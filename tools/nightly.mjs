// Nightly balance check: runs the playtest bot once per playstyle, pulls the end-of-run
// numbers (cash, rep, heat, tick time, errors and each system's counters) and compares them
// with tools/baseline.json. Anything that moved more than DRIFT (default 40%) is flagged, so
// a change that makes hijacking twice as lucrative shows up the next morning.
//   node tools/build.mjs && node tools/nightly.mjs [days] [--update-baseline]
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const DAYS = +(process.argv.find((a) => /^\d+$/.test(a)) || 12);
const UPDATE = process.argv.includes('--update-baseline');
const DRIFT = +(process.env.DRIFT || 0.4);
const STYLES = (process.env.STYLES || 'all,shark,fixer,hijacker').split(',');
const OUT = join(HERE, '..', 'nightly-out');
mkdirSync(OUT, { recursive: true });
const BASE = join(HERE, 'baseline.json');
const baseline = existsSync(BASE) ? JSON.parse(readFileSync(BASE, 'utf8')) : {};

// the numbers worth watching, from the last daily snapshot
const pick = (rep) => {
  const d = rep.days[rep.days.length - 1] || {};
  const num = (v) => (typeof v === 'number' && isFinite(v) ? v : null);
  const out = { errors: (rep.errors || []).length };
  for (const [k, v] of Object.entries(d)) if (num(v) != null && !/^(gameDay|people)$/.test(k)) out[k] = v;
  // "a/b" counters like swag "3/$4200"
  if (typeof d.swag === 'string') { const m = d.swag.match(/(\d+)\/\$(\d+)/); if (m) { out.trucks = +m[1]; out.swagEarned = +m[2]; } }
  return out;
};

const results = {};
for (const style of STYLES) {
  const dir = join(OUT, style);
  process.stdout.write(`\n== ${style}: ${DAYS} days ==\n`);
  try { execFileSync('node', [join(HERE, 'playtest.mjs'), String(DAYS), dir, style], { stdio: ['ignore', 'inherit', 'inherit'], timeout: 1000 * 60 * 40 }); } catch (e) { results[style] = { failed: String(e.message).slice(0, 200) }; continue; }
  results[style] = pick(JSON.parse(readFileSync(join(dir, 'report.json'), 'utf8')));
}

const lines = [`# Nightly balance: ${new Date().toISOString().slice(0, 10)} · ${DAYS} days per style`, ''];
let flagged = 0;
for (const [style, r] of Object.entries(results)) {
  lines.push(`## ${style}`);
  if (r.failed) { lines.push(`**run failed:** ${r.failed}`, ''); flagged++; continue; }
  const b = baseline[style] || {};
  lines.push('| metric | now | baseline | change |', '|---|---|---|---|');
  for (const [k, v] of Object.entries(r)) {
    const was = b[k];
    let change = '';
    if (typeof was === 'number') {
      const rel = was === 0 ? (v === 0 ? 0 : 1) : (v - was) / Math.abs(was);
      change = `${rel >= 0 ? '+' : ''}${Math.round(rel * 100)}%`;
      if (Math.abs(rel) > DRIFT && Math.abs(v - was) > 2) { change += ' ⚠'; flagged++; }
    }
    if (k === 'errors' && v > 0) { change += ' ⚠ errors'; flagged++; }
    lines.push(`| ${k} | ${v} | ${was ?? '—'} | ${change} |`);
  }
  lines.push('');
}
lines.push(flagged ? `**${flagged} metric(s) drifted more than ${Math.round(DRIFT * 100)}% or errored.**` : 'Everything within tolerance.');
writeFileSync(join(OUT, 'summary.md'), lines.join('\n'));
if (UPDATE) { writeFileSync(BASE, JSON.stringify(results, null, 1)); console.log('baseline updated'); }
console.log('\n' + lines.join('\n'));
process.exitCode = flagged && !UPDATE ? 1 : 0;
