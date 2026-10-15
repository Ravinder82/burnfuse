import { test } from "node:test";
import assert from "node:assert/strict";
import { assess, evaluate, isOverCap, isSpike, mean, stdDev, sigma, projectBurn, shouldPauseOnBreach } from "../src/stats.js";
import { readPath, getProvider, providers, revokeHint } from "../src/providers.js";
import { requiresKey, fetchSpend } from "../src/poll.js";
import { mask } from "../src/env.js";

test("mean and stdDev behave", () => {
  assert.equal(mean([]), 0);
  assert.equal(mean([2, 4]), 3);
  assert.equal(stdDev([5]), 0);
  assert.ok(Math.abs(stdDev([2, 4, 4, 4, 5, 5, 7, 9]) - 2) < 1e-9);
});

test("baseline uses only history, not the current reading", () => {
  const r = evaluate([1, 1, 1], 10, {});
  assert.equal(r.baseline, 1);
  assert.ok(r.z > 2.5);
});

test("sigma is floored so quiet keys do not false-trip", () => {
  const r = evaluate([1, 1, 1, 1], 1.05, { minStdDev: 0.1 });
  assert.ok(r.z < 2.5, `z was ${r.z}`);
});

test("a clear spike trips", () => {
  const a = assess({ hourlyLimit: 100, readings: [1, 1.1, 0.9, 1.2, 1, 1.1].map((c) => ({ cost: c })) }, 12, {});
  assert.equal(a.spike, true);
  assert.equal(a.breach, true);
});

test("crossing the cap trips even without a spike", () => {
  const a = assess({ hourlyLimit: 5, readings: [4.9, 4.9, 4.9, 4.9].map((c) => ({ cost: c })) }, 5.5, {});
  assert.equal(a.overCap, true);
  assert.equal(a.breach, true);
});

test("a normal reading does not trip", () => {
  const a = assess({ hourlyLimit: 5, readings: [1.1, 1.2, 1.0, 1.15, 1.05].map((c) => ({ cost: c })) }, 1.2, {});
  assert.equal(a.breach, false);
});

test("first ever reading never trips on spike alone", () => {
  const a = assess({ hourlyLimit: 100, readings: [] }, 50, {});
  assert.equal(a.spike, false);
  assert.equal(a.breach, false);
});

test("cap helpers", () => {
  assert.equal(isOverCap(6, 5), true);
  assert.equal(isOverCap(5, 5), false);
  assert.equal(isSpike(2.5, 2.5), true);
});

test("sigma renders a signed z", () => {
  assert.equal(sigma(2.456), "+2.46σ");
  assert.equal(sigma(-1.2), "-1.20σ");
});

test("projectBurn multiplies", () => {
  assert.equal(projectBurn(10, 6), 60);
});

test("readPath walks arrays and objects", () => {
  const json = { data: [{ results: [{ amount: { value: 3.5 } }] }] };
  assert.equal(readPath(json, "data.0.results.0.amount.value"), 3.5);
  assert.equal(readPath(json, "data.9.missing"), undefined);
});

test("providers parse their documented shapes", () => {
  assert.equal(
    providers.openai.parse({ data: [{ results: [{ amount: { value: 1.25 } }, { amount: { value: 0.75 } }] }] }),
    2,
  );
  assert.equal(providers.openrouter.parse({ data: { usage: 4.2 } }), 4.2);
  // Older OpenRouter responses only carried the daily counter.
  assert.equal(providers.openrouter.parse({ data: { usage_daily: 0.4 } }), 0.4);
  // Anthropic reports decimal strings in cents, so two results are a hundredth.
  assert.equal(
    providers.anthropic.parse({
      data: [{ results: [{ amount: "123.45" }, { amount: "76.55" }] }],
    }),
    2,
  );
  assert.equal(providers.anthropic.parse({ data: [] }), 0);
});

test("the live providers report an endpoint and count money up", () => {
  for (const id of ["openai", "anthropic", "openrouter"]) {
    assert.equal(providers[id].measuresTotal, true, `${id} counts up`);
    assert.equal(typeof providers[id].spendUrl, "function", `${id} has an address`);
    assert.ok(providers[id].spendUrl(), `${id} builds its address`);
  }

  // Anthropic's cost report is daily-only and needs an explicit day window.
  const url = providers.anthropic.spendUrl();
  assert.ok(url.includes("/v1/organizations/cost_report"));
  assert.ok(url.includes("bucket_width=1d"));
  assert.ok(url.includes("starting_at="));

  // ...and authenticates with its own header rather than a bearer token.
  assert.equal(providers.anthropic.spendHeaders("sk-ant-admin").Authorization, undefined);
  assert.equal(providers.anthropic.spendHeaders("sk-ant-admin")["x-api-key"], "sk-ant-admin");
  assert.equal(providers.anthropic.spendHeaders("sk-ant-admin")["anthropic-version"], "2023-06-01");
});

test("a provider with no public read says so", () => {
  for (const id of ["replicate", "groq", "aws"]) {
    assert.equal(providers[id].spendUrl, null, `${id} has no endpoint`);
  }
});

test("a read with no key says so instead of blaming the key", async () => {
  const entry = { id: "a", provider: "openai" };
  assert.equal(requiresKey(entry), true);

  const result = await fetchSpend(entry, null);
  assert.equal(result.ok, false);
  assert.equal(result.reason, "no-key");
  assert.match(result.message, /No OpenAI key given yet/);
  // It never reached the network, so there is no status to misread as a 401.
  assert.equal(result.status, undefined);
});

test("a custom endpoint is still tried without a key", () => {
  // A custom address may be public, so only the user can know whether it wants one.
  assert.equal(requiresKey({ id: "d", provider: "custom" }), false);
  assert.equal(requiresKey({ id: "d", provider: "unknown-thing" }), false);
});

test("a trip pauses a key only when asked — by the blanket rule or by the key", () => {
  const off = { autoKill: false };
  assert.equal(shouldPauseOnBreach(off, {}), false);
  assert.equal(shouldPauseOnBreach(off, { autoKillOnBreach: false }), false);
  assert.equal(shouldPauseOnBreach({ autoKill: true }, {}), true);
  assert.equal(shouldPauseOnBreach(off, { autoKillOnBreach: true }), true);
});

test("every provider that takes a key says where to revoke it", () => {
  for (const [id, p] of Object.entries(providers)) {
    if (!p.signal) continue; // custom takes whatever the user gives it
    assert.ok(p.whereToRevoke, `${id} should say where its key is revoked`);
  }
  // And no provider claims a revocation endpoint: reading spend and revoking a
  // credential are different permissions, and this side only ever does the first.
  for (const [id, p] of Object.entries(providers)) {
    assert.equal(p.killUrl, undefined, `${id} must not carry a revocation endpoint`);
  }
});

test("a trip names the console page where the key is revoked", () => {
  assert.match(revokeHint({ provider: "openai" }), /OpenAI dashboard/);
  assert.match(revokeHint({ provider: "anthropic" }), /Claude Console/);
  // An unknown provider still gets a usable sentence rather than a dead end.
  assert.match(revokeHint({ provider: "nope" }), /where you issued it/);
});

test("an unknown provider is described as itself, not renamed", () => {
  // The app names an id it does not know after the id; the CLI used to call it
  // "Custom endpoint", which pointed people at a form that would not help.
  assert.equal(getProvider("nope").label, "Nope");
  assert.equal(getProvider("my-thing").label, "My Thing");
  assert.equal(getProvider("custom").label, "Your own endpoint");
  // It still behaves like a custom endpoint, so its own cost URL keeps working.
  const entry = { provider: "nope", source: { spendUrl: "https://example.com/cost.json" } };
  assert.equal(getProvider("nope").spendUrl(entry), "https://example.com/cost.json");
});

test("mask never reveals the middle of a key", () => {
  const out = mask("sk-proj-verysecretvalue1234");
  assert.ok(out.startsWith("sk-p"));
  assert.ok(out.endsWith("1234"));
  assert.ok(!out.includes("secret"));
});