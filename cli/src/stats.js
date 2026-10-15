/**
 * The burn-rate math. Deliberately small and explainable:
 *
 *   baseline  = mean of your recent hourly spend
 *   sigma     = standard deviation of that history (floored, so tiny
 *               amounts of noise never trigger a false trip)
 *   z         = (current - baseline) / sigma
 *   trip      = current crosses the hourly cap, OR z crosses the sensitivity
 *
 * Everything here is pure so it is trivial to test and audit.
 */

export function mean(values) {
  if (!values.length) return 0;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

export function stdDev(values) {
  if (values.length < 2) return 0;
  const m = mean(values);
  const variance = values.reduce((acc, v) => acc + (v - m) ** 2, 0) / values.length;
  return Math.sqrt(variance);
}

/**
 * @param {number[]} history past hourly readings, oldest first
 * @param {number}   current the reading being evaluated
 * @param {object}   settings
 */
export function evaluate(history, current, settings = {}) {
  const zThreshold = Number(settings.zThreshold ?? 2.5);
  const minStdDev = Number(settings.minStdDev ?? 0.1);
  const baseline = mean(history);
  const sigma = Math.max(stdDev(history), minStdDev);
  const z = history.length ? (current - baseline) / sigma : 0;
  return { baseline, sigma, current, z, zThreshold, minStdDev };
}

export function isOverCap(reading, hourlyLimit) {
  return Number(reading) > Number(hourlyLimit);
}

/**
 * On a breach, should BurnFuse stop reading this key? The blanket rule, or the
 * key's own flag. Not protection — see the note on `autoKill` in the store.
 */
export function shouldPauseOnBreach(entry, settings = {}) {
  return Boolean(settings.autoKillOnBreach) || Boolean(entry.autoKill);
}

export function isSpike(z, zThreshold) {
  return Number(z) >= Number(zThreshold);
}

/**
 * Turn a stored entry + a fresh reading into a verdict.
 */
export function assess(entry, reading, settings = {}) {
  const window = Number(settings.historyWindow ?? 24);
  const history = entry.readings.slice(-window).map((r) => Number(r.cost));
  const stats = evaluate(history, Number(reading), settings);
  const overCap = isOverCap(reading, entry.hourlyLimit);
  const spike = isSpike(stats.z, stats.zThreshold);
  return {
    ...stats,
    overCap,
    spike,
    breach: overCap || spike,
    hourlyLimit: Number(entry.hourlyLimit),
    samples: history.length,
  };
}

export function money(n, digits = 2) {
  return `$${Number(n || 0).toFixed(digits)}`;
}

export function pct(n) {
  const p = Math.round(Number(n) * 100);
  return `${p > 0 ? "+" : ""}${p}%`;
}

/** Render a z-score the way people read it: +2.45σ */
export function sigma(n) {
  const v = Number(n || 0);
  return `${v >= 0 ? "+" : ""}${v.toFixed(2)}σ`;
}

/** Delta of a reading against a baseline, as a readable multiple. */
export function multiple(current, baseline) {
  if (!baseline) return "—";
  return `${(Number(current) / Number(baseline)).toFixed(1)}×`;
}

/**
 * Rough projection used for "what could this cost me" honesty checks.
 * Assumes the current burn rate holds for `hours`.
 */
export function projectBurn(current, hours) {
  return Number(current || 0) * Number(hours || 0);
}