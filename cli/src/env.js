import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { providers } from "./providers.js";

/**
 * Scans local .env files for AI provider keys.
 * The key itself never leaves the machine and is never printed — only the
 * variable name and a masked preview.
 */
const SIGNALS = Object.entries(providers)
  .filter(([, p]) => p.signal)
  .map(([id, p]) => ({ id, signal: p.signal, label: p.label }));

const EXTRA_SIGNALS = [
  { id: "openai", signal: "OPENAI_API_KEY", label: "OpenAI" },
  { id: "anthropic", signal: "ANTHROPIC_API_KEY", label: "Anthropic" },
];

export function scanEnvFiles(dirs = [process.cwd()]) {
  const seen = new Map();
  for (const dir of dirs) {
    for (const file of listEnvFiles(dir)) {
      const lines = readLines(file);
      for (const { line, index } of lines) {
        const match = line.match(/^\s*(?:export\s+)?([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
        if (!match) continue;
        const [, name, rawValue] = match;
        const value = stripQuotes(rawValue);
        if (!value) continue;
        const known = [...SIGNALS, ...EXTRA_SIGNALS].find((s) => s.signal === name) ||
          guessByName(name);
        if (!known) continue;
        if (seen.has(name)) continue;
        seen.set(name, {
          name,
          provider: known.id,
          providerLabel: known.label,
          preview: mask(value),
          file,
          line: index + 1,
          looksReal: isPlausibleKey(value),
        });
      }
    }
  }
  return [...seen.values()];
}

function guessByName(name) {
  if (/OPENAI/.test(name)) return { id: "openai", label: "OpenAI" };
  if (/ANTHROPIC|CLAUDE/.test(name)) return { id: "anthropic", label: "Anthropic" };
  if (/OPENROUTER/.test(name)) return { id: "openrouter", label: "OpenRouter" };
  if (/REPLICATE/.test(name)) return { id: "replicate", label: "Replicate" };
  if (/GROQ/.test(name)) return { id: "groq", label: "Groq" };
  if (/AWS_ACCESS_KEY/.test(name)) return { id: "aws", label: "AWS" };
  return null;
}

function listEnvFiles(dir) {
  const out = [];
  try {
    for (const name of fs.readdirSync(dir)) {
      if (!/^\.env(\..+)?$/.test(name)) continue;
      if (/\.example$|\.sample$|\.template$/.test(name)) continue;
      const full = path.join(dir, name);
      try {
        if (fs.statSync(full).isFile()) out.push(full);
      } catch {}
    }
  } catch {}
  return out;
}

function readLines(file) {
  try {
    return fs
      .readFileSync(file, "utf8")
      .split(/\r?\n/)
      .map((line, index) => ({ line, index }));
  } catch {
    return [];
  }
}

function stripQuotes(v) {
  const t = v.trim();
  if ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'"))) {
    return t.slice(1, -1);
  }
  return t;
}

export function mask(value) {
  const v = String(value);
  if (v.length <= 8) return "••••";
  return `${v.slice(0, 4)}••••${v.slice(-4)}`;
}

function isPlausibleKey(value) {
  if (value.length < 16) return false;
  if (/^(sk-|sk-proj-|sk-ant-|sk-or-|r8_|gsk_)/.test(value)) return true;
  if (/^(your|xxx|test|example|placeholder|changeme|dummy)/i.test(value)) return false;
  return /[A-Za-z0-9]{16,}/.test(value);
}

export function homeEnvPath() {
  return path.join(os.homedir(), ".burnfuse");
}