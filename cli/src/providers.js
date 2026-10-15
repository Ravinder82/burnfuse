/**
 * Provider registry. Each provider knows three optional things:
 *
 *   spendUrl(key)   -> where to read today's spend
 *   parse(json)     -> how to pull a dollar number out of that response
 *   killUrl(entry)  -> where to disable/revoke a key
 *
 * Read-only by default. A provider only gets a kill path if the API genuinely
 * supports revocation. `custom` lets you point BurnFuse at any read-only
 * cost endpoint of your own.
 */

const today = () => new Date().toISOString().slice(0, 10);

export const providers = {
  openai: {
    label: "OpenAI",
    blurb: "Organization costs API (read-only). Requires an Admin API key.",
    signal: "OPENAI_ADMIN_KEY",
    needsAdminKey: true,
    // The costs API only buckets by day, so a 1d bucket is the money spent
    // since UTC midnight. It climbs monotonically, which means two reads a
    // little apart give a clean hourly rate.
    measuresTotal: true,
    fallbackUrls: [],
    spendUrl: () =>
      `https://api.openai.com/v1/organization/costs?start_time=${Math.floor(Date.now() / 1000) - 3600}&bucket_width=1d&limit=1`,
    spendHeaders: (key) => ({ Authorization: `Bearer ${key}` }),
    parse: (json) => {
      const buckets = json?.data || [];
      return buckets.reduce((acc, b) => acc + (b?.results || []).reduce((s, r) => s + (r?.amount?.value || 0), 0), 0);
    },
    killUrl: (entry) => (entry.providerKeyId ? `https://api.openai.com/v1/organization/admin_api_keys/${entry.providerKeyId}` : null),
    killMethod: "DELETE",
    killHeaders: (key) => ({ Authorization: `Bearer ${key}` }),
  },
  anthropic: {
    label: "Anthropic",
    blurb: "Anthropic exposes cost reports to Admin API keys. Paste a reading if you use a standard key.",
    signal: "ANTHROPIC_ADMIN_KEY",
    spendUrl: null,
    parse: null,
    killUrl: (entry) => (entry.providerKeyId ? `https://api.anthropic.com/v1/organizations/api_keys/${entry.providerKeyId}` : null),
    killMethod: "POST",
  },
  openrouter: {
    label: "OpenRouter",
    blurb: "Reads live credit usage. A standard OpenRouter key is enough.",
    signal: "OPENROUTER_API_KEY",
    measuresTotal: true,
    fallbackUrls: ["https://openrouter.ai/api/v1/key"],
    spendUrl: () => "https://openrouter.ai/api/v1/auth/key",
    spendHeaders: (key) => ({ Authorization: `Bearer ${key}` }),
    parse: (json) => Number(json?.data?.usage || 0),
    killUrl: () => null,
  },
  replicate: {
    label: "Replicate",
    blurb: "No public spend endpoint. Paste readings, or wire a custom URL.",
    signal: "REPLICATE_API_TOKEN",
    spendUrl: null,
    parse: null,
    killUrl: () => null,
  },
  groq: {
    label: "Groq",
    blurb: "No public spend endpoint. Paste readings, or wire a custom URL.",
    signal: "GROQ_API_KEY",
    spendUrl: null,
    parse: null,
    killUrl: () => null,
  },
  aws: {
    label: "AWS",
    blurb: "Use Cost Explorer via the AWS CLI, or your own read-only cost endpoint.",
    signal: "AWS_ACCESS_KEY_ID",
    spendUrl: null,
    parse: null,
    killUrl: () => null,
  },
  custom: {
    label: "Custom endpoint",
    blurb: "Any URL that returns a dollar number. Point BurnFuse at a JSON path.",
    signal: null,
    // Set by the user when they add the key: "rate" (the endpoint already
    // reports $/hr) or "total" (it counts up and needs two reads).
    measuresTotal: false,
    fallbackUrls: [],
    spendUrl: (entry) => entry.source?.spendUrl || null,
    // A source may name its own header, which is how an endpoint wanting
    // x-api-key instead of a bearer token gets wired up.
    spendHeaders: (key, entry) => {
      if (!key) return {};
      const header = entry?.source?.header?.trim() || "Authorization";
      return { [header]: header.toLowerCase() === "authorization" ? `Bearer ${key}` : key };
    },
    parse: null,
    killUrl: (entry) => entry.source?.killUrl || null,
    killMethod: "POST",
  },
};

export const providerList = Object.entries(providers).map(([id, p]) => ({ id, ...p }));

export function getProvider(id) {
  return providers[id] || providers.custom;
}

/**
 * Pull a number out of a JSON body using a dotted path like
 * "data.0.results.0.amount.value". Supports the common shapes without a
 * full JSONPath dependency.
 */
export function readPath(json, path) {
  if (!path) return undefined;
  return String(path)
    .split(".")
    .reduce((acc, part) => {
      if (acc == null) return undefined;
      if (Array.isArray(acc)) return acc[Number(part)];
      return acc[part];
    }, json);
}

export const knownToday = today;