/* I AM RATAN — the shot sets.

   Each cloth declares the frames it actually has, because the range was not all
   shot the same way and pretending otherwise puts a lie in the alt text.

   The 11 August set gave three frames per cloth in no fixed order, so those are
   named 1-hero / 2-view / 3-view and described only as "worn". The 12 August
   reshoot of five cloths was directed — front, back, collar — so those say so.

   The frame lists below are WRITTEN OUT, not discovered by scanning the folder.
   Scanning is what put a different shirt on the back of five cards: the cloths
   photographed before August kept their old 2-back and 3-collar files beside
   the new hero, and a directory listing cannot tell one shoot from another. The
   orphans are deleted and the manifest is now the single source of truth — if a
   frame is not named here it does not exist, whatever is lying in the folder.

   `room` is the wall the cloth was shot against, so the product page can sit the
   frame on its own ground. Measured off the corners of the plates: the August 12
   studio is #EDECEC, about 1.5 dE from the August 11 room. */

window.IAR_ROOM   = '#EFEDE9';
var STUDIO_AUG12  = '#EDECEC';

var ALT = {
  '1-hero':   ', worn',
  '2-view':   ', worn. Another view',
  '3-view':   ', worn. Another view',
  '2-back':   ' from behind, showing the yoke and the shoulder seams',
  '3-collar': '. The collar, open at the throat',
  /* The two details the house is actually known for, and the two a customer
     cannot judge from a photograph of a whole shirt. The alt text names what is
     engraved and what is embroidered, because that is the fact the picture is
     carrying and a blind customer is buying the same detail. */
  '4-cuff':   '. The cuff, with the house signature embroidered tone on tone',
  '5-button': '. A button in close-up, I AM RATAN engraved around the rim'
};

/* Frames that also carry a 1024px file. The worn shots were delivered at 768
   and cannot honestly go wider, but the cuff and button close-ups came in at
   1086, and they are the two frames where a retina desktop plate (which wants
   1178) was visibly upscaling the thing the picture exists to show. Declared
   here rather than hardcoded in the gallery so the manifest stays the single
   source of truth about what each frame actually has. */
window.IAR_WIDE = { '4-cuff': 1024, '5-button': 1024 };

function shoot(name, frames, room) {
  return {
    room: room || window.IAR_ROOM,
    shots: frames.map(function (f) { return { src: f, alt: name + ALT[f] }; })
  };
}

window.IAR_SHOTS = {
  'aegean-haze':        shoot('Aegean Haze', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'azure-pearls':       shoot('Azure Pearls', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'azure-thread':       shoot('Azure Thread', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'blanc-canvas':       shoot('Blanc Canvas', ['1-hero', '2-back', '3-collar', '4-cuff', '5-button'], STUDIO_AUG12),
  'blanc-celestia-2':   shoot('Blanc Celestia', ['1-hero', '2-back', '3-collar', '4-cuff', '5-button'], STUDIO_AUG12),
  'blanc-dewdrop':      shoot('Blanc Dewdrop', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'claret-hound':       shoot('Claret Hound', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'cobalt-charm':       shoot('Cobalt Charm', ['1-hero', '2-view', '4-cuff', '5-button']),
  'cocoa-drift':        shoot('Cocoa Drift', ['1-hero', '2-view', '4-cuff', '5-button']),
  'cognac-drift':       shoot('Cognac Drift', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'dune-sand':          shoot('Dune Sand', ['1-hero', '2-back', '3-collar', '4-cuff', '5-button'], STUDIO_AUG12),
  'forest-weave':       shoot('Forest Weave', ['1-hero', '2-back', '3-collar', '4-cuff', '5-button'], STUDIO_AUG12),
  'harbour-blue':       shoot('Harbour Blue', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'indigo-oak':         shoot('Indigo Oak', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'ivory-grid':         shoot('Ivory Grid', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'marina-stripe':      shoot('Phantom Stripe', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'marina-stripe-3':    shoot('Marina Stripe', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'midnight-navy':      shoot('Midnight Navy', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'midnight-speckle':   shoot('Midnight Speckle', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'moonlight-speckle':  shoot('Moonlight Speckle', ['1-hero', '2-back', '3-collar', '4-cuff', '5-button'], STUDIO_AUG12),
  'obsidian':           shoot('Obsidian', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'onyx-hound':         shoot('Onyx Hound', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'pebble-mist':        shoot('Pebble Mist', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'ratans-blue':        shoot('Ratan\'s Blue', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'slate-harbour':      shoot('Slate Harbour', ['1-hero', '2-view', '4-cuff', '5-button']),
  'storm-grey':         shoot('Storm Grey', ['1-hero', '2-view', '3-view', '4-cuff', '5-button']),
  'warm-dune':          shoot('Warm Dune', ['1-hero', '2-view', '3-view', '4-cuff', '5-button'])
};
