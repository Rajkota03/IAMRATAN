/* I AM RATAN — shared behaviour.

   Every colour decision on this site is measured here, not chosen by eye. The
   contrast maths is not an audit afterthought: --edge and --ink are computed for
   all twenty-five cloths at load and written onto the elements themselves. */

(function (root, doc) {
  'use strict';

  var TABLE = '#22262A';   /* reassigned by setGround */
  var C = root.IAR_CATALOGUE || [];
  var reduce = matchMedia('(prefers-reduced-motion:reduce)').matches;

  /* ---- colour ---------------------------------------------------------- */

  function rgb(h) {
    h = h.replace('#', '');
    return [0, 2, 4].map(function (i) { return parseInt(h.substr(i, 2), 16); });
  }
  function lin(c) {
    c /= 255;
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  }
  function unlin(u) {
    u = Math.max(0, Math.min(1, u));
    var s = u <= 0.0031308 ? u * 12.92 : 1.055 * Math.pow(u, 1 / 2.4) - 0.055;
    return Math.round(s * 255);
  }
  function lum(h) {
    var v = rgb(h).map(lin);
    return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2];
  }
  function ratio(a, b) {
    var x = lum(a), y = lum(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
  }
  function hex(a) {
    return '#' + a.map(function (v) {
      return ('0' + v.toString(16)).slice(-2);
    }).join('').toUpperCase();
  }
  function toWhite(h, t) {
    return hex(rgb(h).map(lin).map(function (c) { return unlin(c + (1 - c) * t); }));
  }

  /* Ink that actually clears 4.5:1 on a given field. Two house values first,
     pure white or black only if neither reaches the threshold. */
  function inkOn(bg) {
    var best = ratio('#0C0B0A', bg) >= ratio('#D7DCD6', bg) ? '#0C0B0A' : '#D7DCD6';
    if (ratio(best, bg) >= 4.5) return best;
    return ratio('#FFFFFF', bg) >= ratio('#000000', bg) ? '#FFFFFF' : '#000000';
  }

  function toBlack(h, t) {
    return hex(rgb(h).map(lin).map(function (c) { return unlin(c * (1 - t)); }));
  }

  /* The cut face of the cloth. No flat ground separates twenty-five colours —
     measured, the best possible ground reaches 1.29:1 against the worst — so
     every swatch carries its own edge.

     The direction matters and it is not fixed: in a dark room the edge lifts
     toward white, in a light room it must deepen toward black. Lifting a white
     cloth on a cream ground reaches 1.21:1, which is no edge at all. So pick
     whichever direction the ground leaves headroom in, and if both are possible
     take the one that moves least. */
  function edgeOn(cloth, ground) {
    ground = ground || TABLE;
    if (ratio(cloth, ground) >= 3) return cloth;
    var gl = lum(ground);
    var upTarget = 3 * (gl + 0.05) - 0.05;      /* lum needed to sit lighter */
    var dnTarget = (gl + 0.05) / 3 - 0.05;      /* lum needed to sit darker  */
    var up = null, dn = null, t;
    if (upTarget <= 1) {
      for (t = 0.02; t <= 1.0001; t += 0.02) {
        var e = toWhite(cloth, t);
        if (lum(e) >= upTarget) { up = { hex: e, t: t }; break; }
      }
    }
    if (dnTarget >= 0) {
      for (t = 0.02; t <= 1.0001; t += 0.02) {
        var d = toBlack(cloth, t);
        if (lum(d) <= dnTarget) { dn = { hex: d, t: t }; break; }
      }
    }
    if (up && dn) return up.t <= dn.t ? up.hex : dn.hex;
    if (up) return up.hex;
    if (dn) return dn.hex;
    return gl > 0.4 ? '#000000' : '#FFFFFF';
  }

  function rupees(n) {
    return '₹' + String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  }
  function pad(n) { return n < 10 ? '0' + n : String(n); }

  /* ---- the catalogue, with its measured values attached ----------------- */

  var RANGE = C.map(function (p) {
    return {
      name: p.name, slug: p.slug, url: p.url,
      hex: p.hex, price: p.price, priceText: rupees(p.price),
      cat: p.cat, sizes: p.sizes, img: p.img, body: p.body,
      shot: !!(root.IAR_SHOTS && root.IAR_SHOTS[p.slug]),
      edge: edgeOn(p.hex, TABLE),
      ink: inkOn(p.hex),
      lum: lum(p.hex)
    };
  });

  /* The cloths photographed on the model lead the range. A folded-shirt
     catalogue photograph sitting next to a full shot set reads as a
     placeholder, so the ones that are finished go first and the rest follow in
     catalogue order. Two filters rather than a sort: both preserve order, so
     nothing shuffles inside either group.

     The numbering is assigned AFTER the reorder — it numbers the range as it is
     shown, which is the only reading of it that means anything on the page. */
  RANGE = RANGE.filter(function (p) { return p.shot; })
        .concat(RANGE.filter(function (p) { return !p.shot; }));
  RANGE.forEach(function (p, i) { p.n = i + 1; p.no = pad(i + 1); });

  /* every size the house could cut, so the three it does not are visible */
  var SIZE_RUN = [39, 40, 41, 42, 43, 44, 45, 46];

  function leaf(p) {
    var holes = SIZE_RUN.map(function (z) {
      var has = p.sizes.indexOf(String(z)) > -1;
      return '<i class="' + (has ? '' : 'off') + '" title="' +
        (has ? 'Size ' + z : 'Size ' + z + ' — not cut') + '"></i>';
    }).join('');
    return '<a class="leaf" href="product.html?p=' + p.slug + '">' +
      '<span class="leaf-face">' +
        '<span class="sw" style="--c:' + p.hex + ';--edge:' + p.edge + '"></span>' +
        '<span class="leaf-shot"><img src="images/shirts/' + p.img + '" alt="' +
          p.name + '" loading="lazy" decoding="async"></span>' +
        '<span class="leaf-hole"></span>' +
      '</span>' +
      '<span class="leaf-name">' + p.name + '</span>' +
      '<span class="leaf-row"><span class="leaf-meta">' + (p.cat || 'The range') +
        '</span><span class="leaf-price">' + p.priceText + '</span></span>' +
      '<span class="holes" aria-label="Sizes ' + p.sizes.join(', ') + '">' + holes +
      '</span>' +
    '</a>';
  }

  /* The shots need no reveal: they are visible from the first paint and the
     swatch behind them is the fallback. Kept as a no-op so callers stay valid. */
  function shots() {}

  /* full-bleed photography; a missing file leaves the ground */
  function plates(scope) {
    var EXT = ['jpg', 'webp', 'png'];
    (scope || doc).querySelectorAll('.plate[data-img]').forEach(function (el) {
      var id = el.getAttribute('data-img'), pos = el.getAttribute('data-pos'), i = 0;
      (function next() {
        if (i >= EXT.length) return;
        var img = new Image();
        img.alt = el.getAttribute('data-alt') || '';
        img.decoding = 'async';
        img.onload = function () {
          if (pos) img.style.objectPosition = pos;
          el.insertBefore(img, el.firstChild);
          requestAnimationFrame(function () { img.classList.add('in'); });
        };
        img.onerror = function () { i++; next(); };
        img.src = 'images/' + id + '.' + EXT[i];
      })();
    });
  }

  /* The hero: four frames cross-fading, and the copy setting itself on load.

     The drift animation is re-armed on every change by removing and re-adding
     the class — otherwise only the first frame ever moves, because the others
     never leave the state the keyframes ended in.

     It pauses when the tab is hidden and when the pointer is over the hero, so
     a frame never changes under someone who is reading it. */
  function hero(scope) {
    var h = (scope || doc).querySelector('.hero');
    if (!h) return;
    var frames = [].slice.call(h.querySelectorAll('.hero-frame'));
    var ticks  = [].slice.call(h.querySelectorAll('.hero-ticks button'));
    if (frames.length < 2) { h.classList.add('lit'); return; }

    var i = 0, timer = null, held = false;
    var HOLD = 3000;

    function show(n) {
      i = (n + frames.length) % frames.length;
      frames.forEach(function (f, k) {
        var on = k === i;
        if (on) {                       /* re-arm the drift */
          var img = f.querySelector('img');
          f.classList.remove('is-on');
          if (img) { void img.offsetWidth; }
        }
        f.classList.toggle('is-on', on);
      });
      ticks.forEach(function (t, k) {
        t.setAttribute('aria-selected', String(k === i));
      });
    }

    function tick() { if (!held && !doc.hidden) show(i + 1); }
    function start() { stop(); if (!reduce) timer = root.setInterval(tick, HOLD); }
    function stop() { if (timer) { root.clearInterval(timer); timer = null; } }

    ticks.forEach(function (t, k) {
      t.addEventListener('click', function () { show(k); start(); });
    });
    h.addEventListener('pointerenter', function () { held = true; });
    h.addEventListener('pointerleave', function () { held = false; });
    doc.addEventListener('visibilitychange', function () {
      if (doc.hidden) stop(); else start();
    });

    /* let the first frame decode before the copy sets, so they arrive together */
    var first = frames[0].querySelector('img');
    function light() { h.classList.add('lit'); }
    if (first && !first.complete) {
      first.addEventListener('load', light);
      first.addEventListener('error', light);
      root.setTimeout(light, 1200);
    } else { light(); }

    start();
  }

  /* Copy rises into place once, then stops. The class does the work so the
     motion is described in CSS and can be turned off in one media query. */
  function rises(scope) {
    var els = (scope || doc).querySelectorAll('.rise');
    if (!els.length) return;
    function all() { els.forEach(function (e) { e.classList.add('in'); }); }
    if (reduce || !('IntersectionObserver' in root)) return all();
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
      });
    }, { rootMargin: '0px 0px -10% 0px' });
    els.forEach(function (e) { io.observe(e); });
    setTimeout(all, 3000);            // never leave copy invisible
  }

  /* Parallax on the campaign frames.
     The scroll handler writes ONE custom property and nothing else — no reads of
     offsetTop, no style recalculation, no layout. Positions are measured once up
     front and again on resize, and the write happens inside rAF, so scrolling
     stays on the compositor. Below 900px the frames are shown whole rather than
     cropped, so there is no room to travel and the whole thing switches off. */
  function parallax(scope) {
    var els = [].slice.call((scope || doc).querySelectorAll('.camp--para'));
    if (!els.length || reduce) return;

    var boxes = [], ticking = false, on = false;

    function measure() {
      on = root.matchMedia('(min-width: 900px)').matches;
      boxes = els.map(function (el) {
        var r = el.getBoundingClientRect();
        return { el: el, top: r.top + root.scrollY, h: r.height };
      });
      if (!on) els.forEach(function (el) { el.style.removeProperty('--par'); });
    }

    function frame() {
      ticking = false;
      if (!on) return;
      var vh = root.innerHeight, y = root.scrollY;
      for (var i = 0; i < boxes.length; i++) {
        var b = boxes[i];
        if (y + vh < b.top || y > b.top + b.h) continue;   // off screen, skip
        // -1 as it enters the bottom, +1 as it leaves the top
        var p = ((y + vh) - b.top) / (vh + b.h) * 2 - 1;
        b.el.style.setProperty('--par', (p * -5.5).toFixed(2) + '%');
      }
    }

    function onScroll() {
      if (!ticking) { ticking = true; root.requestAnimationFrame(frame); }
    }

    measure(); frame();
    root.addEventListener('scroll', onScroll, { passive: true });
    root.addEventListener('resize', function () { measure(); frame(); }, { passive: true });
  }

  /* the chalk line: rules snap along their length. Nothing else animates. */
  function snaps(scope) {
    var els = (scope || doc).querySelectorAll('.snap');
    function all() { els.forEach(function (e) { e.classList.add('in'); }); }
    if (reduce || !('IntersectionObserver' in root)) return all();
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
      });
    }, { rootMargin: '0px 0px -6% 0px' });
    els.forEach(function (e) { io.observe(e); });
    setTimeout(all, 2500);
  }

  /* Silent films. Muted + playsinline is normally enough, but some browsers still
     refuse until the element is on screen, and a refused promise is unhandled by
     default. Nudge on intersection, pause when off screen, and if it is refused
     outright the poster frame is already showing so nothing looks broken. */
  function films() {
    var vids = doc.querySelectorAll('.film video');
    if (!vids.length) return;
    function play(v) { var p = v.play(); if (p && p.catch) p.catch(function () {}); }
    if (reduce) { vids.forEach(function (v) { v.removeAttribute('autoplay'); v.pause(); }); return; }
    if (!('IntersectionObserver' in root)) { vids.forEach(play); return; }
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (e) {
        if (e.isIntersecting) play(e.target); else e.target.pause();
      });
    }, { threshold: 0.15 });
    vids.forEach(function (v) { io.observe(v); });
  }

  /* ---- grounds ----------------------------------------------------------
     Four rooms the same house can stand in. Switching one rewrites every
     swatch edge, because an edge lifted to clear 3:1 against slate is invisible
     against cream — the contrast rule has to be re-run, not just re-skinned. */
  var GROUNDS = [
    { k: 'slate', name: 'Slate',        bg: '#22262A' },
    { k: 'blue',  name: "Ratan's Blue", bg: '#B7CAEE' },
    { k: 'cream', name: 'Bone',         bg: '#EDE9E0' },
    { k: 'white', name: 'White',        bg: '#F7F6F4' }
  ];

  function groundOf(k) {
    for (var i = 0; i < GROUNDS.length; i++) if (GROUNDS[i].k === k) return GROUNDS[i];
    return GROUNDS[0];
  }

  /* Re-run the edge computation for every swatch on the page against the new
     ground, and re-pick the ink sitting on each cloth. */
  function reEdge(bg) {
    doc.querySelectorAll('.sw').forEach(function (el) {
      var c = el.style.getPropertyValue('--c').trim();
      if (c) el.style.setProperty('--edge', edgeOn(c, bg));
    });
    doc.querySelectorAll('.ply-no').forEach(function (el) {
      var sw = el.parentElement && el.parentElement.querySelector('.sw');
      var c = sw && sw.style.getPropertyValue('--c').trim();
      if (c) el.style.setProperty('--pn', inkOn(c));
    });
    RANGE.forEach(function (p) { p.edge = edgeOn(p.hex, bg); });
  }

  function setGround(k, remember) {
    var g = groundOf(k);
    doc.documentElement.setAttribute('data-ground', g.k);
    var m = doc.querySelector('meta[name="theme-color"]');
    if (m) m.setAttribute('content', g.bg);
    TABLE = g.bg;
    reEdge(g.bg);
    doc.querySelectorAll('.grounds button').forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.getAttribute('data-g') === g.k));
    });
    if (remember !== false) { try { localStorage.setItem('iar-ground', g.k); } catch (e) {} }
  }

  /* The ground switcher is a client-review instrument, not part of the site. It
     used to be built on every page that loaded this file and hidden again with
     CSS — which meant a new page silently inherited both the bar and its
     theme-colour override. Pages now opt out declaratively with
     <body data-no-grounds>, and nothing is created or overwritten. */
  function groundBar() {
    if (doc.body.hasAttribute('data-no-grounds')) return;
    if (doc.querySelector('.grounds')) return;
    var el = doc.createElement('div');
    el.className = 'grounds';
    el.setAttribute('role', 'group');
    el.setAttribute('aria-label', 'Preview the site on a different ground');
    el.innerHTML = '<span>Ground</span>' + GROUNDS.map(function (g) {
      return '<button type="button" data-g="' + g.k + '" aria-pressed="false" ' +
        'title="' + g.name + '" aria-label="' + g.name + '" ' +
        'style="--g:' + g.bg + '"></button>';
    }).join('');
    el.addEventListener('click', function (e) {
      var b = e.target.closest('button[data-g]');
      if (b) setGround(b.getAttribute('data-g'));
    });
    doc.body.appendChild(el);
    var saved = null;
    try { saved = localStorage.getItem('iar-ground'); } catch (e) {}
    setGround(saved || 'slate', false);
  }

  function mount() {
    doc.documentElement.classList.add('js');
    var y = doc.getElementById('year');
    if (y) y.textContent = new Date().getFullYear();
    plates(); snaps(); rises(); hero(); shots(); films(); parallax(); groundBar();
  }

  root.IAR = root.IAR || {};
  root.IAR.RANGE = RANGE;
  root.IAR.SIZE_RUN = SIZE_RUN;
  root.IAR.TABLE = TABLE;
  root.IAR.rupees = rupees;
  root.IAR.pad = pad;
  root.IAR.inkOn = inkOn;
  root.IAR.edgeOn = edgeOn;
  root.IAR.ratio = ratio;
  root.IAR.lum = lum;
  root.IAR.leaf = leaf;
  root.IAR.plates = plates;
  root.IAR.snaps = snaps;
  root.IAR.rises = rises;
  root.IAR.hero = hero;
  root.IAR.parallax = parallax;
  root.IAR.shots = shots;
  root.IAR.films = films;
  root.IAR.setGround = setGround;
  root.IAR.GROUNDS = GROUNDS;

  if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', mount);
  else mount();
})(window, document);
