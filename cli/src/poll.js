import { getProvider, readPath } from "./providers.js";

/**
 * Whether this entry's endpoint counts money up rather than reporting an
 * hourly figure. Both are dollar numbers to the engine; only one of them needs
 * two reads before it means anything.
 */
export function measuresTotal(entry) {
  const provider = getProvider(entry.provider);
  if (entry.source?.measures) return entry.source.measures === "total";
  return provider.measuresTotal === true;
}

/**
 * Turn a running total into dollars per hour, using the entry's own last
 * reading of that total. Mirrors the Swift side so the CLI and the app agree.
 * Returns null when there is nothing to compare against yet.
 */
export function rateFromTotal(total, previous, previousAt, nowMs) {
  if (!Number.isFinite(previous) || !Number.isFinite(previousAt)) return null;
  if (!(previousAt < nowMs)) return null;
  const change = total - previous;
  if (change < 0) return null; // a billing day rolled over
  const hours = (nowMs - previousAt) / 3_600_000;
  if (hours <= 0) return null;
  return change / hours;
}

/**
 * Best-effort live spend fetch. Never throws — returns a structured result
 * so the CLI can degrade gracefully and fall back to manual readings.
 */
export async function fetchSpend(entry, apiKey, timeoutMs = 8000) {
  const provider = getProvider(entry.provider);
  const url =
    entry.source?.spendUrl ||
    (typeof provider.spendUrl === "function" ? provider.spendUrl(entry) : null);

  if (!url) {
    return { ok: false, reason: "no-endpoint", message: `${provider.label} has no public spend endpoint.` };
  }

  // A provider relocating its endpoint is not a rejected key, so try the known
  // other address before blaming anything.
  const candidates = [url, ...(provider.fallbackUrls || [])];
  let last = null;
  for (const candidate of candidates) {
    const attempt = await readOnce(entry, provider, candidate, apiKey, timeoutMs);
    if (attempt.ok) return attempt;
    last = attempt;
    // Only a missing address is worth trying elsewhere.
    if (attempt.status !== 404 && attempt.status !== 410) break;
  }
  if (candidates.length > 1 && (last?.status === 404 || last?.status === 410)) {
    return {
      ok: false,
      reason: "endpoint-moved",
      status: last.status,
      message: `Could not find ${provider.label}'s spend endpoint.`,
    };
  }
  return last;
}

async function readOnce(entry, provider, url, apiKey, timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const headers = provider.spendHeaders ? provider.spendHeaders(apiKey, entry) : {};
    const res = await fetch(url, {
      method: "GET",
      headers: { Accept: "application/json", ...headers },
      signal: controller.signal,
    });
    if (!res.ok) {
      return {
        ok: false,
        reason: "http",
        status: res.status,
        message: messageFor(res.status, provider.label),
      };
    }
    const json = await res.json().catch(() => null);
    let cost;
    if (entry.source?.jsonPath) cost = readPath(json, entry.source.jsonPath);
    else if (provider.parse) cost = provider.parse(json);
    if (!Number.isFinite(Number(cost))) {
      return { ok: false, reason: "shape", status: res.status, message: `Could not find a dollar amount in the ${provider.label} response.` };
    }
    return { ok: true, cost: Number(cost), raw: json, url, status: res.status };
  } catch (err) {
    if (err.name === "AbortError") {
      return { ok: false, reason: "timeout", message: `${provider.label} did not answer in time.` };
    }
    return { ok: false, reason: "network", message: err.message };
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Say what actually happened, in words a person can act on. The most common
 * failure with this app is a perfectly good key of the wrong kind, and a bare
 * status code tells them nothing about that.
 */
function messageFor(status, label) {
  switch (status) {
    case 400:
      return `${label} did not accept that request (400).`;
    case 401:
      return `${label} said this key is not valid (401).`;
    case 403:
      return `${label} refused this key (403). It may not have access to billing.`;
    case 404:
      return `${label} could not find that endpoint (404).`;
    case 429:
      return `${label} is rate-limiting reads (429).`;
    default:
      if (status >= 500) return `${label} is having trouble (${status}).`;
      return `${label} returned HTTP ${status}.`;
  }
}

/**
 * Fire an alert webhook (Slack / Discord / generic). Fire-and-forget.
 */
export async function notify(url, payload, timeoutMs = 6000) {
  if (!url) return { ok: false, reason: "no-webhook" };
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const body = url.includes("discord.com") ? { content: payload.text } : payload;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    return { ok: res.ok, status: res.status };
  } catch (err) {
    return { ok: false, reason: err.message };
  } finally {
    clearTimeout(timer);
  }
}
