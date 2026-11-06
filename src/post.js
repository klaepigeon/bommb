// Film grain and a soft vignette. Kept light: the picture should look like a camera in a
// dark room, not a filter.
export const grainShader = {
  uniforms: { tDiffuse: { value: null }, time: { value: 0 }, amount: { value: 0.045 }, vig: { value: 0.42 }, dark: { value: 0 } },
  vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.); }',
  fragmentShader: `
    uniform sampler2D tDiffuse; uniform float time, amount, vig, dark; varying vec2 vUv;
    float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }
    void main(){
      vec4 c = texture2D(tDiffuse, vUv);
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
