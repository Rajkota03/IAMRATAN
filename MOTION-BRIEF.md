# I Am Ratan — motion brief

You offered to generate motion. Here is what would actually change how the site
feels, in the order it would change it. Everything below is **video**, not
animation-in-code — the code motion is already built.

All of it obeys the same house rules as the stills: hard engineered directional
light, no grain, no props, no soft window light, immaculately pressed cloth,
saturated grounds. Add this to every generation:

```
no grain, no film grain, no noise, no vignette, no bokeh, no soft diffused light,
no warm beige, no wooden surfaces, no workshop props, no visible face, no hanger,
no creasing, no rumpling, no text, no watermark, no camera shake
```

---

## 1 · `cloth-loop.mp4` — the single highest-value asset

A **seamless 6-second loop** of cloth in slow motion under a raking light. This
becomes the full-bleed backdrop behind the opening of the main site, replacing a
still. One asset, and the whole page stops feeling like a page.

```
Extreme slow motion of a single panel of Ratan's Blue #B7CAEE Supima poplin
suspended in a black void, moving very slightly as though breathing — a slow
undulation, no more than a few centimetres of travel. Hard engineered directional
light rakes across it from the upper left, so the specular highlight travels along
the weave as the cloth moves. Deep clean shadow in the folds. The cloth stays
knife-pressed and sharp; it never crumples. Seamless loop, first and last frame
identical. Locked-off camera, no shake, no zoom. Impossibly clean, no grain.
6 seconds, 16:9, 2560x1440, 30fps.
```

Make three: `cloth-loop-blue.mp4`, `cloth-loop-cognac.mp4` (#8A6244 on Harbour
Blue #2F3E5C), `cloth-loop-claret.mp4` (#6B2F3A on Warm Dune #C2A882).

## 2 · `weave-macro.mp4` — proof of the cloth

The house sells 2-ply 120s. Show it. This sits behind the range index and does
more for credibility than any adjective.

```
Extreme macro of woven cotton shirting, the individual warp and weft threads
clearly resolved, filling the frame. A hard specular highlight travels slowly
across the weave from left to right as the light source moves, revealing the
texture in relief. Static camera, static cloth — only the light moves. Seamless
loop. Colour: Cognac Drift #8A6244. No grain, no dust, no fibres lifting.
5 seconds, 16:9, 2560x1440, 30fps.
```

## 3 · `turntable-{name}.webm` — the 2040 and 2050 record

A garment rotating slowly on its vertical axis against a **transparent
background**, so it can be dropped straight onto any of the twenty-five colour
grounds without a matte line. This is what would let the record view rotate under
the viewer's finger instead of rendering.

```
A single dress shirt in [COLOUR NAME] [HEX], suspended and weightless, rotating
slowly and evenly through a full 360 degrees on its vertical axis. Front-facing at
frame one and frame last so the loop is seamless. Immaculately pressed: knife-sharp
sleeve folds, dead-straight placket, structured collar roll, nacre buttons. Hard
engineered directional light fixed from the upper left, so the specular travels
across the cloth as the garment turns. Transparent background, alpha channel, no
ground, no shadow catcher. Ultra realistic, photographic, no grain.
8 seconds, square 1600x1600, 30fps, WebM with alpha.
```

Only worth doing for the **two catalogue shirts** — Cognac Drift #8A6244 and
Ratan's Blue #B7CAEE. The other twenty-three stay as rendered cloth.

## 4 · `collar-detail.mp4` — the close

Slow push on a collar and placket, for the closing section.

```
Slow, steady push-in on the collar and upper placket of a Midnight Navy #232C4A
Supima twill shirt. The collar roll and a single nacre button fill the frame by
the end of the move. Hard engineered directional light from the upper left with a
controlled specular on the button. Seamless, no camera shake, constant speed.
Seamless saturated Dune Sand #BFAE96 ground. No grain.
5 seconds, 16:9, 2560x1440, 30fps.
```

---

## Dropping them in

Save into `images/` with those exact names. Video slots are not wired yet — tell
me which ones you've generated and I'll swap the corresponding stills for
`<video autoplay muted loop playsinline>` with the still as its poster frame, so
nothing regresses on slow connections or when the browser blocks autoplay.

**Formats:** `.mp4` (H.264) for the loops, `.webm` (VP9 with alpha) for the
turntables. Keep each loop under ~4 MB — a hero video that takes six seconds to
arrive is worse than the still it replaced.
