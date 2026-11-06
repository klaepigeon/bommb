const {chromium}=require('playwright');(async()=>{const b=await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});const p=await b.newPage();p.on('pageerror',e=>console.log(e.stack));await p.goto('file://'+process.cwd()+'/dist/index.html?shots&q='+(process.argv[2]||'medium'));await p.waitForFunction(()=>window.__ready,null,{timeout:200000});
console.log(await p.evaluate(()=>{const G=window.__G;let meshes=0,cast=0,inst=0,byMat={};G.scene.traverse(o=>{if(o.isMesh){meshes++;if(o.castShadow)cast++;}});
const lights=[];G.scene.traverse(o=>{if(o.isLight)lights.push(o.type+(o.castShadow?'*':''))});
window.__view(4,4.6,2,0);window.__G.renderer.info.autoReset=false;window.__G.renderer.info.reset();window.__G.renderer.render(G.scene,G.camera);const r=window.__G.renderer.info.render;
return JSON.stringify({meshes,cast,props:G.props.length,colliders:G.colliders.length,lights:lights.join(' '),mainPassCalls:r.calls});}));await b.close()})()
