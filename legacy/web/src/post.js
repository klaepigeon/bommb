// Film grain and a soft vignette. Kept light: the picture should look like a camera in a
// dark room, not a filter.
export const grainShader = {
  uniforms: { tDiffuse: { value: null }, time: { value: 0 }, amount: { value: 0.045 }, vig: { value: 0.42 }, dark: { value: 0 }, decay: { value: 0 }, tear: { value: 0 } },
  vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.); }',
  fragmentShader: `
    uniform sampler2D tDiffuse; uniform float time, amount, vig, dark, decay, tear; varying vec2 vUv;
    float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }
    void main(){
      vec2 uv = vUv;
      // reality slipping: a band of the picture shoved sideways now and then
      if (tear > 0.05) { float band = step(abs(uv.y - fract(tear * 7.31)), 0.02 + tear * 0.05); uv.x += band * (tear - 0.5) * 0.06 * decay; }
      // colour fringes at the edges as it goes
      vec2 dd = (uv - 0.5) * decay * 0.006;
      vec4 c = vec4(texture2D(tDiffuse, uv + dd).r, texture2D(tDiffuse, uv).g, texture2D(tDiffuse, uv - dd).b, 1.0);
      // and the colour itself drains away
      float lu = dot(c.rgb, vec3(0.299, 0.587, 0.114));
      c.rgb = mix(c.rgb, vec3(lu), decay * 0.55);
      // blocks of the image drop out, briefly, as if not rendered
      float blk = h(floor(uv * vec2(32.0, 18.0)) + floor(time * 12.0));
      if (blk < max(0.0, decay - 0.45) * max(0.0, decay - 0.45) * 0.004) c.rgb = vec3(lu * 0.25);
      // grain is strongest in the shadows, like a sensor pushed too far
      float lum = dot(c.rgb, vec3(0.299,0.587,0.114));
      float n = h(vUv * vec2(1920.,1080.) + fract(time * 7.13) * 97.) - 0.5;
      c.rgb += n * amount * (1.2 - lum);
      vec2 d = vUv - 0.5; float v = smoothstep(0.85, 0.2, length(d * vec2(1.0, 0.85)) * (1.0 + vig));
      c.rgb *= mix(1.0, v, 0.85);
      // peephole: a fisheye-ish dark ring
      if (dark > 0.5) { float r = length(d * vec2(1.6, 1.0)); c.rgb *= smoothstep(0.32, 0.26, r); }
      gl_FragColor = c;
    }`,
};
