/* I AM RATAN — cloth renderer.

   The 2040 premise: a garment is not photographed, it is rendered, and the
   viewer moves the light rather than the product. So this is an actual shading
   model, not a gradient pretending to be one.

   Per pixel inside the garment mask:
     · perturb the surface normal by a weave function (warp, weft, twill offset)
     · Lambert diffuse against the light vector
     · Blinn-Phong specular, tightened for poplin, widened for brushed twill
     · a little rim light so a near-black shirt still reads against a dark room

   Rendered at low resolution and scaled up by CSS: cloth has no hard edges to
   lose, and it keeps the whole thing comfortably inside one animation frame. */

(function (root) {
  'use strict';

  var BODY = 'M140 118 L330 118 L444 350 L378 371 L320 252 L318 560 ' +
             'C318 568 152 568 152 560 L150 252 L92 371 L26 350 Z';
  var COLLAR = [
    'M188 126 C204 102 266 102 282 126 C266 118 204 118 188 126 Z',
    'M188 124 C190 152 198 180 212 200 L240 146 C224 140 202 134 192 120 Z',
    'M282 124 C280 152 272 180 258 200 L230 146 C246 140 268 134 278 120 Z'
  ];
  var VB_W = 470, VB_H = 620;

  /* weave presets: [warp freq, weft freq, bump, shininess, spec strength]
     Frequencies are radians per pixel — a period of two to three pixels, so the
     weave reads as cloth once the canvas is scaled up, not as a checkerboard.
     Bump and specular stay low: cotton is matte, and anything higher blows the
     whole surface out to white. */
  var WEAVE = {
    solid:   [2.60, 2.60, 0.13, 48, 0.26],
    stripe:  [1.05, 2.80, 0.18, 42, 0.30],
    grid:    [1.30, 1.30, 0.17, 36, 0.22],
    hound:   [1.55, 1.55, 0.24, 22, 0.17],
    speckle: [3.40, 3.40, 0.15, 30, 0.20],
    weave:   [2.00, 1.00, 0.26, 18, 0.15]
  };

  function hexToRgb(h) {
    h = h.replace('#', '');
    return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
  }

  function Cloth(canvas, opts) {
    this.c = canvas;
    this.ctx = canvas.getContext('2d', { alpha: true });
    this.w = (opts && opts.w) || 235;
    this.h = Math.round(this.w * VB_H / VB_W);
    canvas.width = this.w;
    canvas.height = this.h;
    this.light = { x: 0.32, y: 0.22 };      // normalised, 0..1 across the canvas
    this.target = { x: 0.32, y: 0.22 };
    this.shirt = root.IAR.SHIRTS[1];
    this.next = null;
    this.mix = 1;                            // 0..1 crossfade between garments
    this._mask = null;
    this._buildMask();
    this.img = this.ctx.createImageData(this.w, this.h);
  }

  /* One rasterisation of the silhouette, reused every frame. */
  Cloth.prototype._buildMask = function () {
    var w = this.w, h = this.h;
    var off = document.createElement('canvas');
    off.width = w; off.height = h;
    var g = off.getContext('2d');
    g.setTransform(w / VB_W, 0, 0, h / VB_H, 0, 0);
    g.fillStyle = '#fff';
    g.fill(new Path2D(BODY));
    COLLAR.forEach(function (d) { g.fill(new Path2D(d)); });
    var d = g.getImageData(0, 0, w, h).data;
    var m = new Float32Array(w * h);
    for (var i = 0, p = 0; i < d.length; i += 4, p++) m[p] = d[i + 3] / 255;
    this._mask = m;
  };

  Cloth.prototype.set = function (shirt) {
    if (shirt === this.shirt) return;
    this.next = shirt;
    this.mix = 0;
  };

  Cloth.prototype.aim = function (nx, ny) {
    this.target.x = nx;
    this.target.y = ny;
  };

  Cloth.prototype.render = function () {
    var w = this.w, h = this.h, m = this._mask, out = this.img.data;

    /* the light eases toward the pointer — cloth has inertia, cursors do not */
    this.light.x += (this.target.x - this.light.x) * 0.09;
    this.light.y += (this.target.y - this.light.y) * 0.09;
    if (this.next) {
      this.mix += (1 - this.mix) * 0.12;
      if (this.mix > 0.995) { this.shirt = this.next; this.next = null; this.mix = 1; }
    }

    var a = this.shirt, b = this.next || this.shirt, t = this.next ? this.mix : 0;
    var ca = hexToRgb(a.hex), cb = hexToRgb(b.hex);
    var r0 = ca[0] + (cb[0] - ca[0]) * t,
        g0 = ca[1] + (cb[1] - ca[1]) * t,
        b0 = ca[2] + (cb[2] - ca[2]) * t;

    var wa = WEAVE[a.weave] || WEAVE.solid, wb = WEAVE[b.weave] || WEAVE.solid;
    var fx = wa[0] + (wb[0] - wa[0]) * t,
        fy = wa[1] + (wb[1] - wa[1]) * t,
        bump = wa[2] + (wb[2] - wa[2]) * t,
        shin = wa[3] + (wb[3] - wa[3]) * t,
        spec = wa[4] + (wb[4] - wa[4]) * t;

    /* light position in pixels, pulled off the surface so it rakes across it */
    var lx = this.light.x * w, ly = this.light.y * h, lz = h * 0.55;
    var lum = (0.2126 * r0 + 0.7152 * g0 + 0.0722 * b0) / 255;
    var ambient = 0.34 + (1 - lum) * 0.10;   // dark cloth needs a lift to read

    var p = 0, q = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++, p++, q += 4) {
        var cov = m[p];
        if (cov <= 0.004) { out[q + 3] = 0; continue; }

        /* weave normal: two crossed sinusoids, twill shifts one by the other */
        var u = x * fx, v = y * fy;
        var nx = Math.sin(u + Math.sin(v * 0.5) * 0.6) * bump;
        var ny = Math.sin(v) * bump * 0.85;
        var nz = 1;
        var nl = Math.sqrt(nx * nx + ny * ny + 1);
        nx /= nl; ny /= nl; nz /= nl;

        var dx = lx - x, dy = ly - y;
        var dl = Math.sqrt(dx * dx + dy * dy + lz * lz);
        dx /= dl; dy /= dl;
        var dz = lz / dl;

        var diff = nx * dx + ny * dy + nz * dz;
        if (diff < 0) diff = 0;

        /* halfway vector against a viewer straight on */
        var hx = dx, hy = dy, hz = dz + 1;
        var hl = Math.sqrt(hx * hx + hy * hy + hz * hz);
        var sd = (nx * hx + ny * hy + nz * hz) / hl;
        var sp = sd > 0 ? Math.pow(sd, shin) * spec : 0;

        /* falloff so the lit patch stays local and the shadow side stays clean */
        var fall = 1 - Math.min(1, (Math.abs(lx - x) / w) * 0.85 + (Math.abs(ly - y) / h) * 0.55);
        fall = 0.46 + fall * 0.54;

        /* Kept deliberately under 1.0 combined: cotton reflects a fraction of
           what hits it, and letting shade run past unity reads as plastic. */
        var sh = ambient + diff * 0.58 * fall;
        var s = sp * 96 * fall;

        out[q]     = Math.min(255, r0 * sh + s);
        out[q + 1] = Math.min(255, g0 * sh + s);
        out[q + 2] = Math.min(255, b0 * sh + s);
        out[q + 3] = cov * 255;
      }
    }
    this.ctx.putImageData(this.img, 0, 0);
  };

  root.IAR = root.IAR || {};
  root.IAR.Cloth = Cloth;
})(window);
