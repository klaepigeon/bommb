// Bundles src/ into single-file HTML builds. Modules are .js or .ts (TypeScript is
// transpiled per file with the compiler's transpileModule; run `npm run typecheck` for the
// type check itself).
//   dist/index.html     — standalone page for local play / static hosting
//   dist/rhapsody.html  — body-only variant for publishing as a claude.ai artifact
import { readFileSync, writeFileSync, readdirSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const src = join(root, 'src');
// the pixel fonts (SIL Open Font License) are embedded so text stays crisp offline
const font = (file, family) => `@font-face { font-family: '${family}'; font-style: normal; font-weight: 400; font-display: block; src: url(data:font/ttf;base64,${readFileSync(join(root, 'assets', 'fonts', file)).toString('base64')}) format('truetype'); }`;
const fontCss = `<style>\n${font('Silkscreen-Regular.ttf', 'Silkscreen')}\n${font('PixelifySans-Regular.ttf', 'Pixelify Sans')}\n</style>`;
const shell = readFileSync(join(src, 'shell.html'), 'utf8')
  .replace(/<link rel="preconnect"[^>]*>\n?/g, '')
  .replace(/<link rel="stylesheet" href="https:\/\/fonts.googleapis.com[^>]*>/, fontCss);
const files = readdirSync(src).filter((f) => /^\d\d_.*\.(js|ts)$/.test(f) && !/\.d\.ts$/.test(f)).sort();
let ts = null;
const loadTs = () => {
  if (ts) return ts;
  const req = createRequire(import.meta.url);
  try { ts = req('typescript'); } catch { ts = req('/opt/node22/lib/node_modules/typescript'); }
  return ts;
};
const compile = (f) => {
  const code = readFileSync(join(src, f), 'utf8');
  if (!f.endsWith('.ts')) return code;
  const t = loadTs();
  const out = t.transpileModule(code, { fileName: f, reportDiagnostics: true, compilerOptions: { target: t.ScriptTarget.ES2020, module: t.ModuleKind.None, removeComments: false, isolatedModules: false } });
  if (out.diagnostics && out.diagnostics.length) {
    for (const d of out.diagnostics) console.error(`${f}: ${t.flattenDiagnosticMessageText(d.messageText, '\n')}`);
    process.exit(1);
  }
  return out.outputText.replace(/^"use strict";\n/, '').replace(/\n\/\/# sourceMappingURL=.*$/, '');
};
const js = files.map((f) => `// ---- ${f}\n` + compile(f)).join('\n');
const body = `${shell}\n<script>\n${js.replace(/<\/script/gi, '<\\/script')}\n</script>\n`;
mkdirSync(join(root, 'dist'), { recursive: true });
writeFileSync(join(root, 'dist', 'rhapsody.html'), body);
writeFileSync(
  join(root, 'dist', 'index.html'),
  `<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">\n</head>\n<body>\n${body}</body>\n</html>\n`
);
console.log(`built ${files.length} modules (${files.filter((f) => f.endsWith('.ts')).length} TypeScript), ${(body.length / 1024).toFixed(0)} KB`);
