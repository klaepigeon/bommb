// RHAPSODY — the WebGL renderer. The world is still composed with Canvas2D into the
// 480x320 buffer (every sprite routine and every module that draws keeps working), but the
// frame is finished on the GPU:
//   1. LIGHT  the unlit world + a light map of coloured light (lamps, neon, windows,
//             headlights, sirens, fire, muzzle flashes). Normals come from the art itself:
//             brighter pixels stand proud, so every sprite, car and wall edge catches light
//             from the side it's coming from, in its colour. Shadows fill with night blue.
//   2. BLOOM  bright pixels are pulled out, blurred at half size and added back.
//   3. FINAL  bloom + the overlay layer (hard light, speech, weather, HUD: everything drawn
//             after lighting) at full screen resolution, with heat shimmer in the desert
//             noon, a colour split when you're hit, film grain and optional CRT lines.
// If WebGL isn't there, or the context is lost, the classic Canvas2D path takes over.
'use strict';
(function () {
  const BW = 480, BH = 320;
  const GL = (R.gl = { on: false, hurt: 0, t0: performance.now() });

  const VS = 'attribute vec2 p;varying vec2 v;void main(){v=p*0.5+0.5;gl_Position=vec4(p,0.0,1.0);}';
  const LUM = 'float lum(vec3 c){return dot(c,vec3(0.299,0.587,0.114));}';
  const FS_LIT = `precision mediump float;varying vec2 v;
uniform sampler2D uBase;uniform sampler2D uLight;uniform vec2 uTexel;uniform float uDark;uniform vec3 uNight;uniform float uNormal;uniform float uGain;
${LUM}
void main(){
  vec3 a=texture2D(uBase,v).rgb;
  if(uDark<0.01){gl_FragColor=vec4(a,1.0);return;}
  vec3 L=texture2D(uLight,v).rgb;
  vec2 lt=uTexel*3.0;
  float lx=lum(texture2D(uLight,v+vec2(lt.x,0.0)).rgb)-lum(texture2D(uLight,v-vec2(lt.x,0.0)).rgb);
  float ly=lum(texture2D(uLight,v+vec2(0.0,lt.y)).rgb)-lum(texture2D(uLight,v-vec2(0.0,lt.y)).rgb);
  vec2 ld=vec2(lx,ly);float lm=length(ld);
  float hl=lum(texture2D(uBase,v-vec2(uTexel.x,0.0)).rgb),hr=lum(texture2D(uBase,v+vec2(uTexel.x,0.0)).rgb);
  float hd=lum(texture2D(uBase,v-vec2(0.0,uTexel.y)).rgb),hu=lum(texture2D(uBase,v+vec2(0.0,uTexel.y)).rgb);
  vec3 N=normalize(vec3((hl-hr)*uNormal,(hd-hu)*uNormal,1.0));
  vec3 Ld=normalize(vec3(lm>0.002?ld/lm:vec2(0.0),0.65));
  float facing=clamp(0.25+1.25*dot(N,Ld),0.15,1.8);
  float amb=1.0-uDark*0.94;
  vec3 lit=a*(amb+L*uGain*facing*smoothstep(0.0,0.9,uDark));
  lit+=uNight*uDark*(1.0-clamp(lum(L)*1.5,0.0,1.0));
  lit+=L*L*0.06*uDark;
  gl_FragColor=vec4(lit,1.0);
}`;
  const FS_BRIGHT = `precision mediump float;varying vec2 v;uniform sampler2D uTex;uniform float uThr;${LUM}
void main(){vec3 c=texture2D(uTex,v).rgb;gl_FragColor=vec4(c*smoothstep(uThr,uThr+0.3,lum(c)),1.0);}`;
  const FS_BLUR = `precision mediump float;varying vec2 v;uniform sampler2D uTex;uniform vec2 uDir;
void main(){vec3 c=texture2D(uTex,v).rgb*0.227;
c+=(texture2D(uTex,v+uDir*1.385).rgb+texture2D(uTex,v-uDir*1.385).rgb)*0.316;
c+=(texture2D(uTex,v+uDir*3.231).rgb+texture2D(uTex,v-uDir*3.231).rgb)*0.070;
gl_FragColor=vec4(c,1.0);}`;
  const FS_FINAL = `precision mediump float;varying vec2 v;
uniform sampler2D uLit;uniform sampler2D uBloom;uniform sampler2D uOver;uniform float uTime;uniform float uHeat;uniform float uHurt;uniform float uGrain;uniform float uScan;uniform float uScanPx;uniform float uBloomK;
void main(){
  vec2 uv=v;
  if(uHeat>0.0){float n=sin(uv.y*140.0+uTime*6.0)*sin(uv.y*37.0-uTime*3.1);uv.x+=n*0.0022*uHeat*uv.y;}
  vec3 c;
  if(uHurt>0.01){float o=0.005*uHurt;c=vec3(texture2D(uLit,uv+vec2(o,0.0)).r,texture2D(uLit,uv).g,texture2D(uLit,uv-vec2(o,0.0)).b);}
  else c=texture2D(uLit,uv).rgb;
  c+=texture2D(uBloom,uv).rgb*uBloomK;
  vec4 o=texture2D(uOver,v);
  c=c*(1.0-o.a)+o.rgb;
  float gr=fract(sin(dot(gl_FragCoord.xy+vec2(uTime*61.0,uTime*17.0),vec2(12.9898,78.233)))*43758.5453);
  c+=(gr-0.5)*uGrain;
  if(uScan>0.0){float s=abs(sin(gl_FragCoord.y*3.14159/uScanPx));c*=1.0-uScan*(1.0-s)*0.45;}
  gl_FragColor=vec4(c,1.0);
}`;

  GL.supported = function () {
    try { const c = document.createElement('canvas'); return !!(c.getContext('webgl') || c.getContext('experimental-webgl')); } catch (e) { return false; }
  };
  GL.wanted = function (game) { const s = game.settings.renderer; return s ? s === 'gl' : true; };

  GL.setup = function (r) {
    if (this.r === r && this.gl) return true;
    const disp = r.display;
    let cv = document.getElementById('glview');
    if (!cv) {
      cv = document.createElement('canvas');
      cv.id = 'glview';
      cv.setAttribute('aria-hidden', 'true');
      Object.assign(cv.style, { position: 'absolute', left: '0', top: '0', width: '100%', height: '100%', pointerEvents: 'none', imageRendering: 'pixelated', display: 'block' });
      disp.insertAdjacentElement('afterend', cv);
    }
    const gl = cv.getContext('webgl', { alpha: false, antialias: false, depth: false, stencil: false, premultipliedAlpha: false, preserveDrawingBuffer: false, powerPreference: 'high-performance' }) || cv.getContext('experimental-webgl');
    if (!gl) return false;
    this.cv = cv; this.gl = gl; this.r = r;
    cv.addEventListener('webglcontextlost', (e) => { e.preventDefault(); this.fail('context lost'); }, { once: true });
    const sh = (type, src) => { const s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s)); return s; };
    const prog = (fs) => {
      const p = gl.createProgram();
      gl.attachShader(p, sh(gl.VERTEX_SHADER, VS)); gl.attachShader(p, sh(gl.FRAGMENT_SHADER, fs));
      gl.bindAttribLocation(p, 0, 'p'); gl.linkProgram(p);
      if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(p));
      const u = {}; const n = gl.getProgramParameter(p, gl.ACTIVE_UNIFORMS);
      for (let i = 0; i < n; i++) { const a = gl.getActiveUniform(p, i); u[a.name] = gl.getUniformLocation(p, a.name); }
      return { p, u };
    };
    this.P = { lit: prog(FS_LIT), bright: prog(FS_BRIGHT), blur: prog(FS_BLUR), final: prog(FS_FINAL) };
    const buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
    const tex = (w, h, filter) => {
      const t = gl.createTexture();
      gl.bindTexture(gl.TEXTURE_2D, t);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      if (w) gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
      return t;
    };
    const fbo = (w, h, filter) => { const t = tex(w, h, filter), f = gl.createFramebuffer(); gl.bindFramebuffer(gl.FRAMEBUFFER, f); gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, t, 0); return { t, f, w, h }; };
    this.T = { base: tex(0, 0, gl.NEAREST), over: tex(0, 0, gl.NEAREST), light: tex(0, 0, gl.LINEAR) };
    this.F = { lit: fbo(BW, BH, gl.NEAREST), b1: fbo(BW / 2, BH / 2, gl.LINEAR), b2: fbo(BW / 2, BH / 2, gl.LINEAR) };
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
    // the layer drawn after lighting
    r.ov = document.createElement('canvas'); r.ov.width = BW; r.ov.height = BH;
    r.ovg = r.ov.getContext('2d');
    return true;
  };
  GL.fail = function (why) {
    console.warn('WebGL renderer off:', why);
    this.on = false;
    if (this.r) this.r.glOn = false;
    if (this.cv) this.cv.style.display = 'none';
    this.gl = null;
    const g = R.game;
    if (g && g.ui && g.started) g.ui.toast('Graphics fell back to the classic renderer.', 'warn');
  };
  GL.apply = function (game) {
    const r = game.renderer;
    if (!r) return;
    const want = this.wanted(game) && this.supported();
    if (want) {
      try { if (!this.setup(r)) throw new Error('no context'); } catch (e) { this.fail(e.message); return; }
      this.on = true; r.glOn = true; this.cv.style.display = 'block';
      this.size();
    } else { this.on = false; r.glOn = false; if (this.cv) this.cv.style.display = 'none'; }
  };
  GL.size = function () {
    if (!this.cv || !this.r) return;
    const d = this.r.display;
    if (this.cv.width !== d.width || this.cv.height !== d.height) { this.cv.width = d.width; this.cv.height = d.height; }
  };
  const upload = (gl, t, src, premul) => {
    gl.bindTexture(gl.TEXTURE_2D, t);
    gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, !!premul);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, src);
  };

  // the whole frame on the GPU
  GL.present = function (r) {
    const gl = this.gl;
    if (!gl || gl.isContextLost()) { this.fail('lost'); return false; }
    const game = r.game, pl = game.player;
    try {
      this.size();
      const lit = !!r.glFrame; // a world frame (the title screen has no lighting pass)
      if (!lit) { r.ovg && r.ovg.clearRect(0, 0, BW, BH); r.lg.clearRect(0, 0, r.light.width, r.light.height); }
      upload(gl, this.T.base, r.cv, false);
      upload(gl, this.T.over, r.ov, true);
      upload(gl, this.T.light, r.light, false);
      const dark = lit ? (r.glDark || 0) : 0;
      const t = (performance.now() - this.t0) / 1000;
      const draw = (P, fb, w, h, texs, set) => {
        gl.bindFramebuffer(gl.FRAMEBUFFER, fb ? fb.f : null);
        gl.viewport(0, 0, w, h);
        gl.useProgram(P.p);
        let i = 0;
        for (const [name, tx] of texs) { gl.activeTexture(gl.TEXTURE0 + i); gl.bindTexture(gl.TEXTURE_2D, tx); gl.uniform1i(P.u[name], i); i++; }
        set && set(P.u);
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
      };
      const F = this.F, T = this.T;
      // 1. light the world
      draw(this.P.lit, F.lit, BW, BH, [['uBase', T.base], ['uLight', T.light]], (u) => {
        gl.uniform2f(u.uTexel, 1 / BW, 1 / BH); gl.uniform1f(u.uDark, dark);
        gl.uniform3f(u.uNight, 0.035, 0.04, 0.12); gl.uniform1f(u.uNormal, 3.2); gl.uniform1f(u.uGain, pl && pl.room ? 1.3 : 1.75);
      });
      // 2. bloom at half size
      const bloomK = dark > 0.05 ? 0.55 + dark * 0.6 : 0.22;
      draw(this.P.bright, F.b1, BW / 2, BH / 2, [['uTex', F.lit.t]], (u) => gl.uniform1f(u.uThr, dark > 0.05 ? 0.62 : 0.85));
      for (let k = 0; k < 2; k++) {
        draw(this.P.blur, F.b2, BW / 2, BH / 2, [['uTex', F.b1.t]], (u) => gl.uniform2f(u.uDir, (k + 1) * 2 / BW, 0));
        draw(this.P.blur, F.b1, BW / 2, BH / 2, [['uTex', F.b2.t]], (u) => gl.uniform2f(u.uDir, 0, (k + 1) * 2 / BH));
      }
      // 3. to the screen
      this.hurt = Math.max(0, this.hurt - 0.04);
      const heat = R.dust && R.dust.heatOn ? 1 : 0;
      const crt = game.settings.crt ? 1 : 0;
      draw(this.P.final, null, this.cv.width, this.cv.height, [['uLit', F.lit.t], ['uBloom', F.b1.t], ['uOver', T.over]], (u) => {
        gl.uniform1f(u.uTime, t); gl.uniform1f(u.uHeat, heat); gl.uniform1f(u.uHurt, this.hurt);
        gl.uniform1f(u.uGrain, 0.035); gl.uniform1f(u.uScan, crt); gl.uniform1f(u.uScanPx, this.cv.height / BH); gl.uniform1f(u.uBloomK, bloomK);
      });
      r.glFrame = false;
      return true;
    } catch (e) { this.fail(e.message); return false; }
  };

  // ---------------------------------------------------------------- hooks
  const RP = R.Renderer.prototype;
  // after the lighting pass, everything else is drawn into the overlay layer
  RP.afterLighting = function (g) {
    if (!this.glOn || !this.ovg) return g;
    const o = this.ovg;
    o.setTransform(1, 0, 0, 1, 0, 0);
    o.clearRect(0, 0, BW, BH);
    o.imageSmoothingEnabled = false;
    o.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    this.glFrame = true;
    return o;
  };
  const bResize = RP.resize;
  RP.resize = function () { const r = bResize.apply(this, arguments); if (GL.on) GL.size(); return r; };
  GL.init = function (game) {
    this.apply(game);
    if (this.wired) return;
    this.wired = true;
    // a hit splits the colours for a moment
    const U = R.UI.prototype, bHurt = U.hurtFlash;
    if (bHurt) U.hurtFlash = function (amt) { GL.hurt = Math.min(1, GL.hurt + (amt || 10) / 25); return bHurt.apply(this, arguments); };
    // settings: renderer and CRT lines
    const bTab = U.openMenuTab;
    U.openMenuTab = function (tab) {
      const r = bTab.apply(this, arguments);
      if (tab !== 'settings') return r;
      const body = document.getElementById('mbody'), st = this.game.settings;
      if (!body || body.querySelector('#sRend')) return r;
      const cur = st.renderer || (GL.supported() ? 'gl' : 'classic');
      body.insertAdjacentHTML('afterbegin', `<div class="set"><label for="sRend">Graphics</label><select id="sRend"><option value="gl" ${cur === 'gl' ? 'selected' : ''} ${GL.supported() ? '' : 'disabled'}>Modern (WebGL lighting, bloom)</option><option value="classic" ${cur === 'classic' ? 'selected' : ''}>Classic</option></select></div><div class="set"><label for="sCrt">CRT scanlines</label><input id="sCrt" type="checkbox" ${st.crt ? 'checked' : ''}></div>`);
      body.querySelector('#sRend').addEventListener('change', (e) => { st.renderer = e.target.value; this.game.saveSettings(); GL.apply(this.game); });
      body.querySelector('#sCrt').addEventListener('change', (e) => { st.crt = e.target.checked; this.game.saveSettings(); });
      return r;
    };
  };
})();
