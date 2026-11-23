#!/bin/bash
# Re-rigs one cat pet with proper hind legs (cat_fix.py: a real hip, stifle and
# hock with helper bones, and thigh/shoulder skin riding the legs), keeping the
# shared cat animations (dom/cat_anims.py):
#   bash cat/build.sh <name> <meshy.glb> <out.glb>     (run from scripts/tools/meshy_skin)
# pets/<name>.json must be the cat's original config (its first fit), ideally with its
# leg joints placed by hand first (check with cat/joints_plot.py; then FIX_ARGS="-1 -1 -1 0.13 1"
# keeps them); it is rewritten.
set -e
name=$1; src=$2; out=$3; tmp=$(mktemp -d)
python3 cat/cat_fix.py pets/$name.json "$src" pets/$name.json ${FIX_ARGS:-}
python3 -I rig_quad.py pets/$name.json "$src" $tmp/a.glb
python3 dog/relax.py $tmp/a.glb "$out" 60  # (fix_skin.py cut notches where the thigh meets the belly)
python3 stretch.py "$out"
