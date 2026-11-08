// Boot the build headless and report load errors (node tools/boot.cjs)
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage();
  p.on('pageerror', (e) => console.log('PAGEERROR', e.stack.split('\n').slice(0, 6).join('\n')));
  p.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') console.log(m.type(), m.text().slice(0, 300)); });
  const t0 = Date.now();
  await p.goto('file://' + process.cwd() + '/dist/index.html?shots');
  await p.waitForFunction(() => window.__ready || document.getElementById('loadMsg').textContent.startsWith('Something'), null, { timeout: 300000 });
  console.log(await p.evaluate(() => document.getElementById('loadMsg').textContent) || 'booted', ((Date.now() - t0) / 1000).toFixed(1) + 's');
  await b.close();
})();
