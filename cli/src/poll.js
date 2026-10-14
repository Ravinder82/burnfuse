import { getProvider, readPath } from "./providers.js";

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

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const headers = provider.spendHeaders ? provider.spendHeaders(apiKey) : {};
    const res = await fetch(url, {
      method: "GET",
      headers: { Accept: "application/json", ...headers },
      signal: controller.signal,
    });
    if (!res.ok) {
      return { ok: false, reason: "http", status: res.status, message: `HTTP ${res.status} from ${provider.label}.` };
    }
    const json = await res.json().catch(() => null);
    let cost;
    if (entry.source?.jsonPath) cost = readPath(json, entry.source.jsonPath);
    else if (provider.parse) cost = provider.parse(json);
    if (!Number.isFinite(Number(cost))) {
      return { ok: false, reason: "shape", message: `Could not find a dollar amount in the ${provider.label} response.` };
    }
    return { ok: true, cost: Number(cost), raw: json, url };
  } catch (err) {
    if (err.name === "AbortError") {
      return { ok: false, reason: "timeout", message: "Request timed out." };
    }
    return { ok: false, reason: "network", message: err.message };
  } finally {
    clearTimeout(timer);
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