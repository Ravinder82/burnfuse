import fs from "node:fs";
import os from "node:os";
import path from "node:path";

/**
 * BurnFuse keeps a single readable state file so the CLI and the macOS
 * menu-bar app watch the exact same keys. No account, no sync, no cloud.
 */
export const STATE_VERSION = 2;

export function defaultState() {
  return {
    version: STATE_VERSION,
    settings: {
      zThreshold: 2.5,
      minStdDev: 0.1,
      autoKillOnBreach: false,
      notifyWebhook: "",
      historyWindow: 24,
    },
    entries: [],
    incidents: [],
  };
}

export function statePath(explicit) {
  if (explicit) return path.resolve(explicit);
  if (process.env.BURNFUSE_STATE) return path.resolve(process.env.BURNFUSE_STATE);
  return path.join(os.homedir(), ".burnfuse", "state.json");
}

function migrate(raw) {
  const base = defaultState();
  if (!raw || typeof raw !== "object") return base;
  return {
    version: STATE_VERSION,
    settings: { ...base.settings, ...(raw.settings || {}) },
    entries: Array.isArray(raw.entries) ? raw.entries.map(normalizeEntry) : [],
    incidents: Array.isArray(raw.incidents) ? raw.incidents.slice(0, 200) : [],
  };
}

function normalizeEntry(e) {
  return {
    id: e.id || makeId(e.name || "key"),
    name: e.name || "Untitled key",
    provider: e.provider || "custom",
    hourlyLimit: num(e.hourlyLimit, 5),
    armed: e.armed !== false,
    autoKill: e.autoKill !== false,
    status: e.status || "armed",
    readings: Array.isArray(e.readings) ? e.readings : [],
    source: e.source || null,
    lastReading: num(e.lastReading, 0),
    trippedAt: e.trippedAt || null,
    createdAt: e.createdAt || Date.now(),
  };
}

const num = (v, d) => (Number.isFinite(Number(v)) ? Number(v) : d);

export function makeId(seed = "key") {
  const slug = String(seed)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 28);
  const tail = Math.random().toString(36).slice(2, 6);
  return `${slug || "key"}_${tail}`;
}

export function loadState(explicit) {
  const file = statePath(explicit);
  try {
    const raw = JSON.parse(fs.readFileSync(file, "utf8"));
    return { state: migrate(raw), file };
  } catch (err) {
    if (err.code === "ENOENT") return { state: defaultState(), file, fresh: true };
    if (err instanceof SyntaxError) {
      throw new Error(`state file is not valid JSON: ${file}\n  Fix or delete it, then run burnfuse again.`);
    }
    throw err;
  }
}

export function saveState(state, explicit) {
  const file = statePath(explicit);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, `${JSON.stringify(state, null, 2)}\n`);
  fs.renameSync(tmp, file);
  return file;
}

export function findEntries(state, needle) {
  if (!needle) return [];
  const q = String(needle).toLowerCase();
  const exact = state.entries.filter((e) => e.id.toLowerCase() === q);
  if (exact.length) return exact;
  return state.entries.filter(
    (e) => e.id.toLowerCase().includes(q) || e.name.toLowerCase().includes(q),
  );
}

export function resolveEntry(state, needle) {
  if (needle === "all") return state.entries.slice();
  const hits = findEntries(state, needle);
  if (hits.length === 0) throw new Error(`no key matches "${needle}". Run \`burnfuse list\` to see your keys.`);
  if (hits.length > 1) {
    const names = hits.map((h) => h.id).join(", ");
    throw new Error(`"${needle}" matches ${hits.length} keys: ${names}\n  Be more specific.`);
  }
  return hits[0];
}