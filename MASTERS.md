# The master frames

Every one of the 25 cloths derives from these five photographs. Nothing is shot
from a written description any more — a prompt describes a shot, only an image
*is* the shot. Deriving means: reproduce the master frame for frame, change the
shirt's colour, change nothing else.

This makes the model, the pose, the light and the wall **identical** across the
range rather than merely consistent. There is nothing left to drift.

| frame | master taken from | Higgsfield media id |
|---|---|---|
| `1-hero`   | Ratan's Blue | `bdf61ae8-bc85-4ac4-9890-acf2e6cb0e63` |
| `2-back`   | Ratan's Blue | `4f530b12-58ac-4e6f-b94c-e9f44b484172` |
| `3-collar` | Indigo Oak   | `84cc99bd-5ccc-453d-93a7-ae3d0726f46e` |
| `4-cuff`   | Indigo Oak   | `5719dafb-9599-4246-b788-ca3dfb591bde` |
| `5-button` | Indigo Oak   | `69fde88d-20f7-4cde-a9fe-ad43ef9b6094` |

## Why these five

**Hero and back come from Ratan's Blue** because that frame has the best face —
matte skin with natural texture, the beard reading properly. The Indigo Oak hero
carries a hard specular across the brow (the "oily" one), and the Cobalt Charm
hero drifted to a visibly different man. The pose is the same in all three, so
taking Ratan's Blue costs nothing and fixes the face. Both come from the same
frame's room, so their wall matches.

**Collar, cuff and button come from Indigo Oak.** The collar has clean even
light with nothing cast on the cloth. The cuff is the one the client locked
explicitly. The button is the only frame where the engraving renders correctly
spelled.

## Supporting references

| | |
|---|---|
| The model, original | `87ad9f7d-88e1-443d-bc16-4be40c383a37` |
| The real cuff, client photograph | `f4ea61ec-d51d-4386-9f05-5bed39d85f7a` |

These are no longer needed for derivation — the masters already contain the man
and the construction — but they remain the authority if a master is ever reshot.

## Per-cloth inputs

Each cloth needs only its own product photograph uploaded, to drive the colour
and the button colour. Colour comes from the **photograph**, not from the
`catalogue.js` palette; the two disagree materially on at least two cloths
(Indigo Oak `#4A5570` vs `#3D3C43`, Cobalt Charm `#3E5A8C` vs `#2B3B59`) and
this is still open with the client.

## Cost

5 generations per cloth, plus a colour grade and, on the cuff, the signature
composite. Roughly one Higgsfield job in ten comes back `failed` and needs a
re-fire — budget for it.
