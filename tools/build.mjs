// Bundles src/ into single-file HTML builds. Modules are .js or .ts (TypeScript is
// transpiled per file with the compiler's transpileModule; run `npm run typecheck` for the
// type check itself).
//   dist/index.html     — standalone page for local play / static hosting
//   dist/rhapsody.html  — body-only variant for publishing as a claude.ai artifact
// The sequel (sequel/tools/build.mjs) builds from the same engine modules.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { ROOT, engineModules, embedFonts, scriptTag, fullPage } from './bundle.mjs';

const shell = embedFonts(readFileSync(join(ROOT, 'src', 'shell.html'), 'utf8'));
const { files, js } = engineModules();
const body = `${shell}\n${scriptTag(js)}`;
mkdirSync(join(ROOT, 'dist'), { recursive: true });
writeFileSync(join(ROOT, 'dist', 'rhapsody.html'), body);
writeFileSync(join(ROOT, 'dist', 'index.html'), fullPage(body));
console.log(`built ${files.length} modules (${files.filter((f) => f.endsWith('.ts')).length} TypeScript), ${(body.length / 1024).toFixed(0)} KB`);
