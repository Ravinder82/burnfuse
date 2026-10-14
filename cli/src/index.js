import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  loadState,
  saveState,
  makeId,
  resolveEntry,
} from "./store.js";
import { assess, money, multiple, projectBurn } from "./stats.js";
import { fetchSpend, notify } from "./poll.js";
import { scanEnvFiles } from "./env.js";
import { providerList, getProvider } from "./providers.js";
import {
  banner,
  c,
  heading,
  keyTable,
  kv,
  note,
  rule,
  summaryLine,
  combinedSpark,
  sparkline,
  useColor,
} from "./render.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const VERSION = JSON.parse(fs.readFileSync(path.join(here, "..", "package.json"), "utf8")).version;

const EXIT = { ok: 0, error: 1, breach: 2 };

// ---------------------------------------------------------------- arg parsing

function parseArgs(argv) {
  const positional = [];
  const flags = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--") {
      positional.push(...argv.slice(i + 1));
      break;
    }
    if (a.startsWith("--")) {
      const [k, inline] = a.slice(2).split("=");
      if (inline !== undefined) flags[k] = inline;
      else if (argv[i + 1] && !argv[i + 1].startsWith("--")) flags[k] = argv[++i];
      else flags[k] = true;
    } else if (a.startsWith("-") && a.length === 2) {
      const map = { h: "help", v: "version", j: "json" };
      flags[map[a[1]] || a[1]] = true;
    } else {
      positional.push(a);
    }
  }
  return { positional, flags };
}

const isFlag = (v) => v === true;

function prettyPath(file) {
  const home = process.env.HOME || "";
  const rel = path.relative(process.cwd(), file);
  if (rel && !rel.startsWith("..")) return rel;
  if (home && file.startsWith(home)) return `~${file.slice(home.length)}`;
  return file;
}

function uniqueName(state, base) {
  if (!state.entries.some((e) => e.name === base)) return base;
  let n = 2;
  while (state.entries.some((e) => e.name === `${base} ${n}`)) n++;
  return `${base} ${n}`;
}

// -------------------------------------------------------------------- helpers

function requireEntries(state) {
  if (!state.entries.length) {
    console.log("");
    console.log(note(`No keys yet. Add one, then it shows up here:`));
    console.log(note(c.bold("burnfuse add \"OpenAI prod\" --limit 5")));
    console.log(note(c.bold("burnfuse scan")) + c.gray("   (find keys in your .env files)"));
    console.log("");
    return false;
  }
  return true;
}

function assessmentsFor(state) {
  const map = new Map();
  for (const entry of state.entries) {
    map.set(entry.id, assess(entry, entry.lastReading, state.settings));
  }
  return map;
}

async function runVerdict(state, entry, { persist = true, label = "check" } = {}) {
  const verdict = assess(entry, entry.lastReading, state.settings);
  const wasArmed = entry.status !== "tripped";
  if (verdict.breach && wasArmed) {
    entry.status = "tripped";
    entry.trippedAt = Date.now();
    state.incidents.unshift({
      at: Date.now(),
      entryId: entry.id,
      name: entry.name,
      reading: Number(entry.lastReading),
      hourlyLimit: Number(entry.hourlyLimit),
      z: Number(verdict.z.toFixed(2)),
      reason: verdict.overCap ? "over cap" : "spike",
      action: "tripped",
    });
    state.incidents = state.incidents.slice(0, 200);
    if (state.settings.notifyWebhook) {
      await notify(state.settings.notifyWebhook, {
        text: `⛔ burnfuse tripped ${entry.name} — ${money(entry.lastReading)}/hr vs ${money(entry.hourlyLimit)}/hr cap (${multiple(entry.lastReading, verdict.baseline || entry.lastReading)} its usual rate)`,
      });
    }
  }
  if (entry.armed && entry.autoKill && entry.status === "tripped") {
    const provider = getProvider(entry.provider);
    const killUrl = provider.killUrl ? provider.killUrl(entry) : null;
    entry.killAvailable = Boolean(killUrl);
  }
  if (persist) saveState(state, state.__file);
  return verdict;
}

function printVerdict(entry, verdict) {
  const state = entry.status === "tripped" ? c.red("TRIPPED") : c.green("OK");
  console.log(`  ${entry.name} — ${state}`);
  console.log(kv("burning", `${money(verdict.current)}/hr`));
  console.log(kv("cap", `${money(verdict.hourlyLimit)}/hr`));
  if (verdict.samples) {
    console.log(kv("your usual", `${money(verdict.baseline)}/hr`));
    const ratio = verdict.baseline > 0 ? multiple(verdict.current, verdict.baseline) : "—";
    console.log(kv("right now", `${ratio} your usual burn`));
  }
  if (verdict.breach) {
    console.log(
      `\n  ${c.red("⛔ Breaker tripped.")} ${verdict.overCap ? "Burn crossed your cap." : "Burn jumped far above normal."}`,
    );
    console.log(note(`Unchecked for 6 more hours, this rate would cost ${c.bold(money(projectBurn(verdict.current, 6)))}.`));
    console.log(note(`Fixed the leak? Put it back to work: ${c.bold(`burnfuse arm ${entry.id}`)}`));
  }
}

// ------------------------------------------------------------------- commands

function cmdOverview(state, { json } = {}) {
  if (json) return console.log(JSON.stringify(state, null, 2));
  if (!requireEntries(state)) return;
  const assessments = assessmentsFor(state);
  const rows = state.entries.map((entry) => ({ entry, assessment: assessments.get(entry.id) }));
  const series = combinedSpark(state);

  console.log("");
  console.log(`  ${c.bold("Burn")}  ${sparkline(series) || c.gray("—")}`);
  console.log(`  ${summaryLine(state, assessments)}`);
  console.log("");
  console.log(keyTable(rows, state.settings));
  console.log("");
  console.log(rule());
  console.log(note(`cap = the ceiling you set · state = how hot the key is right now`));
  console.log(note(`${c.bold("burnfuse check")} to evaluate · ${c.bold("burnfuse record <key> <$/hr>")} to log a reading`));
}

function cmdList(state, { json, flags }) {
  if (json) return console.log(JSON.stringify(state.entries, null, 2));
  if (!requireEntries(state)) return;
  const assessments = assessmentsFor(state);
  const rows = state.entries.map((entry) => ({ entry, assessment: assessments.get(entry.id) }));
  console.log("");
  console.log(keyTable(rows, state.settings));
  console.log("");
  for (const { entry } of rows) {
    console.log(`  ${c.bold(entry.name)} ${c.gray(`(${entry.id})`)}`);
    console.log(kv("provider", getProvider(entry.provider).label));
    console.log(kv("readings", `${entry.readings.length}`));
    console.log(kv("auto-kill", entry.autoKill ? "on" : "off"));
    console.log("");
  }
}

function cmdAdd(state, positional, flags) {
  const name = positional[0];
  if (!name) throw new Error('give the key a name, e.g.  burnfuse add "OpenAI prod" --limit 5');
  const provider = String(flags.provider || "custom").toLowerCase();
  if (!getProvider(provider)) throw new Error(`unknown provider "${provider}". Try: ${providerList.map((p) => p.id).join(", ")}`);
  const limit = Number(flags.limit ?? flags.cap ?? 5);
  const entry = {
    id: makeId(flags.id || name),
    name,
    provider,
    hourlyLimit: limit,
    armed: true,
    autoKill: flags["auto-kill"] ? flags["auto-kill"] !== "false" : true,
    status: "armed",
    readings: [],
    source:
      flags.url || flags["json-path"]
        ? { spendUrl: flags.url || null, jsonPath: flags["json-path"] || null }
        : null,
    lastReading: 0,
    createdAt: Date.now(),
  };
  state.entries.push(entry);
  saveState(state, state.__file);
  console.log("");
  console.log(`  ${c.green("✓")} Added ${c.bold(entry.name)}`);
  console.log(kv("id", entry.id));
  console.log(kv("cap", `${money(limit)}/hr`));
  console.log(kv("provider", getProvider(provider).label));
  console.log("");
  console.log(note(`Log a reading: ${c.bold(`burnfuse record ${entry.id} 1.20`)}`));
}

function cmdRecord(state, positional, flags) {
  const [needle, amount] = positional;
  if (!needle || amount === undefined) throw new Error("usage:  burnfuse record <key> <$ per hour>");
  const value = Number(amount);
  if (!Number.isFinite(value) || value < 0) throw new Error(`"${amount}" is not a dollar amount.`);
  const entry = resolveEntry(state, needle);
  entry.readings.push({ at: Date.now(), cost: value, model: flags.model || null });
  entry.readings = entry.readings.slice(-500);
  entry.lastReading = value;
  const verdict = assess(entry, value, state.settings);
  const wasTripped = entry.status === "tripped";
  if (verdict.breach && !wasTripped) {
    entry.status = "tripped";
    entry.trippedAt = Date.now();
    state.incidents.unshift({
      at: Date.now(),
      entryId: entry.id,
      name: entry.name,
      reading: value,
      hourlyLimit: Number(entry.hourlyLimit),
      z: Number(verdict.z.toFixed(2)),
      reason: verdict.overCap ? "over cap" : "spike",
      action: "tripped",
    });
    state.incidents = state.incidents.slice(0, 200);
  }
  saveState(state, state.__file);
  console.log("");
  printVerdict(entry, verdict);
  if (verdict.breach) {
    if (state.settings.notifyWebhook) {
      notify(state.settings.notifyWebhook, {
        text: `⛔ burnfuse tripped ${entry.name} — ${money(value)}/hr vs ${money(entry.hourlyLimit)}/hr cap`,
      }).catch(() => {});
      console.log(note("Alert webhook fired."));
    }
    process.exitCode = EXIT.breach;
  }
}

async function cmdCheck(state, positional, flags) {
  const needle = positional[0] || "all";
  if (!requireEntries(state)) return;
  const targets = needle === "all" ? state.entries : [resolveEntry(state, needle)];
  let breached = false;
  console.log("");
  for (const entry of targets) {
    const verdict = await runVerdict(state, entry);
    printVerdict(entry, verdict);
    console.log("");
    if (verdict.breach) breached = true;
  }
  if (breached) process.exitCode = EXIT.breach;
}

async function cmdPoll(state, positional, flags) {
  const needle = positional[0] || "all";
  if (!requireEntries(state)) return;
  const targets = needle === "all" ? state.entries : [resolveEntry(state, needle)];
  const apiKey = flags.key || process.env.BURNFUSE_API_KEY || null;
  console.log("");
  for (const entry of targets) {
    const provider = getProvider(entry.provider);
    process.stdout.write(`  ${entry.name} ${c.gray("…")}`);
    const result = await fetchSpend(entry, apiKey);
    process.stdout.write("\r\u001b[2K");
    if (!result.ok) {
      console.log(`  ${c.yellow("·")} ${entry.name} ${c.gray(`— ${result.message}`)}`);
      if (!provider.spendUrl && !entry.source?.spendUrl) {
        console.log(note(`Use ${c.bold(`burnfuse record ${entry.id} <$/hr>`)} instead.`));
      }
      continue;
    }
    entry.readings.push({ at: Date.now(), cost: result.cost, model: "live" });
    entry.readings = entry.readings.slice(-500);
    entry.lastReading = result.cost;
    const verdict = await runVerdict(state, entry);
    printVerdict(entry, verdict);
    console.log("");
    if (verdict.breach) process.exitCode = EXIT.breach;
  }
}

function cmdTrip(state, positional) {
  const needle = positional[0] || "all";
  const targets = needle === "all" ? state.entries : [resolveEntry(state, needle)];
  if (!targets.length) return requireEntries(state);
  for (const entry of targets) {
    entry.status = "tripped";
    entry.trippedAt = Date.now();
    entry.armed = false;
    state.incidents.unshift({
      at: Date.now(),
      entryId: entry.id,
      name: entry.name,
      reading: Number(entry.lastReading),
      hourlyLimit: Number(entry.hourlyLimit),
      reason: "manual",
      action: "tripped",
    });
  }
  saveState(state, state.__file);
  console.log("");
  console.log(`  ${c.red("⛔ Tripped")} ${targets.length} key${targets.length > 1 ? "s" : ""}: ${targets.map((t) => t.name).join(", ")}`);
  console.log(note(`Re-arm with ${c.bold("burnfuse arm all")}`));
}

function cmdArm(state, positional, flags) {
  const needle = positional[0] || "all";
  const targets = needle === "all" ? state.entries : [resolveEntry(state, needle)];
  if (!targets.length) return requireEntries(state);
  const clear = flags.clear === true || flags.clear === "true";
  for (const entry of targets) {
    entry.status = "armed";
    entry.armed = true;
    entry.trippedAt = null;
    if (clear) {
      entry.readings = [];
      entry.lastReading = 0;
    }
  }
  saveState(state, state.__file);
  console.log("");
  console.log(`  ${c.green("● Armed")} ${targets.length} key${targets.length > 1 ? "s" : ""}${clear ? " (history cleared)" : ""}.`);
}

function cmdCap(state, positional) {
  const [needle, amount] = positional;
  if (!needle || amount === undefined) throw new Error("usage:  burnfuse cap <key> <$/hr>");
  const entry = resolveEntry(state, needle);
  const value = Number(amount);
  if (!Number.isFinite(value) || value <= 0) throw new Error(`"${amount}" is not a dollar amount.`);
  entry.hourlyLimit = value;
  saveState(state, state.__file);
  console.log("");
  console.log(`  ${c.green("✓")} ${entry.name} cap set to ${c.bold(`${money(value)}/hr`)}.`);
}

/// Turns the raw spike threshold into a word, so the terminal never asks you to
/// read a z-score.
function sensitivityWord(value) {
  if (!Number.isFinite(value)) return "balanced";
  if (value <= 1.6) return "very sensitive";
  if (value >= 3) return "relaxed";
  return "balanced";
}

function cmdSensitivity(state, positional, flags) {
  const value = Number(positional[0] ?? flags.z);
  if (!Number.isFinite(value) || value <= 0) throw new Error("usage:  burnfuse sensitivity <number>   (e.g. 2.5)");
  state.settings.zThreshold = value;
  saveState(state, state.__file);
  console.log("");
  console.log(`  ${c.green("✓")} Sensitivity set to ${c.bold(String(value))} — ${sensitivityWord(value)}.`);
  console.log(note(value <= 1.5 ? "Very sensitive — more alerts, fewer surprises." : value >= 3 ? "Relaxed — only loud spikes alert you." : "Balanced default."));
}

function cmdWebhook(state, positional) {
  const url = positional[0] || "";
  state.settings.notifyWebhook = url;
  saveState(state, state.__file);
  console.log("");
  console.log(url ? `  ${c.green("✓")} Alerts will POST to your webhook.` : `  ${c.green("✓")} Webhook alerts cleared.`);
}

function cmdScan(state, positional, flags) {
  const dirs = positional.length ? positional : [process.cwd()];
  const found = scanEnvFiles(dirs);
  console.log("");
  console.log(heading("Local key scan"));
  console.log(note(c.gray("Read-only. Keys never leave this machine or get printed.")));
  console.log("");
  if (!found.length) {
    console.log(`  ${c.gray("No AI provider keys found in")} ${c.gray(dirs.join(", "))}`);
    console.log(note("Looked in .env, .env.local and friends."));
    console.log(note(`Add one instead: ${c.bold('burnfuse add "OpenAI prod" --provider openai --limit 5')}`));
    console.log("");
    return;
  }
  for (const item of found) {
    const tag = item.looksReal ? c.green("●") : c.gray("○");
    const where = prettyPath(item.file);
    console.log(`  ${tag} ${c.bold(item.name)}  ${c.gray(item.preview)}`);
    console.log(`     ${c.gray(item.providerLabel)} · ${c.gray(where)}:${item.line}${item.looksReal ? "" : c.gray("  (looks like a placeholder)")}`);
  }
  console.log("");
  if (flags.import) {
    let added = 0;
    for (const item of found.filter((f) => f.looksReal)) {
      const name = uniqueName(state, item.providerLabel);
      if (state.entries.some((e) => e.name === name)) continue;
      state.entries.push({
        id: makeId(item.providerLabel),
        name,
        provider: item.provider,
        hourlyLimit: Number(flags.limit || 5),
        armed: true,
        autoKill: true,
        status: "armed",
        readings: [],
        lastReading: 0,
        createdAt: Date.now(),
      });
      added++;
    }
    saveState(state, state.__file);
    console.log(`  ${c.green("✓")} Imported ${added} key${added === 1 ? "" : "s"}.`);
    console.log(note("Set a sane cap for each: " + c.bold("burnfuse cap <key> 5")));
    console.log("");
  } else {
    console.log(note(`Import them all: ${c.bold("burnfuse scan --import")}`));
    console.log("");
  }
}

async function cmdWatch(state, positional, flags) {
  if (!requireEntries(state)) return;
  const interval = Math.max(5, Number(flags.interval || 60));
  const once = flags.once === true;
  console.log("");
  console.log(`  ${c.bold("Watching")} ${state.entries.length} key${state.entries.length > 1 ? "s" : ""} every ${interval}s ${c.gray("· ⌃C to stop")}`);
  console.log("");
  let ticks = 0;
  for (;;) {
    ticks++;
    const stamp = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
    const assessments = assessmentsFor(state);
    const line = state.entries
      .map((e) => {
        const a = assessments.get(e.id);
        const over = Number(e.lastReading) > Number(e.hourlyLimit);
        const t = `${e.name.split(" ")[0]} ${money(e.lastReading)}`;
        return e.status === "tripped" ? c.red(t) : over ? c.yellow(t) : c.green(t);
      })
      .join(c.gray("  ·  "));
    console.log(`  ${c.gray(stamp)}  ${line}`);

    for (const entry of state.entries) {
      if (entry.status === "tripped") continue;
      const verdict = await runVerdict(state, entry);
      if (verdict.breach) {
        console.log(`\n  ${c.red("⛔ " + entry.name + " tripped")} — ${money(verdict.current)}/hr (${verdict.overCap ? "over cap" : multiple(verdict.current, verdict.baseline) + " usual"})`);
        if (state.settings.notifyWebhook) console.log(note("Webhook alert sent."));
        console.log(note(`Re-arm: ${c.bold(`burnfuse arm ${entry.id}`)}`));
        process.exitCode = EXIT.breach;
        return;
      }
    }
    if (once) return;
    await new Promise((r) => setTimeout(r, interval * 1000));
  }
}

function cmdDoctor(state, flags) {
  console.log("");
  console.log(heading("Environment"));
  console.log(kv("node", process.version));
  console.log(kv("platform", `${process.platform} ${process.arch}`));
  console.log(kv("state file", state.__file || "(default)"));
  console.log(kv("keys tracked", String(state.entries.length)));
  console.log(kv("webhook", state.settings.notifyWebhook ? "configured" : c.gray("none")));
  console.log(kv("sensitivity", sensitivityWord(Number(state.settings.zThreshold))));
  console.log("");
  console.log(heading("Providers"));
  for (const p of providerList) {
    const live = p.spendUrl ? c.green("live spend") : c.gray("manual readings");
    console.log(`  ${c.bold(p.label.padEnd(18))} ${live}`);
  }
  console.log("");
}

function cmdDemo(state) {
  const seed = [
    { name: "OpenAI prod", provider: "openai", limit: 5, readings: [1.12, 1.28, 1.19, 1.34, 1.22, 1.31] },
    { name: "Claude batch", provider: "anthropic", limit: 8, readings: [0.62, 0.58, 0.71, 0.66, 0.69, 0.63] },
    { name: "Fal images", provider: "custom", limit: 3, readings: [0.4, 0.5, 0.45, 0.52, 0.48, 0.51] },
  ];
  for (const s of seed) {
    if (state.entries.some((e) => e.name === s.name)) continue;
    state.entries.push({
      id: makeId(s.name),
      name: s.name,
      provider: s.provider,
      hourlyLimit: s.limit,
      armed: true,
      autoKill: true,
      status: "armed",
      readings: s.readings.map((cost, i) => ({ at: Date.now() - (s.readings.length - i) * 3600_000, cost, model: null })),
      lastReading: s.readings[s.readings.length - 1],
      createdAt: Date.now(),
    });
  }
  saveState(state, state.__file);
  console.log("");
  console.log(`  ${c.green("✓")} Seeded demo keys.`);
  console.log(note("Watch a spike trip the breaker: " + c.bold("burnfuse record openai_prod 9.90")));
}

function cmdExport(state) {
  console.log(JSON.stringify(state, null, 2));
}

function cmdHelp() {
  const b = (s) => c.bold(s);
  console.log("");
  console.log(banner(VERSION));
  console.log("");
  console.log(`  ${b("USAGE")}  burnfuse <command> [options]`);
  console.log("");
  console.log(`  ${c.gray("EVERYDAY")}`);
  console.log(`    ${b("status")}                 see every key, burn rate and spike at a glance`);
  console.log(`    ${b("scan")} [dir] [--import]  find AI keys in your .env files (read-only)`);
  console.log(`    ${b("add")} <name> [--limit N] [--provider p]   start tracking a key`);
  console.log(`    ${b("record")} <key> <$/hr>     log an hourly spend reading`);
  console.log(`    ${b("check")} [key|all]         evaluate now, trip if the breaker should`);
  console.log(`    ${b("poll")} [key|all]          pull live spend where the provider allows`);
  console.log("");
  console.log(`  ${c.gray("CONTROL")}`);
  console.log(`    ${b("trip")} <key|all>         cut the power now`);
  console.log(`    ${b("arm")} <key|all> [--clear]   re-arm after a fix`);
  console.log(`    ${b("cap")} <key> <$/hr>       set the hourly ceiling`);
  console.log(`    ${b("sensitivity")} <number>    how big a spike trips the breaker (default 2.5)`);
  console.log(`    ${b("watch")} [--interval 60] [--once]   keep watching until something trips`);
  console.log("");
  console.log(`  ${c.gray("OTHER")}`);
  console.log(`    ${b("list")} · ${b("doctor")} · ${b("demo")} · ${b("export")} · ${b("webhook")} <url>`);
  console.log("");
  console.log(`  ${c.gray(`burnfuse ${VERSION} · MIT · keys stay on your machine`)}`);
  console.log("");
}

// ---------------------------------------------------------------------- main

export async function run(argv) {
  const { positional, flags } = parseArgs(argv);
  const command = positional.shift() || (flags.version ? "version" : flags.help ? "help" : "status");

  if (command === "version" || command === "--version") return console.log(VERSION);
  if (command === "help" || command === "--help") return cmdHelp();

  const { state, file } = loadState(flags.state);
  // Keep the resolved path handy without letting it leak into JSON output.
  Object.defineProperty(state, "__file", { value: file, enumerable: false, writable: true });

  switch (command) {
    case "status":
    case "overview":
    case "dashboard":
      return cmdOverview(state, flags);
    case "list":
      return cmdList(state, { flags });
    case "add":
      return cmdAdd(state, positional, flags);
    case "record":
      return cmdRecord(state, positional, flags);
    case "check":
      return cmdCheck(state, positional, flags);
    case "poll":
      return cmdPoll(state, positional, flags);
    case "trip":
    case "kill":
    case "cut":
      return cmdTrip(state, positional);
    case "arm":
    case "resume":
      return cmdArm(state, positional, flags);
    case "cap":
    case "limit":
      return cmdCap(state, positional);
    case "sensitivity":
    case "threshold":
      return cmdSensitivity(state, positional, flags);
    case "webhook":
      return cmdWebhook(state, positional);
    case "scan":
    case "audit":
      return cmdScan(state, positional, flags);
    case "watch":
    case "monitor":
      return cmdWatch(state, positional, flags);
    case "doctor":
      return cmdDoctor(state, flags);
    case "demo":
      return cmdDemo(state);
    case "export":
      return cmdExport(state);
    default:
      console.log(`\n  ${c.red("Unknown command:")} ${command}\n`);
      cmdHelp();
      process.exitCode = EXIT.error;
  }
}