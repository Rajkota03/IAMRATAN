/* I AM RATAN — the bunch.

   Twenty-five cloth swatches punched through one corner and riveted to a single
   post. It is the hero, the navigation, and the only motion primitive on the
   site: every animation here is a rotation about the rivet, because nothing
   riveted through one corner can translate.

   The easing is a damped spring rather than a cubic-bezier — cloth has mass, and
   a released bunch overshoots slightly and settles. Detents are angular, so a
   flick lands on a swatch instead of drifting between two. */

(function (root, doc) {
  'use strict';

  var reduce = matchMedia('(prefers-reduced-motion:reduce)').matches;

  /* The pinked edge: a sawtooth cut down the outer edge of every swatch.
     Generated once as an SVG mask so it scales with the ply. */
  function pinkMask(teeth) {
    var h = 100, w = 100, step = h / teeth, d = 'M0,0 L' + (w - 3) + ',0 ';
    for (var i = 0; i < teeth; i++) {
      var y0 = i * step, ym = y0 + step / 2, y1 = y0 + step;
      d += 'L' + w + ',' + ym.toFixed(2) + ' L' + (w - 3) + ',' + y1.toFixed(2) + ' ';
    }
    d += 'L0,' + h + ' Z';
    var svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" ' +
      'preserveAspectRatio="none"><path d="' + d + '" fill="#fff"/></svg>';
    /* single quotes only: this value is set via setProperty, but a double quote
       here would terminate any style attribute it ever landed in */
    return "url('data:image/svg+xml;charset=utf-8," + encodeURIComponent(svg) + "')";
  }

  function Bunch(el, items, opts) {
    opts = opts || {};
    this.el = el;
    this.items = items;
    this.n = items.length;
    this.onChange = opts.onChange || function () {};

    /* The fan. Wide enough that every ply shows a sliver of its own cloth —
       at 74deg the twenty-five stacked almost exactly and the bunch read as one
       dark mass rather than as twenty-five colours. */
    this.spread = opts.spread || 96;       /* total degrees across the bunch  */
    this.base = opts.base || -48;           /* angle of the first ply          */
    this.step = this.spread / (this.n - 1);

    this.rot = 0;        /* current fan offset, degrees                        */
    this.target = 0;     /* where the spring is pulling                        */
    this.vel = 0;
    this.index = 0;
    this.dragging = false;
    this.raf = null;

    this.build();
    this.bind();
    this.select(opts.start || 0, true);
    this.tick();
  }

  Bunch.prototype.build = function () {
    var el = this.el, mask = pinkMask(26);
    el.innerHTML = '';
    el.setAttribute('role', 'listbox');
    el.setAttribute('aria-label', 'The range — twenty-five cloths, riveted');

    this.plies = this.items.map(function (it, i) {
      var b = doc.createElement('button');
      b.className = 'ply';
      b.type = 'button';
      b.setAttribute('role', 'option');
      b.setAttribute('aria-selected', 'false');
      b.setAttribute('aria-label', it.name + ', ' + it.priceText);
      b.dataset.i = i;
      b.style.setProperty('--pw', 'var(--ply-w)');
      b.style.setProperty('--ph', 'var(--ply-h)');
      b.innerHTML =
        '<span class="ply-face">' +
          '<span class="sw sw--pinked"></span>' +
          '<span class="ply-veil"></span>' +
          '<span class="ply-no">' + it.no + '</span>' +
        '</span>';
      /* set through the CSSOM, never through a style attribute — the mask is a
         data URI and would break the attribute at its first quote */
      var sw = b.querySelector('.sw');
      sw.style.setProperty('--c', it.hex);
      sw.style.setProperty('--edge', it.edge);
      sw.style.setProperty('--pink', mask);
      b.querySelector('.ply-no').style.setProperty('--pn', it.ink);
      el.appendChild(b);
      return b;
    });

    var rivet = doc.createElement('span');
    rivet.className = 'rivet';
    rivet.setAttribute('aria-hidden', 'true');
    el.appendChild(rivet);
    this.layout();
  };

  /* The post sits at the upper left; plies are as long as the stage allows. */
  Bunch.prototype.layout = function () {
    var r = this.el.getBoundingClientRect();
    var h = r.height || 420;
    var pw = Math.min(Math.max(h * 0.30, 96), 200);
    var ph = Math.min(h * 0.86, 460);
    var px = pw * 0.16, py = ph * 0.075;      /* the punched hole, in the ply  */
    /* The post hangs at the upper right. The active ply points straight down and
       the rest of the bunch fans anticlockwise from it, so the sweep opens into
       the stage instead of off the left edge of the page. */
    var ox = r.width - pw * 0.62, oy = h * 0.05;

    this.el.style.setProperty('--ply-w', pw + 'px');
    this.el.style.setProperty('--ply-h', ph + 'px');
    this.el.style.setProperty('--px', px + 'px');
    this.el.style.setProperty('--py', py + 'px');
    this.el.style.setProperty('--ox', ox + 'px');
    this.el.style.setProperty('--oy', oy + 'px');
    /* the rivet is drawn at the same point the plies pivot around */
    var rv = this.el.querySelector('.rivet');
    if (rv) { rv.style.left = (ox + px) + 'px'; rv.style.top = (oy + py) + 'px'; }
    this.paint();
  };

  Bunch.prototype.angleOf = function (i) {
    return this.base + i * this.step + this.rot;
  };

  Bunch.prototype.paint = function () {
    var self = this;
    this.plies.forEach(function (b, i) {
      var a = self.angleOf(i);
      b.style.transform = 'rotate(' + a.toFixed(2) + 'deg)';
      /* the reading angle is 0deg: whatever points straight down-right is live.
         The veil is kept low because plies overlap — twenty-four of them at 0.4
         each composite to solid black, which is how the fan lost its colour. */
      var off = Math.min(1, Math.abs(a) / (self.spread * 0.75));
      var veil = off * 0.26;
      b.querySelector('.ply-veil').style.opacity = veil.toFixed(3);
      b.style.zIndex = String(100 - Math.round(Math.abs(a)));
    });
  };

  Bunch.prototype.nearest = function () {
    /* which ply currently sits closest to the reading angle */
    var best = 0, bd = Infinity;
    for (var i = 0; i < this.n; i++) {
      var d = Math.abs(this.angleOf(i));
      if (d < bd) { bd = d; best = i; }
    }
    return best;
  };

  Bunch.prototype.select = function (i, snap) {
    i = Math.max(0, Math.min(this.n - 1, i));
    this.index = i;
    /* rotate the fan so ply i sits at the reading angle */
    this.target = -(this.base + i * this.step);
    if (snap || reduce) { this.rot = this.target; this.vel = 0; this.paint(); }
    this.plies.forEach(function (b, k) {
      b.setAttribute('aria-selected', String(k === i));
    });
    this.onChange(this.items[i], i);
  };

  Bunch.prototype.tick = function () {
    var self = this;
    function frame() {
      if (!self.dragging) {
        /* damped spring — stiffness and damping tuned so cloth settles in
           about half a second without ringing */
        var k = 0.16, damp = 0.74;
        self.vel = (self.vel + (self.target - self.rot) * k) * damp;
        self.rot += self.vel;
        if (Math.abs(self.vel) < 0.01 && Math.abs(self.target - self.rot) < 0.01) {
          self.rot = self.target; self.vel = 0;
        }
      }
      self.paint();
      self.raf = requestAnimationFrame(frame);
    }
    if (reduce) { this.paint(); return; }
    this.raf = requestAnimationFrame(frame);
  };

  Bunch.prototype.bind = function () {
    var self = this, last = 0, moved = 0, id = null;

    function angleAt(e) {
      var r = self.el.getBoundingClientRect();
      var ox = parseFloat(getComputedStyle(self.el).getPropertyValue('--ox'));
      var oy = parseFloat(getComputedStyle(self.el).getPropertyValue('--oy'));
      var px = parseFloat(getComputedStyle(self.el).getPropertyValue('--px'));
      var py = parseFloat(getComputedStyle(self.el).getPropertyValue('--py'));
      return Math.atan2(e.clientY - r.top - (oy + py),
                        e.clientX - r.left - (ox + px)) * 180 / Math.PI;
    }

    this.el.addEventListener('pointerdown', function (e) {
      if (reduce) return;
      self.dragging = true; moved = 0; id = e.pointerId;
      last = angleAt(e);
      self.el.classList.add('dragging');
      self.el.setPointerCapture(e.pointerId);
    });

    this.el.addEventListener('pointermove', function (e) {
      if (!self.dragging || e.pointerId !== id) return;
      var a = angleAt(e), d = a - last;
      if (d > 180) d -= 360; else if (d < -180) d += 360;
      last = a; moved += Math.abs(d);
      self.rot += d; self.vel = d;
      /* the fan cannot open past its own ends */
      var lo = -(self.base + (self.n - 1) * self.step), hi = -self.base;
      if (self.rot < lo) self.rot = lo + (self.rot - lo) * 0.35;
      if (self.rot > hi) self.rot = hi + (self.rot - hi) * 0.35;
    });

    function release() {
      if (!self.dragging) return;
      self.dragging = false;
      self.el.classList.remove('dragging');
      /* carry the flick into the detent, then let the spring settle it */
      var glide = Math.max(-6, Math.min(6, self.vel * 2.4));
      var probe = self.rot + glide, best = 0, bd = Infinity;
      for (var i = 0; i < self.n; i++) {
        var d = Math.abs(self.base + i * self.step + probe);
        if (d < bd) { bd = d; best = i; }
      }
      self.select(best);
    }
    ['pointerup', 'pointercancel', 'lostpointercapture'].forEach(function (ev) {
      self.el.addEventListener(ev, release);
    });

    this.el.addEventListener('click', function (e) {
      var b = e.target.closest('.ply');
      if (!b) return;
      if (moved > 5) { e.preventDefault(); return; }   /* a drag is not a click */
      self.select(+b.dataset.i);
    });

    this.el.addEventListener('keydown', function (e) {
      var k = e.key, d = 0;
      if (k === 'ArrowRight' || k === 'ArrowDown') d = 1;
      else if (k === 'ArrowLeft' || k === 'ArrowUp') d = -1;
      else if (k === 'Home') { e.preventDefault(); return self.select(0); }
      else if (k === 'End') { e.preventDefault(); return self.select(self.n - 1); }
      else return;
      e.preventDefault();
      var next = self.index + d;
      self.select(next);
      if (self.plies[self.index]) self.plies[self.index].focus();
    });

    this.el.addEventListener('focusin', function (e) {
      var b = e.target.closest('.ply');
      if (b && +b.dataset.i !== self.index) self.select(+b.dataset.i);
    });

    var t;
    addEventListener('resize', function () {
      clearTimeout(t);
      t = setTimeout(function () { self.layout(); }, 120);
    });
  };

  root.IAR = root.IAR || {};
  root.IAR.Bunch = Bunch;
})(window, document);
