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
  '2-view':   ', worn \u2014 another view',
  '3-view':   ', worn \u2014 another view',
  '2-back':   ' from behind, showing the yoke and the shoulder seams',
  '3-collar': ' \u2014 the collar, open at the throat'
};

function shoot(name, frames, room) {
  return {
    room: room || window.IAR_ROOM,
    shots: frames.map(function (f) { return { src: f, alt: name + ALT[f] }; })
  };
}

window.IAR_SHOTS = {
  'aegean-haze':        shoot('Aegean Haze', ['1-hero', '2-view', '3-view']),
  'azure-pearls':       shoot('Azure Pearls', ['1-hero', '2-view', '3-view']),
  'azure-thread':       shoot('Azure Thread', ['1-hero', '2-view', '3-view']),
  'blanc-canvas':       shoot('Blanc Canvas', ['1-hero', '2-back', '3-collar'], STUDIO_AUG12),
  'blanc-celestia-2':   shoot('Blanc Celestia', ['1-hero', '2-back', '3-collar'], STUDIO_AUG12),
  'blanc-dewdrop':      shoot('Blanc Dewdrop', ['1-hero', '2-view', '3-view']),
  'claret-hound':       shoot('Claret Hound', ['1-hero', '2-view', '3-view']),
  'cobalt-charm':       shoot('Cobalt Charm', ['1-hero', '2-view']),
  'cocoa-drift':        shoot('Cocoa Drift', ['1-hero', '2-view']),
  'cognac-drift':       shoot('Cognac Drift', ['1-hero', '2-view', '3-view']),
  'dune-sand':          shoot('Dune Sand', ['1-hero', '2-back', '3-collar'], STUDIO_AUG12),
  'forest-weave':       shoot('Forest Weave', ['1-hero', '2-back', '3-collar'], STUDIO_AUG12),
  'harbour-blue':       shoot('Harbour Blue', ['1-hero', '2-view', '3-view']),
  'indigo-oak':         shoot('Indigo Oak', ['1-hero', '2-view', '3-view']),
  'ivory-grid':         shoot('Ivory Grid', ['1-hero', '2-view', '3-view']),
  'marina-stripe':      shoot('Phantom Stripe', ['1-hero', '2-view', '3-view']),
  'marina-stripe-3':    shoot('Marina Stripe', ['1-hero', '2-view', '3-view']),
  'midnight-navy':      shoot('Midnight Navy', ['1-hero', '2-view', '3-view']),
  'midnight-speckle':   shoot('Midnight Speckle', ['1-hero', '2-view', '3-view']),
  'moonlight-speckle':  shoot('Moonlight Speckle', ['1-hero', '2-back', '3-collar'], STUDIO_AUG12),
  'obsidian':           shoot('Obsidian', ['1-hero', '2-view', '3-view']),
  'onyx-hound':         shoot('Onyx Hound', ['1-hero', '2-view', '3-view']),
  'pebble-mist':        shoot('Pebble Mist', ['1-hero', '2-view', '3-view']),
  'ratans-blue':        shoot('Ratan\'s Blue', ['1-hero', '2-view', '3-view']),
  'slate-harbour':      shoot('Slate Harbour', ['1-hero', '2-view']),
  'storm-grey':         shoot('Storm Grey', ['1-hero', '2-view', '3-view']),
  'warm-dune':          shoot('Warm Dune', ['1-hero', '2-view', '3-view'])
};
