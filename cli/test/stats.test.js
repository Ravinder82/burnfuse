import { test } from "node:test";
import assert from "node:assert/strict";
import { assess, evaluate, isOverCap, isSpike, mean, stdDev, sigma, projectBurn } from "../src/stats.js";
import { readPath, getProvider, providers } from "../src/providers.js";
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

test("unknown provider falls back to custom", () => {
  assert.equal(getProvider("nope").label, getProvider("custom").label);
});

test("mask never reveals the middle of a key", () => {
  const out = mask("sk-proj-verysecretvalue1234");
  assert.ok(out.startsWith("sk-p"));
  assert.ok(out.endsWith("1234"));
  assert.ok(!out.includes("secret"));
});