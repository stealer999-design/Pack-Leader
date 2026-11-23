#!/bin/bash
# Rigs one cat pet with the reference walk, its legs fitted the way Emberfox's were:
#   bash cat/build.sh <name> <meshy.glb> <first-config.json> <emberfox meshy.glb> <out.glb>
# (run from scripts/tools/meshy_skin). <first-config.json> is the cat's original fit
# (spine, head, tail, paws); cat/autofit.py writes pets/<name>.json from it, placing each
# leg joint, helper and muscle in proportion to Emberfox's (pets/emberfox.json).
set -e
name=$1; src=$2; first=$3; ember=$4; out=$5; tmp=$(mktemp -d)
python3 cat/autofit.py "$first" "$src" pets/$name.json "$ember"
python3 -I rig_quad.py pets/$name.json "$src" $tmp/a.glb
python3 dog/relax.py $tmp/a.glb "$out" 60  # (fix_skin.py cut notches where the thigh meets the belly)
python3 stretch.py "$out"
