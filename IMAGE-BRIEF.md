# I Am Ratan — image brief

The site was restructured so photography is used the way a fashion house uses it:
a few images at full-bleed viewport scale, not twenty-five small ones. The
twenty-five shirts now live as a typographic index with woven swatches and need
**no photography at all**.

That leaves **three images that matter**. Everything else on the page is already
covered by what you generated earlier.

---

## The single most important change

Every image on the new site runs **edge to edge at full viewport height**, with
type sitting on top of it. The masters you gave me are portrait (896×1200) and
16:9 (1376×768), so they are being cropped hard to fit a wide screen — that's
why the hero's collar sits where it does.

**Shoot these landscape.** `2560 × 1440` (16:9). It changes more than any prompt
wording will.

---

## Non-negotiables, in every prompt

**Always** — hard engineered directional light from the upper left; controlled
speculars; clean deep shadow; no grain; immaculately pressed cloth with a
dead-straight placket and a structured collar roll; a saturated seamless ground
that is a counterpoint to the garment, never its own hue; nothing incidental in
frame.

**Never** — and these are the ones generators reach for by default:

```
creased, rumpled, wrinkled fabric, soft window light, diffused daylight, golden hour,
warm beige, cream background, wooden table, workshop props, thread spools, scissors,
tape measure, bolts of cloth on shelves, film grain, noise, vignette, bokeh, lifestyle,
visible face, hanger, mannequin head, watermark, text, logo, cluttered, rustic, vintage
```

I checked your current site at iamratan.co.in — the existing photography is bolts
of cloth with a tracing wheel and a wooden handle. That is precisely the register
the brand document rules out ("bolts on old shelves… a story about the past, told
with props, and it is not this house"). None of it is used here.

Add to every prompt: **shot on a Phase One XF with a 120mm macro, f/11, studio
strobe with a hard reflector, colour-accurate, ultra realistic, photographic.**

---

## 1 · `hero.jpg` — the opening frame

Runs the full first screen. Type sits bottom-left, so **leave the lower-left third
uncluttered** and put the garment centre-right.

```
A single Claret #6B2F3A houndstooth dress shirt frozen in mid-air, caught at the top
of its fall, sleeves lifted by the motion but the cloth still knife-pressed and sharp.
Positioned centre-right of frame with open empty ground to the lower left. Seamless
saturated Warm Dune #C2A882 ground, no floor line, no horizon. Hard engineered
directional light from the upper left, one clean specular along the placket, a single
hard shadow thrown down and right. Nacre buttons. Impossibly clean, no grain, no dust.
Shot on a Phase One XF, 120mm macro, f/11, studio strobe with a hard reflector,
colour-accurate, ultra realistic, photographic. 16:9 landscape, 2560x1440.
```

## 2 · `campaign-01.jpg` — Cognac Drift, shirt 15 of 25

One of your two catalogue shirts. The house's own line is *"warm brown against a
cold blue"* — this is that sentence. Type sits bottom-left again.

```
A Cognac Drift #8A6244 garment-dyed twill dress shirt worn on a male torso, cropped
above the chin so no face is visible, shoulders square to camera, arms relaxed at the
sides. The shirt is immaculately pressed, placket dead straight, collar with a clean
structured roll, nacre buttons. Figure positioned right of centre with open empty
ground to the left. Seamless saturated Harbour Blue #2F3E5C ground, flat, no gradient,
no horizon. Hard engineered directional light from the upper left, controlled specular
on the sleeve, clean deep shadow on the right side of the body. Warm brown cloth against
a cold blue field. No grain. Shot on a Phase One XF, 120mm, f/11, studio strobe with a
hard reflector, colour-accurate, ultra realistic, photographic. 16:9 landscape, 2560x1440.
```

## 3 · `campaign-02.jpg` — Ratan's Blue, shirt 02 of 25

Your second catalogue shirt, and the namesake — the document calls it "the one
colour that is not negotiable." This plate is **right-aligned**, so mirror the
composition: garment left of centre, open ground to the **right**.

```
A single Ratan's Blue #B7CAEE Supima poplin dress shirt suspended flat and weightless
in an empty void, front facing, sleeves fallen naturally, no hanger and nothing holding
it up. Positioned left of centre with open empty ground to the right. Seamless saturated
Onyx #2E3033 near-black ground. Hard engineered directional light from the upper left
raking across the cloth, a controlled specular down the placket edge, one hard shadow
falling to the lower right. Knife-sharp sleeve folds, dead-straight placket, collar with
a clean structured roll, nacre buttons. Pale cold blue against near-black. Impossibly
clean, no grain, no texture noise. Shot on a Phase One XF, 120mm macro, f/11, studio
strobe with a hard reflector, colour-accurate, ultra realistic, photographic.
16:9 landscape, 2560x1440.
```

---

## Already covered

| Slot | Currently using | Replace? |
|---|---|---|
| `editorial-03` | your six-collars shot | No — it's the document's own DO example and it works |
| `editorial-01` | figure against concrete | Optional. A 16:9 reshoot would crop better, but it holds |

## Optional fourth, if you want one more

`editorial-02.jpg` — the nacre button on near-black is currently unused on the new
page. If you want a fabric-detail moment between the index and the commission
section, tell me and I'll add the slot.

---

## Dropping them in

Save with the exact filename into `images/`, then:

```bash
vercel deploy --prod --yes
```

`.jpg`, `.webp` and `.png` all work. A slot with no file falls back to its
saturated colour field — never to a drawing.

---

## The mark — done

Traced from `iamratan.co.in`, letters separated from the animal, and installed as
`assets/mark-badger.png` and `assets/mark-monogram.png`. Both are alpha masks, so
the mark takes the ink colour of whatever field it sits on rather than needing one
file per background. The badger alone is used in the nav; the full IAR monogram in
the footer, where it has the 90px the document says it needs.
