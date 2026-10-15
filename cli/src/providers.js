/**
 * Provider registry. Each provider knows three optional things:
 *
 *   spendUrl(key)     -> where to read today's spend
 *   parse(json)       -> how to pull a dollar number out of that response
 *   whereToRevoke     -> where in the console the key itself is revoked
 *
 * Read-only by design. Nothing here ever revokes anything: reading a cost figure
 * and killing a credential are different permissions, and holding the second one
 * would make BurnFuse a bigger risk than the leak it watches for. So a trip names
 * the console page where the key is revoked instead of pretending to cut it.
 * `custom` lets you point BurnFuse at any read-only cost endpoint of your own.
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
    // Turns down a request that carries no key at all.
    requiresKey: true,
    fallbackUrls: [],
    spendUrl: () =>
      `https://api.openai.com/v1/organization/costs?start_time=${Math.floor(Date.now() / 1000) - 3600}&bucket_width=1d&limit=1`,
    spendHeaders: (key) => ({ Authorization: `Bearer ${key}` }),
    parse: (json) => {
      const buckets = json?.data || [];
      return buckets.reduce((acc, b) => acc + (b?.results || []).reduce((s, r) => s + (r?.amount?.value || 0), 0), 0);
    },
    // Where the key is revoked. Not an endpoint BurnFuse calls: reading a cost
    // figure and revoking a credential are different permissions, and this never
    // holds the second one. Named so the trip output can say where to go.
    whereToRevoke: "OpenAI dashboard → API keys",
  },
  anthropic: {
    label: "Anthropic",
    blurb: "Reads your organization's cost report. Needs an Admin key on an organization account.",
    signal: "ANTHROPIC_ADMIN_KEY",
    measuresTotal: true,
    // Turns down a request that carries no key at all.
    requiresKey: true,
    fallbackUrls: [],
    // The cost report is daily-only and wants an RFC 3339 window: ask for the
    // day we are in, so the single bucket it returns is today's running total.
    spendUrl: () => {
      const dayStart = new Date(Math.floor(Date.now() / 86_400_000) * 86_400_000)
        .toISOString()
        .replace(/\.\d{3}Z$/, "Z");
      return `https://api.anthropic.com/v1/organizations/cost_report?starting_at=${dayStart}&bucket_width=1d&limit=1`;
    },
    // `x-api-key` rather than a bearer token, plus the API version.
    spendHeaders: (key) => {
      const headers = { "anthropic-version": "2023-06-01" };
      if (key) headers["x-api-key"] = key;
      return headers;
    },
    // Amounts are decimal strings in *cents*, so a day total is a hundredth.
    parse: (json) =>
      (json?.data || []).reduce(
        (acc, b) => acc + (b?.results || []).reduce((s, r) => s + (Number(r?.amount) || 0), 0),
        0,
      ) / 100,
    whereToRevoke: "Claude Console → API keys",
  },
  openrouter: {
    label: "OpenRouter",
    blurb: "Reads live credit usage. A standard OpenRouter key is enough.",
    signal: "OPENROUTER_API_KEY",
    measuresTotal: true,
    // Turns down a request that carries no key at all.
    requiresKey: true,
    // The path OpenRouter used before it settled on /api/v1/key.
    fallbackUrls: ["https://openrouter.ai/api/v1/auth/key"],
    spendUrl: () => "https://openrouter.ai/api/v1/key",
    spendHeaders: (key) => ({ Authorization: `Bearer ${key}` }),
    // `usage` is all-time credits used, which only ever climbs — the most
    // robust number to take a difference from. Older responses only carried
    // the daily figure.
    parse: (json) => Number(json?.data?.usage ?? json?.data?.usage_daily ?? 0),
    whereToRevoke: "OpenRouter → Settings → Keys",
  },
  replicate: {
    label: "Replicate",
    blurb: "No public spend endpoint. Paste readings, or wire a custom URL.",
    signal: "REPLICATE_API_TOKEN",
    spendUrl: null,
    parse: null,
    whereToRevoke: "Replicate → Account → API tokens",
  },
  groq: {
    label: "Groq",
    blurb: "No public spend endpoint. Paste readings, or wire a custom URL.",
    signal: "GROQ_API_KEY",
    spendUrl: null,
    parse: null,
    whereToRevoke: "Groq Console → API Keys",
  },
  aws: {
    label: "AWS",
    blurb: "Use Cost Explorer via the AWS CLI, or your own read-only cost endpoint.",
    signal: "AWS_ACCESS_KEY_ID",
    spendUrl: null,
    parse: null,
    whereToRevoke: "AWS IAM → Access keys",
  },
  custom: {
    label: "Your own endpoint",
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
    whereToRevoke: null,
  },
};

/**
 * Providers BurnFuse can name but cannot read. Kept here so a trip, a label and
 * a revoke pointer stay true for a key from any of them — an app that only
 * knows the four it can read has to describe the rest as "custom", which is
 * exactly the kind of small lie this project exists to avoid.
 *
 * Add a provider by adding a line: `id: [label, whereToRevoke]`.
 */
const MANUAL = {
  google: ["Google Gemini", "Google AI Studio → API keys"],
  xai: ["xAI (Grok)", "console.x.ai → API keys"],
  mistral: ["Mistral", "Mistral Console → API keys"],
  deepseek: ["DeepSeek", "DeepSeek platform → API keys"],
  together: ["Together AI", "Together → Settings → API keys"],
  fireworks: ["Fireworks AI", "Fireworks → API keys"],
  perplexity: ["Perplexity", "Perplexity → API → Keys"],
  huggingface: ["Hugging Face", "Hugging Face → Settings → Access tokens"],
  stability: ["Stability AI", "Stability → Account → API keys"],
  fal: ["fal.ai", "fal.ai → Dashboard → API keys"],
  runway: ["Runway", "Runway → Account → API keys"],
  luma: ["Luma", "Luma → Dashboard → API keys"],
  elevenlabs: ["ElevenLabs", "ElevenLabs → Profile → API keys"],
  deepgram: ["Deepgram", "Deepgram Console → API keys"],
  firecrawl: ["Firecrawl", "Firecrawl → Dashboard → API keys"],
  apify: ["Apify", "Apify Console → Settings → Integrations"],
  browserbase: ["Browserbase", "Browserbase → Settings → API keys"],
  exa: ["Exa", "Exa → Dashboard → API keys"],
  tavily: ["Tavily", "Tavily → Dashboard → API keys"],
  gcp: ["Google Cloud", "Google Cloud Console → IAM → Service accounts"],
  azure: ["Microsoft Azure", "Azure → App registrations → Certificates & secrets"],
  cloudflare: ["Cloudflare", "Cloudflare → My Profile → API Tokens"],
  vercel: ["Vercel", "Vercel → Settings → Tokens"],
  supabase: ["Supabase", "Supabase → Account → Access Tokens"],
};

for (const [id, [label, whereToRevoke]] of Object.entries(MANUAL)) {
  providers[id] = {
    label,
    blurb: "No spend read. Add readings by hand, or wire a custom URL.",
    signal: null,
    measuresTotal: false,
    fallbackUrls: [],
    spendUrl: null,
    parse: null,
    whereToRevoke,
  };
}

export const providerList = Object.entries(providers).map(([id, p]) => ({ id, ...p }));

/**
 * The provider entry for an id, falling back to a description of the id itself
 * rather than quietly renaming it "custom endpoint". A key from a provider
 * BurnFuse cannot read is still that provider's key, and saying so is the
 * difference between a label and a lie.
 */
export function getProvider(id) {
  const known = providers[id];
  if (known) return known;
  return {
    ...providers.custom,
    id,
    label: String(id || "unknown")
      .replace(/[-_]+/g, " ")
      .replace(/\b\w/g, (m) => m.toUpperCase()),
    blurb: "No spend read for this provider. Add readings by hand.",
    whereToRevoke: null,
  };
}

/**
 * The one line that belongs with a trip: the only action that ends the spend.
 * Reading a cost figure and revoking a credential are different permissions, so
 * this says where to revoke rather than implying the trip stopped anything.
 */
export function revokeHint(entry) {
  const where = getProvider(entry.provider).whereToRevoke;
  return where
    ? `Revoke the key at ${where} to stop the spend.`
    : "Revoke the key where you issued it to stop the spend.";
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