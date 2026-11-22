#!/bin/bash
# Rigs and animates one dog pet from its Meshy model, with no stretching:
#   bash dog/build.sh <name> <meshy.glb> <out.glb>     (run from scripts/tools/meshy_skin)
# 1. autofit.py measures the model and writes pets/<name>.json (unless it exists)
# 2. rig_quad.py builds the skeleton, skin and the shared animations (dog_pet_anims.py)
# 3. cut_legs.py unhooks each leg from the others and from the chest/belly midline
#    (argument: the belly's height, from the config)
# 4. fix_skin.py --generic repairs points that still tear
# 5. relax.py blends the weights round any edge that still stretches, until none do
set -e
name=$1; src=$2; out=$3; tmp=$(mktemp -d)
[ -f pets/$name.json ] || { python3 dog/autofit.py "$src" pets/$name.json; sed -i 's|"lib": "quad_lib.py"|"lib": "../quad_lib.py"|; s|"anims": "dog_pet_anims.py"|"anims": "../dog/dog_pet_anims.py"|' pets/$name.json; }
python3 -I rig_quad.py pets/$name.json "$src" $tmp/a.glb
belly=$(python3 -c "import json; c=json.load(open('pets/$name.json')); print(min(l['top'] for l in c['legs']) - 0.02)")
python3 dog/cut_legs.py $tmp/a.glb $tmp/b.glb $belly
python3 fix_skin.py $tmp/b.glb $tmp/c.glb --generic
python3 dog/relax.py $tmp/c.glb "$out" 40
python3 stretch.py "$out"
