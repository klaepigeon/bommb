// Bundles src/ into single-file HTML builds (no dependencies).
//   dist/index.html     — standalone page for local play / static hosting
//   dist/rhapsody.html  — body-only variant for publishing as a claude.ai artifact
import { readFileSync, writeFileSync, readdirSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const src = join(root, 'src');
const shell = readFileSync(join(src, 'shell.html'), 'utf8');
const files = readdirSync(src).filter((f) => /^\d\d_.*\.js$/.test(f)).sort();
const js = files.map((f) => `// ---- ${f}\n` + readFileSync(join(src, f), 'utf8')).join('\n');
const body = `${shell}\n<script>\n${js.replace(/<\/script/gi, '<\\/script')}\n</script>\n`;
mkdirSync(join(root, 'dist'), { recursive: true });
writeFileSync(join(root, 'dist', 'rhapsody.html'), body);
writeFileSync(
  join(root, 'dist', 'index.html'),
  `<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">\n</head>\n<body>\n${body}</body>\n</html>\n`
);
console.log(`built ${files.length} modules, ${(body.length / 1024).toFixed(0)} KB`);
