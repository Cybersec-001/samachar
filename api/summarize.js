/**
 * Samachar AI summary (Vercel serverless function).
 * POST { title, description, link, lang } -> { summary }
 * The Gemini API key (env GEMINI_API_KEY) stays server-side. Summaries are
 * cached in Redis per article link so a story costs one Gemini call total.
 */
const crypto = require('crypto');
const redis = require('./_redis');

const MODELS = [process.env.GEMINI_MODEL, 'gemini-3.8-flash', 'gemini-3.8', 'gemini-2.5-flash-lite', 'gemini-flash-latest', 'gemini-2.5-flash'].filter(Boolean);
const RATE_WINDOW_MS = 10 * 60 * 1000;
const RATE_MAX = 20;
const DAILY_CAP = 400;
const hits = new Map();

function send(res, status, obj) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(obj));
}

function ipOf(req) {
  const f = req.headers['x-forwarded-for'];
  return typeof f === 'string' && f ? f.split(',')[0].trim() : 'unknown';
}

function limited(ip) {
  const now = Date.now();
  const arr = (hits.get(ip) || []).filter((t) => now - t < RATE_WINDOW_MS);
  if (arr.length >= RATE_MAX) { hits.set(ip, arr); return true; }
  arr.push(now); hits.set(ip, arr);
  if (hits.size > 5000) hits.clear();
  return false;
}

async function readBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  const chunks = [];
  for await (const c of req) chunks.push(c);
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}'); } catch (_) { return {}; }
}

/** Best-effort: pull readable paragraph text from the article page. */
async function fetchArticleText(link) {
  try {
    const u = new URL(link);
    if (u.protocol !== 'https:' && u.protocol !== 'http:') return '';
    const r = await fetch(link, {
      headers: { 'User-Agent': 'Mozilla/5.0 (compatible; SamacharBot/1.0)', Accept: 'text/html' },
      signal: AbortSignal.timeout(5000),
      redirect: 'follow',
    });
    if (!r.ok) return '';
    const html = (await r.text()).slice(0, 600000);
    const paras = [...html.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/gi)]
      .map((m) => m[1].replace(/<[^>]+>/g, ' ').replace(/&[a-z#0-9]+;/gi, ' ').replace(/\s+/g, ' ').trim())
      .filter((t) => t.length > 60);
    return paras.join(' ').slice(0, 6000);
  } catch (_) {
    return '';
  }
}

module.exports = async (req, res) => {
  if (req.method !== 'POST') return send(res, 405, { error: 'Method not allowed.' });
  const key = process.env.GEMINI_API_KEY;
  if (!key) return send(res, 503, { error: 'AI summary is not configured yet.' });
  if (limited(ipOf(req))) return send(res, 429, { error: 'Too many summaries. Try again in a few minutes.' });

  const body = await readBody(req);
  const title = String(body.title || '').slice(0, 300);
  const description = String(body.description || '').slice(0, 1500);
  const link = String(body.link || '').slice(0, 500);
  const hindi = body.lang === 'hi';
  if (!title) return send(res, 400, { error: 'Missing title.' });

  const ck = 'sum:' + (hindi ? 'hi:' : 'en:') + crypto.createHash('sha1').update(link || title).digest('hex');
  if (redis.enabled()) {
    const hit = await redis.cmd(['GET', ck]);
    if (typeof hit === 'string' && hit) return send(res, 200, { summary: hit, cached: true });
    const day = new Date().toISOString().slice(0, 10);
    const used = await redis.cmd(['INCR', 'sumquota:' + day]);
    if (used === 1) await redis.cmd(['EXPIRE', 'sumquota:' + day, 172800]);
    if (typeof used === 'number' && used > DAILY_CAP) {
      return send(res, 429, { error: 'Daily AI summary limit reached. Try again tomorrow.' });
    }
  }

  const pageText = link ? await fetchArticleText(link) : '';
  const source = [`Headline: ${title}`, description && `Description: ${description}`, pageText && `Article text: ${pageText}`]
    .filter(Boolean).join('\n');
  const prompt =
    `Summarize this news story in 2 to 3 short sentences (max 60 words) in ${hindi ? 'Hindi (Devanagari)' : 'English'}. ` +
    `Use only facts in the text below. No opinions, no preamble, no bullet points.\n\n${source}`;

  let list = MODELS;
  try {
    const lr = await fetch('https://generativelanguage.googleapis.com/v1beta/models?pageSize=200', { headers: { 'x-goog-api-key': key }, signal: AbortSignal.timeout(5000) });
    if (lr.ok) {
      const lj = await lr.json();
      const found = (lj.models || []).filter((m) => (m.supportedGenerationMethods || []).includes('generateContent') && /flash/.test(m.name) && !/image|tts|live|audio|preview|exp|thinking/.test(m.name)).map((m) => m.name.replace('models/', ''));
      found.sort().reverse();
      list = [...new Set([...MODELS.slice(0, 1), ...found.slice(0, 4)])].filter(Boolean);
    }
  } catch (_) {}
  console.log('models', list.join(','));
  let r;
  for (const MODEL of list) {
    try {
      r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': key },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.2, maxOutputTokens: 400 },
        }),
        signal: AbortSignal.timeout(8000),
      });
    } catch (_) { r = null; continue; }
    if (r.ok) break;
    if (r.status !== 503 && r.status !== 404 && r.status !== 429) break;
  }
  if (!r) return send(res, 504, { error: 'The AI service timed out. Try again.' });
  if (r.status === 429) return send(res, 429, { error: 'AI is busy right now. Try again in a minute.' });
  if (!r.ok) { let m=''; try { m=((await r.json()).error||{}).message||''; } catch (_) {} console.log('gemini', r.status, m.slice(0,200)); return send(res, 502, { error: 'AI summary is unavailable right now.', upstream: r.status, tried: list.join(','), detail: m.slice(0,120) }); }
  let j;
  try { j = await r.json(); } catch (_) { return send(res, 502, { error: 'Unexpected AI response.' }); }
  const text = (((j.candidates || [])[0] || {}).content || {}).parts;
  const summary = Array.isArray(text) ? text.map((p) => p.text || '').join('').trim() : '';
  if (!summary) return send(res, 502, { error: 'No summary was produced.' });
  if (redis.enabled()) await redis.cmd(['SET', ck, summary, 'EX', 7 * 24 * 3600]);
  return send(res, 200, { summary });
};
