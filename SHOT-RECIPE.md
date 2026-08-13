# The shot recipe

The house photography language, locked 4 Aug 2026 on Indigo Oak. Every one of the
25 cloths is shot to this spec so the shop reads as one catalogue rather than
twenty-five separate sessions.

This file exists because the recipe was arrived at by correction, not by design.
Each rule below is here because breaking it produced a bad frame.

---

## The two references — non-negotiable

Every generation passes **two** reference images. Never one.

| Role | Source | Media id |
|---|---|---|
| **The model** | `images/_hero/A-stone.png` | `87ad9f7d-88e1-443d-bc16-4be40c383a37` |
| **The garment** | the client's own product photo for that cloth | one per cloth |

**Why two.** Describing the man in words produces a different man every render —
words describe a type, not a person. Two renders were thrown away to learn this.
The model is a reference image; he is never re-described and never substituted.

**Why the client's photo drives the garment.** We are photographing their real
product, not designing a new one. Cloth, buttons, collar, cuff, stitching all
come from their photograph. Nothing about the garment is invented — no
"mother-of-pearl", no "smoky horn", no restyling. The only thing we control is
the photography.

---

## The space

- Wall **~4 metres behind** the model. Distant, not a backdrop at his shoulder.
- Because of that distance the wall falls **out of focus** while he stays sharp.
- Pale warm stone, **unbroken to all four frame edges**.
- **No floor.** No floor line, skirting, wall-to-floor junction, horizon, corner
  or reflection. The bottom edge of the frame is still wall.

## The camera

- Medium format, **135mm at f/2.8**.
- Long lens, compressed perspective, shallow depth of field.

## The light — two different jobs

The figure shots and the detail shots are NOT lit the same way. Conflating them
produced a rejected collar frame.

**Figure shots (1-hero, 2-back)** — tall window out of frame to the left. The
geometric window pattern is thrown across the **distant wall**, softened by the
distance. That drama is what gives the room its depth.

**Detail shots (3-collar, 4-cuff, 5-button)** — clean, soft, even, fully
diffused light with generous fill. **NO cast shadow of any kind on the
garment.** No window pattern, no hard edge, no diagonal band, no half-lit
cloth. The only shadows in frame are the garment's own: the roll of the collar
leaf, the raised placket edge, the seating of a button, the relief of the
embroidery. The colour must read as one even tone across the whole frame.

A shadow falling across the product hides the product. These frames exist to
show construction, so nothing is allowed to sit on top of it.

Natural-looking daylight throughout. No flash, no strobe, no gels.

## The crop

- **Mid-thigh to just above the head.** Feet far outside the frame.
- Subject fills ~70% of the frame width.
- Portrait 3:4, 2k, quality high.

## The styling

- Shirt pressed, cut close, shoulder seam on the shoulder point, no billowing.
- **Sleeves full length, both cuffs buttoned.** Never rolled.
- Top button open, no tie. Tucked into charcoal wool flat-front trousers.
- No jewellery, watch, glasses or jacket.

## The cuff — read this before writing any cuff prompt

Established by tracing the topstitched edge in the client's own photograph at
full zoom. Two frames were rejected before this was measured rather than read.

**Two buttons are visible, on two different pieces of the shirt.** The cuff's
rounded topstitched edge runs BETWEEN them, and that edge must be plainly
visible in the frame:

| Button | Where it actually sits |
|---|---|
| Upper | **on the cuff**, inside the rounded edge, buttonhole slit just above it |
| Lower | **on the sleeve**, beyond the cuff edge — the gauntlet button |

The two failures to avoid, both of which happened:
- **v1** — both buttons on the cuff face as a stacked pair, no edge between them.
- **v2** — the second button deleted entirely.

Neither matches. One on the cuff, one on the sleeve, the curved edge between.

### The signature — measured, not described

Established by PCA on the embroidery's own stitch gradient versus a line fitted
to the cuff's topstitched border, then verified by drawing both axes back onto
the photograph.

| | measured |
|---|---|
| **Tilt** | **+16° clockwise** off the cuff's border — left end high, right end low |
| **Width** | **~40%** of the cuff's width |
| **Position** | upper-middle of the cuff face, above the buttonhole and button |

**The tilt is the thing that keeps getting missed.** The signature is NOT square
with the cuff — it lies across it at an angle, like a handwritten signature.
Earlier prompts in this project said "baseline parallel to the cuff's edge so it
sits square rather than tilted", which is the exact opposite of the product, and
every frame generated from them was wrong in the same way.

Form: an angular monogram — tall upright stroke, rounded form, peaked M — with a
flowing script beneath and slightly left, the script sloping down to the right
too. Embroidered tone on tone, visible only through its own stitch relief.

Reference images that show the mark large are enlargements, not the product.

### The mark is composited, not generated

Four attempts confirmed the generator can place a mark that reads plausibly at
page size but never draws their artwork, and its proportions drift toward square
when the real mark is 1.46 wide-to-tall. So it is no longer generated.

[iar-lab/emboss.py](iar-lab/emboss.py) lifts the generated mark off the cloth
and composites `assets/mark-signature.png` — the client's own file — in its
place, at the measured 40% width and +16° tilt, perspective-mapped into the
cuff's own plane and rendered as stitch relief rather than as ink.

Two things that had to be right, both learned by getting them wrong:

- **Removal.** Only the strokes are replaced. A grey dilation was tried first
  and bleached the whole patch, because MaxFilter takes the lightest pixel in
  its neighbourhood and the cloth is dark. The region is now split into the
  cuff's gradient and its high-frequency residual, and only the markedly darker
  part of that residual is pushed back — so the weave survives.
- **Relief.** Highlight up-left, shadow down-right, kept close in value. Wider
  blur turns the offset bands into a halo and the mark reads as a smudge.

**Per-frame cost:** the cuff's four corners are read off a gridded preview and
recorded in `QUADS`. One entry per cuff render — about a minute each, 24 to go.

The cuff itself: barrel, one rounded outer corner, topstitched border following
the curve, signature embroidered tone on tone. When fastened, the rounded outer
side lies **on top** and the under side passes **beneath** it, hidden, showing
only as a soft thickness at the wrist.

**Pose:** forearm raised, wrist up, arm running diagonally from lower-left to
upper-right with the hand at the top of frame, cuff centred and its face turned
to the camera. Chosen by the client over the arm-down version.

## Colour comes from the shirt, construction comes from the cuff photo

The cuff photograph is of the **navy** shirt. It is the authority for shape,
stitching, button form and the engraving — **never for colour**. Every cloth's
colour and button tone come from that cloth's own product photograph.

## No topstitching — anywhere

Established from the client's own high-resolution originals (`images/_orig/`,
6000×4000 camera files supplied 4 Aug 2026). Every frame generated before this
was wrong in the same way.

**The garment has no topstitching.** Not around the rounded cuff edge, not down
either side of the placket, not along the collar edge. Those edges are **clean
folded and pressed edges** — a soft tonal ridge with a faint shadow, never a
line of thread.

The **only** thread visible anywhere on the shirt is:

- each button's own crossed thread through its four holes
- the small bar tacks at the ends of each buttonhole slit

Generators add topstitching by default because most shirts have it. This one
does not, and the unstitched minimal edge is the most distinctive thing about
its construction. Every prompt must say so explicitly, and say what to draw
instead: *if you are about to draw a line of stitches along an edge, draw a
clean pressed fold instead.*

The construction authority is `images/_ref/construction.jpg` and
`images/_ref/placket.jpg`, cropped from those originals — media
`19e7d571-50e7-4948-afbb-17c8c43c415b` and `41c649aa-2d33-46b3-883d-d252aa2b0a4e`.

## THERE IS NO PLACKET BAND — ON ANY SHIRT

Client, 4 Aug 2026: *"there is no band for any shirts."*

The shirt front is a **single smooth unbroken plane of cloth**. The buttons sit
directly on it. There is no strip of doubled fabric, no raised band, no ridge,
no rolled edge, no lip, no fold line, no crease and no tonal seam running down
beside the buttons. The buttons are the only interruption in that surface.

This is the house's signature and it is the detail most often got wrong, because
almost every dress shirt in the world has a band and generators default to one.

**It cost three rounds to see.** The sequence was: the client flagged a line
beside the buttons; I diagnosed *topstitching* and removed the stitch marks; the
line was still there because the **band** was still there. Removing stitches
from a band leaves a band.

**The check that would have caught it in seconds:** put the frame next to the
locked Indigo Oak hero and look at the front. The locked frame has no band. I
had been comparing against the client's linen photograph instead, which does
show a soft placket fold, and against my memory of the locked frame rather than
the frame itself.

> Diff against the approved frame, never against a description of it.

### Supersedes

The earlier instruction "the placket opening is on the LEFT" no longer applies
to the button macro. With no band there is no opening edge to place. Draw
unbroken cloth with the button on it and nothing else.

## ~~The placket opening is on the LEFT~~ — superseded, see above

In every frame that shows the button front — the hero, the collar, and above all
the button macro — **the placket's free edge runs down the LEFT-HAND side of the
buttons.**

- To the **left** of a button: the soft pressed fold, then the edge of the
  placket band where the shirt front opens.
- To the **right** of a button: unbroken cloth continuing across the chest.

The macro is generated with no body in frame to orient it, so it flips to the
wrong side unless told. State it explicitly every time, and add *"mirror the
arrangement if necessary so the opening falls on the LEFT."*

Check it against the long shot before accepting any button or collar frame — the
full-length photograph is the reference for which side the shirt opens on.

## The button must have material presence

The failure to watch for is a button that reads as a **flat, soft, uniform grey
disc** — technically the right colour, but with no substance. It looks washed
out and cheapens the whole frame.

A button that reads correctly has:

| | |
|---|---|
| Rim | crisply defined and raised, a thin specular highlight along its upper-left, dropping to a distinct shadow lower-right |
| Centre | a clearly recessed well, deeper than the rim, with its own soft internal shading |
| Holes | genuinely **dark and open** — real depth with a shadow inside, never grey dots |
| Engraving | cut sharply INTO the rim, each letter carrying a crisp dark shadow in its cut |
| Surface | a subtle tight sheen — a smooth solid material against matte woven cloth |
| Seating | a small soft contact shadow beneath it, so it sits ON the cloth |

**Its presence comes from contrast WITHIN itself, not from being paler than the
shirt.** Measured on the real goods, the buttons are tonal with their cloth:
Indigo Oak's are dark near-black on charcoal, Ratan's Blue's are white on pale
blue. Lightening a dark button to give it "presence" is the wrong fix — deepen
the holes and sharpen the cut shadows instead.

## The cuff frame

The client selected the **earlier** cuff master — the one before the
topstitching correction. It is kept as-is at their direction. Note that it
therefore still carries a topstitched border, which the real garment does not
have; that is a knowing trade, not an oversight.

## Always excluded

A different man · any floor · a sharp or close wall · neck label, size tab or
brand tag · printed text, watermarks, coloured patch overlays · rolled sleeves ·
extra or missing buttons · waxy skin, over-smoothing, HDR glow · malformed hands.

---

## Verification — measured, not eyeballed

Every frame is checked before it is accepted. Two numbers:

**Floor test.** Largest row-to-row tonal step across the background columns in
the lower 45% of the frame. A visible floor line reads **8 or above**.

**Depth test.** Edge-energy of the background versus edge-energy of the shirt.
The subject must be at least **3× sharper** than the wall.

Indigo Oak hero, accepted: floor step **0.57**, subject **3.7×** sharper.

---

## The shot set

Five frames per cloth, matching `assets/shots.js`:

| # | Frame | Status on Indigo Oak |
|---|---|---|
| 1 | `1-hero` — three-quarter front, hand in pocket, gaze into the light | **locked** |
| 2 | `2-back` — yoke, shoulder seams, side seams | in progress |
| 3 | `3-collar` — collar shape and the engraved buttons | pending |
| 4 | `4-cuff` — fastened cuff, signature embroidered tone on tone | pending |
| 5 | `5-button` — I AM RATAN engraved around the rim | pending |

Frames 3–5 are macros. The model's face is out of frame, so they carry the
garment and the light but not the identity problem.

---

## Open — colour grading

Generated cloth drifts from the catalogue hex. Indigo Oak came back `#262328`
against a catalogue `#3D3C43`. The intended fix is a final grade of each render
back to the exact catalogue colour, so the shirt on the model matches the swatch
on the shop page. **Not yet wired in — awaiting sign-off.**
