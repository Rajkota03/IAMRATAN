/* I AM RATAN — image plates.

   Every photographic slot on every variant is a <figure data-plate="..."> .
   The rendered garment goes in immediately, so the page is complete with no
   photography at all. Then the real file is tried in the background; if it
   loads it replaces the drawing, if it 404s nothing happens and nothing breaks.

   Drop a file at images/<plate-id>.jpg and it appears. No code change.
   See IMAGE-BRIEF.md for the plate list and the prompt for each one. */

(function (root) {
  'use strict';

  var EXT = ['jpg', 'webp', 'png'];

  function plateCSS() {
    if (document.getElementById('iar-plate-css')) return;
    var s = document.createElement('style');
    s.id = 'iar-plate-css';
    s.textContent = [
      '.plate{position:relative;margin:0;overflow:hidden;display:block}',
      '.plate>img,.plate>.plate-draw{position:absolute;inset:0;width:100%;height:100%}',
      '.plate>img{object-fit:cover;opacity:0;transition:opacity .8s cubic-bezier(.16,1,.3,1)}',
      '.plate>img.is-in{opacity:1}',
      '.plate-draw{display:grid;place-items:center;padding:3%}',
      '.plate-draw svg{width:100%;height:100%;max-height:100%}',
      '@media (prefers-reduced-motion:reduce){.plate>img{transition:none}}'
    ].join('');
    document.head.appendChild(s);
  }

  /* Tries each extension in turn. Resolves with the loaded <img>, or never. */
  function tryLoad(base, alt, done) {
    var i = 0;
    (function next() {
      if (i >= EXT.length) return;
      var img = new Image();
      img.alt = alt || '';
      img.decoding = 'async';
      img.onload = function () { done(img); };
      img.onerror = function () { i++; next(); };
      img.src = base + '.' + EXT[i];
    })();
  }

  function fill(el) {
    var id = el.getAttribute('data-plate');
    if (!id) return;
    var n = parseInt(el.getAttribute('data-shirt'), 10);
    var shirt = root.IAR.SHIRTS[(n || 1) - 1];
    var alt = el.getAttribute('data-alt') || shirt.name;
    /* Landscape masters dropped into portrait slots get cropped to their centre
       by default, which can cut the subject straight out of frame. data-pos
       steers the crop the way an art director would. */
    var pos = el.getAttribute('data-pos');

    var draw = document.createElement('div');
    draw.className = 'plate-draw';
    draw.innerHTML = root.IAR.garment(shirt, { shadow: el.getAttribute('data-shadow') !== 'false' });
    el.appendChild(draw);

    tryLoad('images/' + id, alt, function (img) {
      if (pos) img.style.objectPosition = pos;
      el.appendChild(img);
      requestAnimationFrame(function () {
        img.classList.add('is-in');
        draw.style.opacity = '0';
        setTimeout(function () { if (draw.parentNode) draw.remove(); }, 900);
      });
    });
  }

  function plates(scope) {
    plateCSS();
    var nodes = (scope || document).querySelectorAll('.plate[data-plate]');
    Array.prototype.forEach.call(nodes, fill);
  }

  root.IAR = root.IAR || {};
  root.IAR.plates = plates;
})(window);
