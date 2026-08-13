# What size to make the pictures

Every slot on the site crops with CSS `object-fit: cover`, which means the
browser throws away whatever does not fit the shape of the box. Give it the
right shape and nothing is lost. Give it the wrong one and it takes the
difference off an edge — usually the top, which is where heads are.

Run the checker before sending anything:

```bash
python3 iar-lab/fit.py hero-wide ~/Desktop/new-shot.jpg
```

It prints the verdict and writes a preview showing exactly what the browser
will keep, what it will cut at three common screen shapes, and where the
headline will land.

---

## The slots

| slot | file | shape | smallest usable | ideal |
|---|---|---|---|---|
| `hero-wide` | `images/hero/*-wide.jpg` | **16:9** | 1600 × 900 | 2400 × 1350 |
| `hero-tall` | `images/hero/*-tall.jpg` | **4:5** | 1080 × 1350 | 1600 × 2000 |
| `door-wide` | `images/hero/ready-wide.jpg` | **5:4** | 1200 × 960 | 1800 × 1440 |
| `door-tall` | `images/hero/ready-tall.jpg` | **3:4** | 1080 × 1440 | 1600 × 2133 |
| `plate` | `images/campaign/*.jpg` | **16:9** (3:2 also fine) | 1920 × 1080 | 2560 × 1440 |
| `journal` | `images/journal/*.jpg` | **4:5** | 660 × 825 | 1320 × 1650 |
| `square` | the frame beside the copy | **1:1** | 1200 × 1200 | 1800 × 1800 |

Shape matters more than size. A 16:9 picture at 1600px wide works; a 3:2
picture at 4000px wide gets a fifth of itself cut off.

---

## The rules that actually bite

**1. Headroom. Leave 10% of the frame above the top of the head.**

This is the one that keeps going wrong. A phone window is about 0.46 wide-to-tall
and a laptop about 1.85, so the same picture gets cropped in opposite directions
on the two. The site now crops from the FOOT of every hero frame rather than the
middle, so a head is never cut — but that only works if there is a head to keep.
Of the three frames in the hero today, the jet has 3% of headroom above the crown
and the city 8%. Both are at the limit of what the source allows.

**2. Hero frames: keep the right 40% quiet.**

The headline, the paragraph and the button sit bottom-right on a wide screen, in
a band from 58% to 93% across and 45% to 92% down. Nobody's face should be in
that band. It does not need to be empty — dark, soft or out of focus is enough;
the veil does the rest — but a face there fights the type and loses.

The model should stand centre or left of centre. All three current frames do.

**3. Full-bleed plates: keep any lettering inside the middle.**

The plates run edge to edge on a wide screen at 74% of the window's height,
which on a laptop is a 2.4:1 letterbox. A 16:9 picture loses about a quarter of
its height to that. So baked-in lettering has to sit within the **middle 72%
vertically and the middle 84% horizontally**, or it gets cut.

On a phone the plates are shown whole with bone above and below, so nothing is
lost there — but that also means a 16:9 plate is only a 210px strip on a phone.
A frame with no lettering in it is better sent as a `hero-wide` and cropped.

**4. No baked-in type on hero frames.**

The hero sets its own type in HTML, so it stays sharp at any size, reflows on a
phone, is readable to a screen reader, and can be changed without a reshoot. If
a supplied frame has lettering in it, the crop has to dodge it, which usually
costs the composition. Send hero frames clean.

**5. Vary the light, and vary the man.**

The client's note on the first round was that every frame shares one ambient —
same hour, same softness, same key. A campaign reads as a campaign when the
light changes and the man stays recognisable, not the other way round. So:

- **two or three models across the set**, different hair and different faces,
  not one man in every frame
- **change the hour**: hard noon, low gold, overcast flat, a lit interior at
  night. One of each beats four of the same
- **keep the room honest to the cloth** — a coloured wall bounces onto skin and
  drifts the complexion, which is why the product sets are all shot in one
  neutral room. That rule is for the SHOP frames. The campaign frames are free

**6. Colour space and format.**

sRGB, JPEG, quality 88 or better. Not P3 — Safari will show it correctly and
Chrome on Windows will not, and the shirt colour is the product.

---

## What happens to each slot on a real screen

Measured, not estimated — these are the actual boxes the CSS produces.

| slot | phone (375 × 812) | laptop (1440 × 800) |
|---|---|---|
| `hero-wide` | not used | 1440 × 800 → box 1.80, crops the sides |
| `hero-tall` | 375 × 422 → crops ~10% off the foot | not used |
| `door-tall` | 375 × 552 → box 0.68 | not used |
| `door-wide` | not used | 719 × 624 → box 1.15 |
| `plate` | 375 × 211, whole picture, nothing cut | 1440 × 592 → box 2.43, crops the height |
| `square` | 340 × 340, nothing cut | ~700 × 700, nothing cut |

---

## Where the current pictures actually stand

Run `python3 iar-lab/fit.py <slot> <file>` on any of them to see this yourself.

Every shape is right. What is not right is resolution: the frames were generated
at 1024–1680px, which is ample on a phone and soft on a large desktop. Only the
jet frame and the lobby square clear the floor.

| file | shape | pixels |
|---|---|---|
| `jet-wide.jpg` | ok | **ok** 1664 × 936 |
| `03-lobby.jpg` | ok | **ok** 1254 × 1254 |
| `conv-wide.jpg` | ok | 1528 × 860 — just under |
| `02-newspaper.jpg` | ok | 1672 × 940 — under |
| `01-car.jpg` | ok | 1536 × 1024 — under |
| `city-wide.jpg` | ok | 1024 × 576 — **well** under |
| `conv-tall.jpg` | ok | 819 × 1024 — under |
| `city-tall.jpg` | ok | 989 × 1236 — under |
| `jet-tall.jpg` | ok | 749 × 936 — under |
| `ready-wide.jpg` | ok | 864 × 691 — under |
| `ready-tall.jpg` | ok | 864 × 1152 — under |

The tall crops cannot be improved by cropping differently: they are cut from
landscape originals, so their width is capped by the original's height. The only
fix is a higher-resolution regeneration of the campaign frames — ideally
**2560px on the long edge**, and ideally a portrait version of each as well, so
the phone crop is not carved out of a landscape frame.

The city frame is the worst of them at 1024 wide, and it is also the one with
the least headroom, because its original has the lettering set directly above
the model's head.
