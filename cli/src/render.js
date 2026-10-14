import { money, sigma } from "./stats.js";

/**
 * Presentation layer. Plain, quiet, Apple-ish: restrained colour, aligned
 * columns, no wall of text. Honours NO_COLOR and piped output.
 */
export const useColor =
  !process.env.NO_COLOR && process.stdout.isTTY === true;

const wrap = (code) => (s) => (useColor ? `\x1b[${code}m${s}\x1b[0m` : String(s));

export const c = {
  bold: wrap("1"),
  dim: wrap("2"),
  red: wrap("31"),
  green: wrap("32"),
  yellow: wrap("33"),
  blue: wrap("34"),
  magenta: wrap("35"),
  cyan: wrap("36"),
  gray: wrap("90"),
  strike: wrap("9"),
};

export const BRAND = "burnfuse";

export function banner(version) {
  return `${c.bold("burnfuse")} ${c.gray(version)}\n${c.gray("A spend breaker for your AI keys.")}`;
}

const SPARK = "▁▂▃▄▅▆▇█";

export function sparkline(values) {
  if (!values.length) return "";
  const max = Math.max(...values, 0.0001);
  const min = Math.min(...values, 0);
  const span = max - min || 1;
  return values
    .map((v) => {
      const i = Math.round(((v - min) / span) * (SPARK.length - 1));
      return SPARK[Math.max(0, Math.min(SPARK.length - 1, i))];
    })
    .join("");
}

export function statusGlyph(entry) {
  if (entry.status === "tripped") return c.red("⛔ tripped");
  if (entry.status === "paused" || !entry.armed) return c.gray("○ paused");
  return c.green("● armed");
}

export function zGlyph(assessment, settings) {
  if (!assessment.samples) return c.gray("— new");
  const label = sigma(assessment.z);
  if (assessment.overCap) return c.red(label);
  if (assessment.spike) return c.yellow(label);
  return c.cyan(label);
}

export function burnGlyph(entry) {
  const over = Number(entry.lastReading) > Number(entry.hourlyLimit);
  const text = `${money(entry.lastReading)}/hr`;
  return over ? c.red(text) : c.green(text);
}

function pad(s, n) {
  const plain = String(s).replace(/\x1b\[[0-9;]*m/g, "");
  return String(s) + " ".repeat(Math.max(0, n - plain.length));
}

function truncate(s, n) {
  const t = String(s);
  return t.length > n ? `${t.slice(0, n - 1)}…` : t;
}

export function keyTable(rows, settings) {
  const head = `  ${pad(c.gray("KEY"), 26)}${pad(c.gray("BURN"), 14)}${pad(c.gray("CAP"), 10)}${pad(c.gray("SPIKE"), 12)}STATUS`;
  const lines = rows.map(({ entry, assessment }) => {
    const name = pad(truncate(entry.name, 24), 26);
    return `  ${name}${pad(burnGlyph(entry), 14)}${pad(c.gray(money(entry.hourlyLimit)), 10)}${pad(zGlyph(assessment, settings), 12)}${statusGlyph(entry)}`;
  });
  return [head, ...lines].join("\n");
}

export function summaryLine(state, assessments) {
  const tripped = state.entries.filter((e) => e.status === "tripped").length;
  const armed = state.entries.filter((e) => e.armed && e.status !== "tripped").length;
  const burning = state.entries.reduce((a, e) => a + Number(e.lastReading || 0), 0);
  const parts = [];
  if (tripped) parts.push(c.red(`⛔ ${tripped} tripped`));
  parts.push(`${armed} armed`);
  parts.push(`${money(burning)}/hr burning now`);
  return parts.join(c.gray("  ·  "));
}

export function combinedSpark(state) {
  const window = 24;
  const series = [];
  for (let i = window - 1; i >= 0; i--) {
    let sum = 0;
    let any = false;
    for (const e of state.entries) {
      const r = e.readings[e.readings.length - 1 - i];
      if (r) {
        sum += Number(r.cost);
        any = true;
      }
    }
    if (any) series.push(sum);
  }
  return series;
}

export function note(text) {
  return `  ${c.gray("·")} ${text}`;
}

export function heading(text) {
  return `\n  ${c.bold(text)}`;
}

export function kv(k, v, width = 18) {
  return `  ${c.gray(pad(k, width))}${v}`;
}

export function rule(width = 54) {
  return c.gray(`  ${"─".repeat(width)}`);
}