// Shared bundling for game 1 and the sequel: collects the numbered engine modules from a src
// directory (.js as-is, .ts transpiled per file), and embeds the pixel fonts into a shell.
import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

export const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

let ts = null;
const loadTs = () => {
  if (ts) return ts;
  const req = createRequire(import.meta.url);
  try { ts = req('typescript'); } catch { ts = req('/opt/node22/lib/node_modules/typescript'); }
  return ts;
};

export function compileModule(dir, f) {
  const code = readFileSync(join(dir, f), 'utf8');
  if (!f.endsWith('.ts')) return code;
  const t = loadTs();
  const out = t.transpileModule(code, { fileName: f, reportDiagnostics: true, compilerOptions: { target: t.ScriptTarget.ES2020, module: t.ModuleKind.None, removeComments: false, isolatedModules: false } });
  if (out.diagnostics && out.diagnostics.length) {
    for (const d of out.diagnostics) console.error(`${f}: ${t.flattenDiagnosticMessageText(d.messageText, '\n')}`);
    process.exit(1);
  }
  return out.outputText.replace(/^"use strict";\n/, '').replace(/\n\/\/# sourceMappingURL=.*$/, '');
}

// the engine: every NN_*.js / NN_*.ts in src, in name order
export function engineModules(dir = join(ROOT, 'src')) {
  const files = readdirSync(dir).filter((f) => /^\d\d_.*\.(js|ts)$/.test(f) && !/\.d\.ts$/.test(f)).sort();
  return { files, js: files.map((f) => `// ---- ${f}\n` + compileModule(dir, f)).join('\n') };
}

// the pixel fonts (SIL Open Font License) are embedded so text stays crisp offline
export function embedFonts(shell) {
  const font = (file, family) => `@font-face { font-family: '${family}'; font-style: normal; font-weight: 400; font-display: block; src: url(data:font/ttf;base64,${readFileSync(join(ROOT, 'assets', 'fonts', file)).toString('base64')}) format('truetype'); }`;
  const fontCss = `<style>\n${font('Silkscreen-Regular.ttf', 'Silkscreen')}\n${font('PixelifySans-Regular.ttf', 'Pixelify Sans')}\n</style>`;
  return shell.replace(/<link rel="preconnect"[^>]*>\n?/g, '').replace(/<link rel="stylesheet" href="https:\/\/fonts.googleapis.com[^>]*>/, fontCss);
}

export const scriptTag = (js) => `<script>\n${js.replace(/<\/script/gi, '<\\/script')}\n</script>\n`;

export function fullPage(body) {
  return `<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">\n</head>\n<body>\n${body}</body>\n</html>\n`;
}
