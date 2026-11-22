/**
 * Samachar server-side proxy for NewsData.io (Vercel serverless function).
 *
 * Why this exists: newsdata.io blocks browser CORS, so the Flutter web build
 * cannot call it directly. This function holds the API key server-side
 * (env var NEWSDATA_API_KEY, never shipped to the client) and forwards
 * whitelisted query params to the NewsData.io /api/1/latest endpoint.
 *
 * Quota protection (free plan = 200 credits/day):
 *  - 10-minute in-memory cache per unique param combination, so repeat
 *    visits and tab switches do not burn credits.
 *  - Sliding-window per-IP rate limit (60 requests / 10 minutes).
 * Both stores are in-memory, so they reset on cold starts. Successful
 * responses also carry s-maxage=600 so Vercel's edge caches each unique
 * param combination for 10 minutes globally (the key is never in the URL).
 */

const redis = require('./_redis');

const UPSTREAM = 'https://newsdata.io/api/1/latest';
// Hard cap on real NewsData calls per UTC day (free plan = 200 credits).
const DAILY_CAP = 180;
const STALE_TTL_S = 7 * 24 * 3600;
const CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes
const CACHE_MAX = 200;
const RATE_WINDOW_MS = 10 * 60 * 1000;
const RATE_MAX = 60; // requests per IP per window
const UPSTREAM_TIMEOUT_MS = 12000;

/** @type {Map<string, {ts: number, status: number, body: string}>} */
const cache = new Map();
/** @type {Map<string, number[]>} */
const hits = new Map();

const ALLOWED_CATEGORIES = new Set([
  'top', 'business', 'crime', 'domestic', 'education', 'entertainment',
  'environment', 'food', 'health', 'lifestyle', 'other', 'politics',
  'science', 'sports', 'technology', 'tourism', 'world',
]);

function sendJson(res, status, obj, extraHeaders) {
  const body = JSON.stringify(obj);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    ...extraHeaders,
  });
  res.end(body);
}

function errorBody(message) {
  // Shape matches what the app's NewsService already parses.
  return { status: 'error', results: { message } };
}

function clientIp(req) {
  const fwd = req.headers['x-forwarded-for'];
  if (typeof fwd === 'string' && fwd.length > 0) {
    return fwd.split(',')[0].trim();
  }
  return req.socket?.remoteAddress || 'unknown';
}

function rateLimited(ip) {
  const now = Date.now();
  const arr = (hits.get(ip) || []).filter((t) => now - t < RATE_WINDOW_MS);
  if (arr.length >= RATE_MAX) {
    hits.set(ip, arr);
    return true;
  }
  arr.push(now);
  hits.set(ip, arr);
  // keep the map from growing without bound
  if (hits.size > 5000) hits.clear();
  return false;
}

/** Validate and copy only the params NewsData.io supports for this app. */
function buildUpstreamParams(q) {
  const params = new URLSearchParams();

  const language = typeof q.language === 'string' ? q.language : 'hi,en';
  if (!/^(hi|en)(,(hi|en))?$/.test(language)) return { error: 'Invalid language.' };
  params.set('language', language);

  const country = typeof q.country === 'string' ? q.country : 'in';
  if (!/^[a-z]{2}$/.test(country)) return { error: 'Invalid country.' };
  params.set('country', country);

  if (typeof q.category === 'string' && q.category !== '') {
    if (!ALLOWED_CATEGORIES.has(q.category)) return { error: 'Invalid category.' };
    params.set('category', q.category);
  }

  if (typeof q.q === 'string' && q.q.trim() !== '') {
    const term = q.q.trim().slice(0, 100);
    if (!/^[\p{L}\p{N} .,'&+-]+$/u.test(term)) return { error: 'Invalid search term.' };
    params.set('q', term);
  }

  if (typeof q.page === 'string' && q.page !== '') {
    if (!/^[A-Za-z0-9_-]{1,64}$/.test(q.page)) return { error: 'Invalid page token.' };
    params.set('page', q.page);
  }

  return { params };
}

module.exports = async (req, res) => {
  if (req.method !== 'GET') {
    return sendJson(res, 405, errorBody('Method not allowed.'));
  }

  const key = process.env.NEWSDATA_API_KEY;
  if (!key) {
    return sendJson(res, 500, errorBody('Proxy is not configured.'));
  }

  const ip = clientIp(req);
  if (rateLimited(ip)) {
    return sendJson(res, 429, errorBody('Too many requests. Please wait a few minutes.'), {
      'Retry-After': '600',
    });
  }

  const url = new URL(req.url, 'http://localhost');
  const q = Object.fromEntries(url.searchParams.entries());
  const { params, error } = buildUpstreamParams(q);
  if (error) {
    return sendJson(res, 400, errorBody(error));
  }

  const cacheKey = params.toString();

  // Shared (Redis) cache survives cold starts and is shared by all instances.
  const rkey = 'nc:' + cacheKey;
  if (redis.enabled() && !cache.get(cacheKey)) {
    const hit = await redis.cmd(['GET', rkey]);
    if (typeof hit === 'string') cache.set(cacheKey, { ts: Date.now(), status: 200, body: hit });
  }
  const cached = cache.get(cacheKey);
  if (cached && Date.now() - cached.ts < CACHE_TTL_MS) {
    res.writeHead(cached.status, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'public, s-maxage=600, stale-while-revalidate=60',
      'X-Cache': 'HIT',
    });
    return res.end(cached.body);
  }

  // Daily quota cap: count every real upstream call. Past the cap we never
  // call NewsData; we serve the last good copy of this feed instead.
  const staleKey = 'ns:' + cacheKey;
  async function serveStale(reason) {
    const stale = redis.enabled() ? await redis.cmd(['GET', staleKey]) : null;
    if (typeof stale === 'string') {
      res.writeHead(200, {
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'no-store',
        'X-Cache': 'STALE',
        'X-Stale-Reason': reason,
      });
      res.end(stale);
      return true;
    }
    const mem = cache.get(cacheKey);
    if (mem) {
      res.writeHead(200, {
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'no-store',
        'X-Cache': 'STALE',
        'X-Stale-Reason': reason,
      });
      res.end(mem.body);
      return true;
    }
    return false;
  }

  if (redis.enabled()) {
    const day = new Date().toISOString().slice(0, 10);
    const used = await redis.cmd(['INCR', 'quota:' + day]);
    if (used === 1) await redis.cmd(['EXPIRE', 'quota:' + day, 172800]);
    if (typeof used === 'number' && used > DAILY_CAP) {
      if (await serveStale('cap')) return;
      return sendJson(res, 429, errorBody('Daily free news limit reached. Try again tomorrow.'));
    }
  }

  params.set('apikey', key);
  let upstream;
  try {
    upstream = await fetch(`${UPSTREAM}?${params.toString()}`, {
      headers: { 'User-Agent': 'samachar-web-proxy/1.0', Accept: 'application/json' },
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
    });
  } catch (e) {
    const timedOut = e && (e.name === 'TimeoutError' || e.name === 'AbortError');
    if (await serveStale('upstream-error')) return;
    return sendJson(res, timedOut ? 504 : 502, errorBody(timedOut ? 'News server timed out. Try again.' : 'News server unreachable. Try again.'));
  }

  const bodyText = await upstream.text();
  // Only cache successful JSON payloads; never cache upstream errors.
  if (upstream.status === 200 && bodyText.includes('"status":"success"')) {
    cache.set(cacheKey, { ts: Date.now(), status: upstream.status, body: bodyText });
    if (redis.enabled()) {
      await redis.cmd(['SET', rkey, bodyText, 'EX', 600]);
      await redis.cmd(['SET', staleKey, bodyText, 'EX', STALE_TTL_S]);
    }
    if (cache.size > CACHE_MAX) {
      const oldest = cache.keys().next().value;
      cache.delete(oldest);
    }
  }

  if (upstream.status !== 200 && (await serveStale('upstream-' + upstream.status))) return;

  res.writeHead(upstream.status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Cache': 'MISS',
  });
  res.end(bodyText);
};
