#!/usr/bin/env node
import { run } from "../src/index.js";

run(process.argv.slice(2)).catch((err) => {
  process.stderr.write(`\n  burnfuse: ${err?.message || err}\n\n`);
  process.exit(1);
});