/**
 * Tiny Upstash Redis REST client (no dependencies).
 * Works with the env vars Upstash/Vercel set: UPSTASH_REDIS_REST_URL +
 * UPSTASH_REDIS_REST_TOKEN, or the KV_REST_API_URL + KV_REST_API_TOKEN pair.
 * When Redis is not configured, enabled() is false and callers fall back to
 * their in-memory behaviour, so the site keeps working either way.
 */
const URL_ = process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL || '';
const TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN || '';

function enabled() {
  return URL_ !== '' && TOKEN !== '';
}

/** Run one command, e.g. cmd(['INCR','k']). Returns the result or null on failure. */
async function cmd(args) {
  if (!enabled()) return null;
  try {
    const r = await fetch(URL_, {
      method: 'POST',
      headers: { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(args),
      signal: AbortSignal.timeout(3000),
    });
    if (!r.ok) return null;
    const j = await r.json();
    return j.result === undefined ? null : j.result;
  } catch (_) {
    return null;
  }
}

module.exports = { enabled, cmd };
