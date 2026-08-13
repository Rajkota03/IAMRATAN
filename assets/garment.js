/* I AM RATAN — garment + mark renderer.

   The house photography brief forbids soft window light, grain, warm beige, and
   props. What it asks for is "the clarity of a render that is still a photograph":
   hard directional light, controlled speculars, knife-sharp folds, a dead-straight
   placket, suspension instead of hanging. That is what this draws.

   Light comes from the upper left in every garment. Form is described by BOTH a
   black shadow set and a white highlight set, so Obsidian and Blanc Canvas are
   equally legible — one is read by its highlights, the other by its shadows. */

(function (root) {
  'use strict';

  var uid = 0;

  /* One shared stylesheet rather than 25 copies of the same inline fills. */
  function css() {
    if (document.getElementById('iar-garment-css')) return;
    var s = document.createElement('style');
    s.id = 'iar-garment-css';
    s.textContent = [
      /* Must clip. Swatches use preserveAspectRatio=slice, which overflows the
         viewport by design; left visible it pushes a horizontal scrollbar onto
         the whole page. The garment's cast shadow already sits inside its viewBox. */
      '.iar-g{display:block;overflow:hidden}',
      '.iar-g .gs{fill:var(--g,#888)}',
      '.iar-g .sh{fill:#000}',
      '.iar-g .hi{fill:#fff}',
      '.iar-g .btn{fill:#E2DBE1}',
      /* Stroke colour must live here: the .sh / .hi classes carry fill, and a
         path with fill:none and no stroke colour draws nothing at all. */
      '.iar-g .ln{fill:none;stroke:#000;stroke-linecap:round}',
      '.iar-g .ln.hi{stroke:#fff}',
      '@media (prefers-reduced-motion:reduce){.iar-g *{transition:none!important;animation:none!important}}'
    ].join('');
    document.head.appendChild(s);
  }

  /* ---- fabric ---------------------------------------------------------- */
  /* Every pattern is built from black and white at low alpha only, never from a
     named colour, so one definition works across all twenty-five grounds. */
  function fabric(weave, id) {
    switch (weave) {
      case 'stripe':
        return '<pattern id="' + id + '" width="17" height="8" patternUnits="userSpaceOnUse">' +
          '<rect x="0" y="0" width="7" height="8" fill="#fff" opacity=".34"/>' +
          '<rect x="7" y="0" width="1.3" height="8" fill="#000" opacity=".13"/>' +
          '<rect x="12" y="0" width="1.6" height="8" fill="#fff" opacity=".16"/>' +
          '</pattern>';
      case 'grid':
        return '<pattern id="' + id + '" width="26" height="26" patternUnits="userSpaceOnUse">' +
          '<rect x="0" y="0" width="26" height="1.5" fill="#000" opacity=".24"/>' +
          '<rect x="0" y="0" width="1.5" height="26" fill="#000" opacity=".24"/>' +
          '<rect x="13" y="0" width="26" height="0.8" fill="#000" opacity=".10"/>' +
          '<rect x="0" y="13" width="0.8" height="26" fill="#000" opacity=".10"/>' +
          '</pattern>';
      case 'hound':
        /* Classic pied-de-poule. The white wash underneath keeps the check
           readable on Onyx as well as on Claret. */
        return '<pattern id="' + id + '" width="20" height="20" patternUnits="userSpaceOnUse">' +
          '<rect width="20" height="20" fill="#fff" opacity=".15"/>' +
          '<path d="M0 0h10v10H0z M10 10h10v10H10z M10 0l10 10V0z M0 10l10 10H0z" fill="#000" opacity=".42"/>' +
          '</pattern>';
      case 'speckle':
        return '<pattern id="' + id + '" width="4" height="4" patternUnits="userSpaceOnUse">' +
          '<rect x="0" y="0" width="2" height="2" fill="#fff" opacity=".20"/>' +
          '<rect x="2" y="2" width="2" height="2" fill="#000" opacity=".14"/>' +
          '</pattern>';
      case 'weave':
        return '<pattern id="' + id + '" width="16" height="16" patternUnits="userSpaceOnUse">' +
          '<path d="M0 16L8 8 16 16" fill="none" stroke="#fff" stroke-width="2.2" opacity=".18"/>' +
          '<path d="M0 8L8 0 16 8" fill="none" stroke="#000" stroke-width="2.2" opacity=".14"/>' +
          '</pattern>';
      default:
        return '';
    }
  }

  /* The silhouette. Flat front, sleeves fallen, nothing holding it up.
     Shoulders 190 wide against a 442 length, and the body tapers in from the
     shoulder rather than flaring past it — the difference between a shirt and
     a smock is entirely in that taper. */
  /* The shoulder line is unbroken — the collar is built on top of it rather than
     cut into it, so no neck hole can ever show through. */
  var BODY = 'M140 118 L330 118 ' +
             'L444 350 L378 371 L320 252 L318 560 C318 568 152 568 152 560 ' +
             'L150 252 L92 371 L26 350 Z';

  var BUTTON_Y = [226, 288, 350, 412, 474, 530];

  /* opts: { scale, shadow (bool), id }  */
  function garment(shirt, opts) {
    css();
    opts = opts || {};
    var k = 'g' + (++uid);
    var patId = 'fab-' + k;
    var clipId = 'clip-' + k;
    var blurId = 'blur-' + k;
    var hasPat = shirt.weave !== 'solid';
    var showShadow = opts.shadow !== false;
    /* detail mode draws only the structure — seams, placket, collar edges, cuffs,
       buttons — with no cloth of its own, so it can be laid over a live render. */
    var detail = opts.detail === true;
    if (detail) { hasPat = false; showShadow = false; }

    var o = [];
    o.push('<svg class="iar-g" viewBox="0 0 470 620" style="--g:' + shirt.hex + '" ' +
           'role="img" aria-label="' + shirt.name + ' — ' + shirt.cloth.toLowerCase() +
           ' shirt, suspended, lit from the left">');

    o.push('<defs>');
    if (hasPat) o.push(fabric(shirt.weave, patId));
    o.push('<clipPath id="' + clipId + '"><path d="' + BODY + '"/></clipPath>');
    o.push('<filter id="' + blurId + '" x="-20%" y="-20%" width="150%" height="150%">' +
           '<feGaussianBlur stdDeviation="4"/></filter>');
    o.push('</defs>');

    /* Cast shadow. Hard light casts a hard shadow; this is barely softened. */
    if (showShadow) {
      o.push('<g filter="url(#' + blurId + ')" opacity=".26">');
      o.push('<path class="sh" d="' + BODY + '" transform="translate(24 20)"/>');
      o.push('</g>');
    }

    /* Cloth. */
    if (!detail) o.push('<path class="gs" d="' + BODY + '"/>');
    if (hasPat) o.push('<path d="' + BODY + '" fill="url(#' + patId + ')"/>');

    /* Everything below is clipped to the silhouette so no edge spills. */
    o.push('<g clip-path="url(#' + clipId + ')">');

    /* Shadow set — right of every form, light being upper-left. */
    o.push('<path class="sh" opacity=".13" d="M318 570 L320 252 L282 262 L284 572 Z"/>');
    o.push('<path class="sh" opacity=".11" d="M320 252 L378 371 L400 358 L338 248 Z"/>');
    o.push('<path class="sh" opacity=".07" d="M150 252 L92 371 L74 360 L134 248 Z"/>');
    o.push('<path class="sh" opacity=".08" d="M186 156 C210 214 260 214 284 156 L290 182 C264 246 206 246 180 182 Z"/>');

    /* Highlight set — the lit face. On near-blacks this is what draws the shirt. */
    o.push('<path class="hi" opacity=".12" d="M152 570 L150 252 L188 262 L186 572 Z"/>');
    o.push('<path class="hi" opacity=".14" d="M140 118 L26 350 L54 364 L166 134 Z"/>');
    o.push('<path class="hi" opacity=".06" d="M330 118 L444 350 L420 362 L310 134 Z"/>');

    /* Pressed folds. A crease is a shadow and a specular two pixels apart. */
    [180, 290].forEach(function (x) {
      var lit = x === 180 ? x - 3.2 : x + 3.2;
      var dark = x === 180 ? x + 1 : x - 1;
      o.push('<rect class="hi" opacity=".13" x="' + lit + '" y="200" width="2.4" height="368"/>');
      o.push('<rect class="sh" opacity=".10" x="' + dark + '" y="200" width="2.4" height="368"/>');
    });

    /* Armhole seams, sleeve creases, hem stitch. */
    o.push('<path class="ln sh" opacity=".16" stroke-width="1.4" d="M140 120 C130 162 143 214 150 250"/>');
    o.push('<path class="ln sh" opacity=".16" stroke-width="1.4" d="M330 120 C340 162 327 214 320 250"/>');
    o.push('<path class="ln sh" opacity=".12" stroke-width="1.2" d="M154 548 L316 548"/>');
    o.push('<path class="ln sh" opacity=".13" stroke-width="1.2" d="M128 152 L54 348"/>');
    o.push('<path class="ln sh" opacity=".13" stroke-width="1.2" d="M342 152 L416 348"/>');

    o.push('</g>'); /* end clip */

    /* Placket — dead straight, raised, catching the light on its left edge. */
    o.push('<rect class="hi" opacity=".08" x="218" y="176" width="34" height="388"/>');
    o.push('<rect class="hi" opacity=".20" x="218" y="176" width="2.2" height="388"/>');
    o.push('<rect class="sh" opacity=".16" x="249.4" y="176" width="2.6" height="388"/>');
    o.push('<rect class="sh" opacity=".09" x="222.5" y="176" width="1" height="388"/>');
    o.push('<rect class="sh" opacity=".09" x="246" y="176" width="1" height="388"/>');

    /* Collar, built up in four passes: the stand, the dark of the inside seen
       through the opening, then the two blades folding down over it. What stays
       visible between the blades is a narrow V — a shirt, not a keyhole. */
    var stand  = 'M188 126 C204 102 266 102 282 126 C266 118 204 118 188 126 Z';
    var inside = 'M206 124 C216 115 254 115 264 124 L258 141 C248 132 222 132 212 141 Z';
    var bladeL = 'M188 124 C190 152 198 180 212 200 L240 146 C224 140 202 134 192 120 Z';
    var bladeR = 'M282 124 C280 152 272 180 258 200 L230 146 C246 140 268 134 278 120 Z';

    if (!detail) o.push('<path class="gs" d="' + stand + '"/>');
    o.push('<path class="sh" opacity=".18" d="' + stand + '"/>');
    o.push('<path class="hi" opacity=".14" d="M188 126 C204 102 266 102 282 126 C264 108 206 108 188 126 Z"/>');
    o.push('<path class="sh" opacity=".58" d="' + inside + '"/>');

    if (!detail) { o.push('<path class="gs" d="' + bladeL + '"/>'); o.push('<path class="gs" d="' + bladeR + '"/>'); }
    if (hasPat) {
      o.push('<path fill="url(#' + patId + ')" d="' + bladeL + '"/>');
      o.push('<path fill="url(#' + patId + ')" d="' + bladeR + '"/>');
    }
    o.push('<path class="hi" opacity=".17" d="M188 124 C190 152 198 180 212 200 L207 192 C193 172 185 148 183 125 Z"/>');
    o.push('<path class="sh" opacity=".14" d="M282 124 C280 152 272 180 258 200 L263 192 C277 172 285 148 287 125 Z"/>');
    /* A hairline round the collar. Without it the blades share the body's value
       and the whole assembly reads as a crew neck. */
    o.push('<path class="ln sh" opacity=".30" stroke-width="1.5" d="' + bladeL + '"/>');
    o.push('<path class="ln sh" opacity=".30" stroke-width="1.5" d="' + bladeR + '"/>');
    o.push('<path class="ln sh" opacity=".22" stroke-width="1.3" d="M188 126 C204 118 266 118 282 126"/>');

    /* Cuffs, set square to the sleeve axis. */
    o.push('<path class="hi" opacity=".11" d="M26 350 L92 371 L103 337 L37 316 Z"/>');
    o.push('<path class="ln sh" opacity=".20" stroke-width="1.4" d="M37 316 L103 337"/>');
    o.push('<path class="sh" opacity=".10" d="M444 350 L378 371 L367 337 L433 316 Z"/>');
    o.push('<path class="ln sh" opacity=".20" stroke-width="1.4" d="M433 316 L367 337"/>');
    o.push('<circle class="btn" cx="66" cy="344" r="5"/>');
    o.push('<circle class="btn" cx="404" cy="344" r="5"/>');

    /* Nacre buttons. The button's shift — highlights and hairlines only. */
    BUTTON_Y.forEach(function (y) {
      o.push('<circle class="sh" opacity=".20" cx="236.5" cy="' + (y + 2.5) + '" r="6.6"/>');
      o.push('<circle class="btn" cx="235" cy="' + y + '" r="6.6"/>');
      o.push('<circle class="hi" opacity=".55" cx="233" cy="' + (y - 2) + '" r="2.4"/>');
      o.push('<circle class="sh" opacity=".38" cx="232.6" cy="' + y + '" r="1.15"/>');
      o.push('<circle class="sh" opacity=".38" cx="237.4" cy="' + y + '" r="1.15"/>');
      o.push('<circle fill="none" stroke="#000" stroke-opacity=".22" stroke-width=".9" cx="235" cy="' + y + '" r="6.2"/>');
    });

    o.push('</svg>');
    return o.join('');
  }

  /* ---- the mark -------------------------------------------------------- */
  /* Small, unbothered, impossible to intimidate. One colour, no effects.
     The mantle and the eye are cut out of the same path with evenodd, so the
     badger sits on any ground without a second fill. */
  /* A honey badger is a big blunt head, a long flat back and a short thick tail.
     Get the tail wrong and it reads as a rodent, which is the opposite of the
     point: small, unbothered, impossible to intimidate. */
  var BADGER =
    'M128 30 C127 22 121 16 112 13 C107 7 99 4 92 5 ' +
    'C89 1 81 1 79 6 C78 9 79 12 81 14 C72 10 62 8 52 8 ' +
    'C39 8 27 11 19 16 C15 10 8 6 2 6 C2 13 5 20 11 25 ' +
    'C8 33 9 43 14 51 C24 57 40 60 56 59 C71 58 85 54 96 48 ' +
    'C107 45 117 41 124 37 C128 35 129 33 128 30 Z ' +
    /* mantle, cut out — a hairline from the crown to the tail base */
    'M20 22 C29 17 41 14 55 14 C68 14 79 16 87 20 L85 25 ' +
    'C77 21 67 19 55 19 C42 19 31 22 23 27 Z ' +
    'M104 16 a2.3 2.3 0 1 0 0.01 0 Z';

  /* Short and set wide. The animal is built low to the ground. */
  var LEGS = [
    'M22 46 L33 49 L32 62 L21 61 Z',
    'M39 52 L49 54 L48 63 L38 63 Z',
    'M67 54 L77 53 L76 63 L66 63 Z',
    'M84 49 L94 46 L93 61 L83 62 Z'
  ];

  function mark(opts) {
    opts = opts || {};
    var fill = opts.fill || 'currentColor';
    var cls = opts.className ? ' class="' + opts.className + '"' : '';
    var label = opts.label === false ? ' aria-hidden="true"'
      : ' role="img" aria-label="I Am Ratan"';
    var o = ['<svg' + cls + ' viewBox="0 0 132 66" fill="' + fill + '"' + label + '>'];
    LEGS.forEach(function (d) { o.push('<path d="' + d + '"/>'); });
    o.push('<path fill-rule="evenodd" d="' + BADGER + '"/>');
    o.push('</svg>');
    return o.join('');
  }

  /* A flat swatch of the cloth itself, for index rails and colour grids. */
  function swatch(shirt, opts) {
    css();
    opts = opts || {};
    var k = 'sw' + (++uid);
    var patId = 'fab-' + k;
    var hasPat = shirt.weave !== 'solid';
    /* The viewBox matches the garment's own scale. Drawn at 100 units the grid
       and houndstooth tiles would cover a quarter of the swatch each and read as
       a chessboard rather than as cloth. */
    var o = ['<svg class="iar-g" viewBox="0 0 470 470" preserveAspectRatio="xMidYMid slice" ' +
             'style="--g:' + shirt.hex + '" aria-hidden="true">'];
    if (hasPat) o.push('<defs>' + fabric(shirt.weave, patId) + '</defs>');
    o.push('<rect class="gs" width="470" height="470"/>');
    if (hasPat) o.push('<rect width="470" height="470" fill="url(#' + patId + ')"/>');
    return o.join('') + '</svg>';
  }

  root.IAR = root.IAR || {};
  root.IAR.garment = garment;
  root.IAR.mark = mark;
  root.IAR.swatch = swatch;
})(window);
