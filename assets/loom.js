/* I AM RATAN — the loom.

   A real-time cloth surface in WebGL. Not a video, not a gradient: a subdivided
   plane displaced in the vertex stage and shaded with a fabric BRDF in the
   fragment stage, running the house's own twenty-five colours.

   Why anisotropic sheen and not Blinn-Phong. A woven surface does not reflect
   like a sphere. Light glances along the thread direction, so the highlight is a
   band perpendicular to the warp rather than a dot — that single term is the
   difference between reading as cotton and reading as plastic. The weave itself
   perturbs the normal procedurally, so each of the twenty-five cloths carries its
   own warp and weft frequency, bump depth and roughness.

   No library. One vertex shader, one fragment shader, one index buffer. */

(function (root, doc) {
  'use strict';

  var VERT = [
    'attribute vec2 aUv;',
    'uniform float uTime, uAmp, uAspect;',
    'varying vec2 vUv;',
    'varying vec3 vPos, vNrm;',

    /* The cloth. Pinned along the top edge and free below, so the amplitude
       grows with distance from the pin the way a hung panel actually moves. */
    'vec3 clothAt(vec2 uv){',
    '  float x = (uv.x - 0.5) * 2.0 * uAspect;',
    '  float y = (uv.y - 0.5) * 2.0;',
    '  float hang = pow(clamp(0.5 - y * 0.5 + 0.5, 0.0, 1.0), 1.35);',
    '  float t = uTime;',
    '  float z = sin(x * 2.1 + t * 0.55) * 0.210',
    '          + sin(y * 1.63 - t * 0.42) * 0.155',
    '          + sin((x + y) * 1.27 + t * 0.31) * 0.115',
    '          + sin((x - y) * 2.9 - t * 0.24) * 0.052',
    '          + sin((x * 1.7 - y * 2.3) + t * 0.19) * 0.034;',
    '  return vec3(x, y, z * hang * uAmp);',
    '}',

    'void main(){',
    '  vUv = aUv;',
    '  vec3 p = clothAt(aUv);',
    /* analytic normal by finite difference — cheaper and steadier than passing
       one in, and it stays correct as the displacement animates */
    '  float e = 0.004;',
    '  vec3 dx = clothAt(aUv + vec2(e, 0.0)) - p;',
    '  vec3 dy = clothAt(aUv + vec2(0.0, e)) - p;',
    '  vNrm = normalize(cross(dx, dy));',
    '  vPos = p;',
    '  gl_Position = vec4(p.x / uAspect, p.y, 0.0, 1.0);',
    '}'
  ].join('\n');

  var FRAG = [
    'precision highp float;',
    'varying vec2 vUv;',
    'varying vec3 vPos, vNrm;',
    'uniform vec3 uColor, uLight;',
    'uniform float uWarp, uWeft, uBump, uSheen, uRough, uAmbient, uPattern;',

    /* the weave, as a normal perturbation. uPattern shifts the weft by the warp
       to make a twill rather than a plain crossing. */
    'vec3 weaveNormal(vec3 n, vec2 uv){',
    '  float u = uv.x * uWarp;',
    '  float v = uv.y * uWeft;',
    '  float du = cos(u + sin(v * 0.5) * uPattern);',
    '  float dv = cos(v + sin(u * 0.5) * uPattern * 0.6);',
    '  return normalize(n + vec3(du * uBump, dv * uBump * 0.86, 0.0));',
    '}',

    'void main(){',
    '  vec3 n = weaveNormal(vNrm, vUv);',
    '  vec3 L = normalize(uLight - vPos);',
    '  vec3 V = vec3(0.0, 0.0, 1.0);',
    '  vec3 H = normalize(L + V);',

    '  float diff = max(dot(n, L), 0.0);',

    /* Anisotropic sheen. The tangent runs along the warp, and the highlight is
       the band where H is most perpendicular to it. */
    '  vec3 T = normalize(vec3(1.0, 0.08, 0.0));',
    '  float dTH = dot(T, H);',
    '  float sTH = sqrt(max(1.0 - dTH * dTH, 0.0));',
    '  float aniso = pow(sTH, 1.0 / max(uRough, 0.015));',

    /* a little rim so the silhouette reads against a dark room */
    '  float fres = pow(1.0 - max(dot(n, V), 0.0), 3.0);',

    /* falloff keeps the lit patch local, the way one hard source behaves */
    '  float d = length(uLight.xy - vPos.xy);',
    '  float fall = 1.0 / (1.0 + d * d * 0.82);',

    '  vec3 col = uColor * (uAmbient + diff * 1.05 * fall)',
    '           + vec3(aniso * uSheen * fall * 1.55)',
    '           + uColor * fres * 0.09;',

    /* The room is not infinite. Falling off toward the edges puts the cloth in a
       space rather than filling a rectangle, and it is what lets the copy sit on
       the left without a panel behind it. */
    '  float vig = smoothstep(1.55, 0.30, length(vPos.xy * vec2(0.72, 1.0)));',
    '  col *= mix(0.46, 1.0, vig);',
    '  gl_FragColor = vec4(col, 1.0);',
    '}'
  ].join('\n');

  /* per-weave shader constants: [warp, weft, bump, sheen, rough, pattern] */
  var WEAVE = {
    solid:   [340.0, 340.0, 0.055, 0.16, 0.075, 0.55],
    stripe:  [120.0, 380.0, 0.075, 0.20, 0.065, 0.35],
    grid:    [170.0, 170.0, 0.070, 0.14, 0.090, 0.30],
    hound:   [210.0, 210.0, 0.105, 0.11, 0.130, 1.25],
    speckle: [460.0, 460.0, 0.060, 0.13, 0.100, 0.85],
    weave:   [260.0, 130.0, 0.110, 0.10, 0.150, 1.55]
  };

  function compile(gl, type, src) {
    var s = gl.createShader(type);
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
      /* surfaced, never swallowed — a silent shader failure is a black canvas
         and no way to tell why */
      throw new Error('shader: ' + gl.getShaderInfoLog(s));
    }
    return s;
  }

  function hexToRgb(h) {
    h = h.replace('#', '');
    return [0, 2, 4].map(function (i) { return parseInt(h.substr(i, 2), 16) / 255; });
  }
  function srgbToLinear(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  }

  function Loom(canvas, opts) {
    opts = opts || {};
    this.c = canvas;
    this.seg = opts.seg || 128;
    this.reduce = matchMedia('(prefers-reduced-motion:reduce)').matches;

    var gl = canvas.getContext('webgl', { antialias: true, alpha: false,
      powerPreference: 'high-performance' })
      || canvas.getContext('experimental-webgl');
    if (!gl) { this.ok = false; return; }
    this.gl = gl;

    try {
      var p = gl.createProgram();
      gl.attachShader(p, compile(gl, gl.VERTEX_SHADER, VERT));
      gl.attachShader(p, compile(gl, gl.FRAGMENT_SHADER, FRAG));
      gl.linkProgram(p);
      if (!gl.getProgramParameter(p, gl.LINK_STATUS)) {
        throw new Error('link: ' + gl.getProgramInfoLog(p));
      }
      this.prog = p;
    } catch (e) {
      this.ok = false; this.error = e.message;
      if (root.console) console.warn('[loom]', e.message);
      return;
    }

    gl.useProgram(this.prog);
    this.buildMesh();
    this.u = {};
    ['uTime','uAmp','uAspect','uColor','uLight','uWarp','uWeft','uBump','uSheen',
     'uRough','uAmbient','uPattern'].forEach(function (k) {
      this.u[k] = gl.getUniformLocation(this.prog, k);
    }, this);

    this.light = { x: -0.45, y: 0.5 };
    this.aim   = { x: -0.45, y: 0.5 };
    this.col   = [0.72, 0.79, 0.93];
    this.colTo = this.col.slice();
    this.weave = WEAVE.solid.slice();
    this.weaveTo = this.weave.slice();
    this.t0 = performance.now();
    this.ok = true;
    this.resize();
  }

  Loom.prototype.buildMesh = function () {
    var gl = this.gl, n = this.seg, uv = [], idx = [];
    for (var y = 0; y <= n; y++) {
      for (var x = 0; x <= n; x++) { uv.push(x / n, y / n); }
    }
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        var a = j * (n + 1) + i, b = a + 1, c = a + n + 1, d = c + 1;
        idx.push(a, b, c, b, d, c);
      }
    }
    var vb = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, vb);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(uv), gl.STATIC_DRAW);
    var loc = gl.getAttribLocation(this.prog, 'aUv');
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);

    var ib = gl.createBuffer();
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ib);
    /* >65k vertices needs 32-bit indices; 128 segments stays under, but check
       rather than assume, because the count is a constructor option */
    var big = idx.length > 65535 || (n + 1) * (n + 1) > 65535;
    if (big && !gl.getExtension('OES_element_index_uint')) {
      this.seg = 100; return this.buildMesh();
    }
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER,
      big ? new Uint32Array(idx) : new Uint16Array(idx), gl.STATIC_DRAW);
    this.count = idx.length;
    this.idxType = big ? gl.UNSIGNED_INT : gl.UNSIGNED_SHORT;
  };

  Loom.prototype.resize = function () {
    if (!this.ok) return;
    var dpr = Math.min(2, root.devicePixelRatio || 1);
    var w = this.c.clientWidth || 1, h = this.c.clientHeight || 1;
    this.c.width = Math.floor(w * dpr);
    this.c.height = Math.floor(h * dpr);
    this.gl.viewport(0, 0, this.c.width, this.c.height);
    this.aspect = w / h;
  };

  Loom.prototype.set = function (shirt) {
    var rgb = hexToRgb(shirt.hex).map(srgbToLinear);
    this.colTo = rgb;
    this.weaveTo = (WEAVE[shirt.weave] || WEAVE.solid).slice();
    /* a near-black cloth needs a lift or the whole panel reads as a hole */
    var l = 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2];
    this.ambient = 0.175 + (1 - Math.min(1, l * 4)) * 0.115;
  };

  Loom.prototype.point = function (nx, ny) {
    this.aim.x = (nx - 0.5) * 2.2 * (this.aspect || 1);
    this.aim.y = (0.5 - ny) * 2.2;
  };

  Loom.prototype.frame = function () {
    if (!this.ok) return;
    var gl = this.gl, u = this.u;
    var t = this.reduce ? 2.4 : (performance.now() - this.t0) / 1000;

    this.light.x += (this.aim.x - this.light.x) * 0.075;
    this.light.y += (this.aim.y - this.light.y) * 0.075;
    for (var i = 0; i < 3; i++) this.col[i] += (this.colTo[i] - this.col[i]) * 0.06;
    for (var k = 0; k < 6; k++) this.weave[k] += (this.weaveTo[k] - this.weave[k]) * 0.06;

    gl.useProgram(this.prog);
    gl.uniform1f(u.uTime, t);
    gl.uniform1f(u.uAmp, this.reduce ? 0.6 : 1.0);
    gl.uniform1f(u.uAspect, this.aspect || 1);
    gl.uniform3f(u.uColor, this.col[0], this.col[1], this.col[2]);
    gl.uniform3f(u.uLight, this.light.x, this.light.y, 1.15);
    gl.uniform1f(u.uWarp, this.weave[0]);
    gl.uniform1f(u.uWeft, this.weave[1]);
    gl.uniform1f(u.uBump, this.weave[2]);
    gl.uniform1f(u.uSheen, this.weave[3]);
    gl.uniform1f(u.uRough, this.weave[4]);
    gl.uniform1f(u.uPattern, this.weave[5]);
    gl.uniform1f(u.uAmbient, this.ambient || 0.20);

    gl.clearColor(0.047, 0.05, 0.055, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.drawElements(gl.TRIANGLES, this.count, this.idxType, 0);
  };

  Loom.prototype.start = function () {
    if (!this.ok) return;
    var self = this, running = true;
    function loop() { if (!running) return; self.frame(); requestAnimationFrame(loop); }
    /* pause when the canvas is off screen — a shader at 60fps behind the fold is
       just heat */
    if ('IntersectionObserver' in root) {
      new IntersectionObserver(function (es) {
        running = es[0].isIntersecting;
        if (running) loop();
      }, { threshold: 0.01 }).observe(this.c);
    }
    loop();
    var t; addEventListener('resize', function () {
      clearTimeout(t); t = setTimeout(function () { self.resize(); }, 120);
    });
  };

  root.IAR = root.IAR || {};
  root.IAR.Loom = Loom;
})(window, document);
