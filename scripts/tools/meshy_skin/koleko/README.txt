Koleko is rebuilt from his Meshy model (dog_orig.glb, kept out of the repo) like this,
from scripts/tools/meshy_skin:
  python3 turn_head_quad.py koleko/dog.json dog_orig.glb turned.glb -26   # his head, modelled turned aside, faces forward
  python3 rig_quad.py koleko/dog_straight.json turned.glb rigged.glb      # dog.json with the head bones turned the same way
  python3 fix_skin.py rigged.glb ../../../models/koleko.glb --generic
