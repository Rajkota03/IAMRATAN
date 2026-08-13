/* I AM RATAN — house data.
   Loaded as a classic script so the pages open from file:// without a server.
   Every colour here is from the house palette. Nothing was invented to look good in a swatch. */

(function (root) {
  'use strict';

  /* The six values that carry everything. */
  var CORE = {
    navy: '#1C254A',   // the monogram. ink for everything on paper.
    blue: '#B7CAEE',   // the namesake shirt. not negotiable.
    bone: '#EDE9E0',   // ground. warmer than white, never cream.
    claret: '#6B2F3A', // the accent, used once per page.
    nacre: '#E2DBE1',  // the button's shift. highlights and hairlines only.
    black: '#0C0B0A'   // grounds that carry a single lit object.
  };

  /* Twenty-five shirts, and only four of them are white.
     `ground` is the field the garment is shown against — a counterpoint drawn from
     the same palette, never the garment's own hue. A cognac shirt on ultramarine. */
  var SHIRTS = [
    { n: 1,  name: "Blanc Celestia",    hex: '#F2F2F0', ground: '#1C254A', price: 2999, coll: 'Blanc',    weave: 'solid',   cloth: 'Supima poplin',      spec: '2-ply 100s · 110 gsm' },
    { n: 2,  name: "Ratan's Blue",      hex: '#B7CAEE', ground: '#2E3033', price: 3499, coll: 'Azur',     weave: 'solid',   cloth: 'Supima poplin',      spec: '2-ply 120s · 105 gsm' },
    { n: 3,  name: "Obsidian",          hex: '#16171A', ground: '#EDE9E0', price: 3299, coll: 'Terre',    weave: 'solid',   cloth: 'Brushed twill',      spec: '2-ply 80s · 140 gsm'  },
    { n: 4,  name: "Indigo Oak",        hex: '#4A5570', ground: '#C2A882', price: 3699, coll: 'Azur',     weave: 'solid',   cloth: 'Supima twill',       spec: '2-ply 100s · 130 gsm' },
    { n: 5,  name: "Moonlight Speckle", hex: '#E6E4DE', ground: '#6B2F3A', price: 3999, coll: 'Blanc',    weave: 'speckle', cloth: 'End-on-end',         spec: '2-ply 120s · 108 gsm' },
    { n: 6,  name: "Midnight Speckle",  hex: '#22252D', ground: '#B7CAEE', price: 3999, coll: 'Terre',    weave: 'speckle', cloth: 'End-on-end',         spec: '2-ply 100s · 118 gsm' },
    { n: 7,  name: "Cobalt Charm",      hex: '#3E5A8C', ground: '#E8E3D6', price: 3599, coll: 'Azur',     weave: 'solid',   cloth: 'Royal oxford',       spec: '2-ply 100s · 145 gsm' },
    { n: 8,  name: "Blanc Dewdrop",     hex: '#F0F0EC', ground: '#5E6449', price: 2999, coll: 'Blanc',    weave: 'solid',   cloth: 'Sea-island poplin',  spec: '2-ply 140s · 100 gsm' },
    { n: 9,  name: "Azure Pearls",      hex: '#9FB6D9', ground: '#2B2A2E', price: 3499, coll: 'Azur',     weave: 'solid',   cloth: 'Supima poplin',      spec: '2-ply 120s · 105 gsm' },
    { n: 10, name: "Blanc Canvas",      hex: '#F4F4F2', ground: '#16171A', price: 2999, coll: 'Blanc',    weave: 'solid',   cloth: 'Supima oxford',      spec: '2-ply 80s · 150 gsm'  },
    { n: 11, name: "Aegean Haze",       hex: '#8FA0AD', ground: '#6B2F3A', price: 3399, coll: 'Azur',     weave: 'solid',   cloth: 'Chambray',           spec: '2-ply 100s · 120 gsm' },
    { n: 12, name: "Pebble Mist",       hex: '#C4C6C6', ground: '#232C4A', price: 3199, coll: 'Blanc',    weave: 'solid',   cloth: 'Supima poplin',      spec: '2-ply 100s · 110 gsm' },
    { n: 13, name: "Midnight Navy",     hex: '#232C4A', ground: '#BFAE96', price: 3799, coll: 'Azur',     weave: 'solid',   cloth: 'Supima twill',       spec: '2-ply 120s · 132 gsm' },
    { n: 14, name: "Storm Grey",        hex: '#5C6066', ground: '#EDE9E0', price: 3299, coll: 'Terre',    weave: 'solid',   cloth: 'Brushed twill',      spec: '2-ply 80s · 138 gsm'  },
    { n: 15, name: "Cognac Drift",      hex: '#8A6244', ground: '#2F3E5C', price: 4499, coll: 'Terre',    weave: 'solid',   cloth: 'Garment-dyed twill', spec: '2-ply 100s · 142 gsm' },
    { n: 16, name: "Dune Sand",         hex: '#BFAE96', ground: '#1C254A', price: 3899, coll: 'Terre',    weave: 'solid',   cloth: 'Linen-cotton',       spec: '2-ply 80s · 128 gsm'  },
    { n: 17, name: "Marina Stripe",     hex: '#7FA3CC', ground: '#EDE9E0', price: 4299, coll: 'Azur',     weave: 'stripe',  cloth: 'Bengal stripe',      spec: '2-ply 120s · 112 gsm' },
    { n: 18, name: "Phantom Stripe",    hex: '#2B2A2E', ground: '#E2DBE1', price: 4199, coll: 'Terre',    weave: 'stripe',  cloth: 'Shadow stripe',      spec: '2-ply 100s · 124 gsm' },
    { n: 19, name: "Ivory Grid",        hex: '#E8E3D6', ground: '#2F3E5C', price: 4099, coll: 'Blanc',    weave: 'grid',    cloth: 'Graph check',        spec: '2-ply 120s · 108 gsm' },
    { n: 20, name: "Forest Weave",      hex: '#5E6449', ground: '#E2DBE1', price: 4699, coll: 'Terre',    weave: 'weave',   cloth: 'Herringbone',        spec: '2-ply 100s · 148 gsm' },
    { n: 21, name: "Onyx Hound",        hex: '#2E3033', ground: '#EDE9E0', price: 4999, coll: 'Terre',    weave: 'hound',   cloth: 'Houndstooth',        spec: '2-ply 100s · 152 gsm' },
    { n: 22, name: "Warm Dune",         hex: '#C2A882', ground: '#232C4A', price: 3799, coll: 'Terre',    weave: 'solid',   cloth: 'Supima twill',       spec: '2-ply 100s · 130 gsm' },
    { n: 23, name: "Claret Hound",      hex: '#6B2F3A', ground: '#E6E4DE', price: 5999, coll: 'Terre',    weave: 'hound',   cloth: 'Houndstooth',        spec: '2-ply 120s · 150 gsm' },
    { n: 24, name: "Azure Thread",      hex: '#6E93C4', ground: '#2E3033', price: 3999, coll: 'Azur',     weave: 'solid',   cloth: 'Royal oxford',       spec: '2-ply 120s · 140 gsm' },
    { n: 25, name: "Harbour Blue",      hex: '#2F3E5C', ground: '#C2A882', price: 6999, coll: 'Azur',     weave: 'solid',   cloth: 'Sea-island twill',   spec: '2-ply 170s · 135 gsm' }
  ];

  var COLLECTIONS = [
    { key: 'Blanc',  count: 6,  note: 'Four whites and the two that stand next to them.' },
    { key: 'Azur',   count: 9,  note: 'The namesake and everything that answers to it.' },
    { key: 'Terre',  count: 10, note: 'Cognac, dune, forest, claret, and the near-blacks.' }
  ];

  var SIZES = [39, 40, 41, 42, 43, 44, 45, 46];

  var HOUSE = {
    name: 'I Am Ratan',
    city: 'Hyderabad',
    phone: '+91 82828 26264',
    email: 'prashanth@iamratan.co.in',
    social: '@iamratanofficial',
    entry: 2999,
    top: 6999,
    average: 3991,
    stock: 25,
    collections: 3,
    measurements: 30,
    weeks: 3
  };

  /* ---- colour helpers -------------------------------------------------- */

  function srgbToLin(c) {
    c = c / 255;
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  }

  function luminance(hex) {
    var h = hex.replace('#', '');
    var r = parseInt(h.slice(0, 2), 16),
        g = parseInt(h.slice(2, 4), 16),
        b = parseInt(h.slice(4, 6), 16);
    return 0.2126 * srgbToLin(r) + 0.7152 * srgbToLin(g) + 0.0722 * srgbToLin(b);
  }

  function contrast(a, b) {
    var la = luminance(a), lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
  }

  /* Picks whichever house ink actually clears 4.5:1 on the given field.
     Mid-tones like Storm Grey and Aegean Haze fall on opposite sides of the line,
     so this is measured rather than guessed.

     Cognac Drift is the one ground where neither house value reaches 4.5 — bone
     lands at 4.43 — so the fallback opens up to pure white or black. At label
     size it is indistinguishable from bone, and the text is legible. */
  function inkOn(bg) {
    var best = contrast(CORE.black, bg) >= contrast(CORE.bone, bg) ? CORE.black : CORE.bone;
    if (contrast(best, bg) >= 4.5) return best;
    return contrast('#FFFFFF', bg) >= contrast('#000000', bg) ? '#FFFFFF' : '#000000';
  }

  function isLight(hex) {
    return luminance(hex) > 0.45;
  }

  /* Rupees in tabular figures. They sit in columns and must align. */
  function rupees(n) {
    return '₹' + n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  }

  function pad(n) {
    return n < 10 ? '0' + n : String(n);
  }

  function byCollection(key) {
    return SHIRTS.filter(function (s) { return s.coll === key; });
  }

  root.IAR = {
    CORE: CORE,
    SHIRTS: SHIRTS,
    COLLECTIONS: COLLECTIONS,
    SIZES: SIZES,
    HOUSE: HOUSE,
    luminance: luminance,
    contrast: contrast,
    inkOn: inkOn,
    isLight: isLight,
    rupees: rupees,
    pad: pad,
    byCollection: byCollection
  };
})(window);
