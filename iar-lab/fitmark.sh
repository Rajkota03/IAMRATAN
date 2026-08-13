#!/usr/bin/env bash
# Fit a generated logo clip to the mark's own geometry.
#
# Generated clips frame the logo loosely inside whatever canvas the model used,
# so the logo lands smaller than the CSS mask mark it hands over to — and the
# crossfade at the end of the walk-in visibly jumped in scale.
#
# This measures the ink in the clip's LAST frame (which is the resting pose),
# expands that box to the mark's 1430:620, crops to it and rescales. After it,
# the clip's logo fills its frame to within a per-cent of what the mask does,
# so the handover is invisible.
#
#   ./iar-lab/fitmark.sh in.mp4 out.mp4

set -euo pipefail
IN="$1"; OUT="$2"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

ffmpeg -hide_banner -loglevel error -sseof -0.1 -i "$IN" -frames:v 1 "$TMP/last.png" -y

CROP=$(python3 - "$TMP/last.png" <<'PY'
import sys
from PIL import Image
import numpy as np
im=Image.open(sys.argv[1]).convert('L'); W,H=im.size
ys,xs=np.nonzero(np.asarray(im,float)<128)          # dark ink on bone
x0,x1,y0,y1=xs.min(),xs.max(),ys.min(),ys.max()
T=1430/620
w,h=x1-x0,y1-y0
if w/h < T: w=h*T
else:       h=w/T
cx,cy=(x0+x1)/2,(y0+y1)/2
cw=int(round(w/2))*2; ch=int(round(h/2))*2
cw=min(cw,W-(W%2)); ch=min(ch,H-(H%2))
print('%d:%d:%d:%d'%(cw,ch,
  max(0,min(W-cw,int(round(cx-cw/2)))),
  max(0,min(H-ch,int(round(cy-ch/2))))))
PY
)

ffmpeg -hide_banner -loglevel error -i "$IN" \
  -vf "crop=$CROP,scale=1144:496:flags=lanczos" \
  -an -c:v libx264 -crf 25 -pix_fmt yuv420p -movflags +faststart "$OUT" -y

echo "$(basename "$OUT")  crop=$CROP  $(du -h "$OUT" | cut -f1)"
