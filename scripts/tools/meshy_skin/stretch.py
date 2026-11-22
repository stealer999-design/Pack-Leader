import numpy as np, sys
sys.path.insert(0,'.')
from glb import *; from skin import *
j,bn=load(sys.argv[1]); r=Rig(j,bn)
p=j['meshes'][0]['primitives'][0]; a=p['attributes']
P=acc(j,bn,a['POSITION']).astype(float); J=acc(j,bn,a['JOINTS_0']).astype(int); W=acc(j,bn,a['WEIGHTS_0']).astype(float)
I=acc(j,bn,p['indices']).reshape(-1,3)
E=np.unique(np.sort(np.concatenate([I[:,[0,1]],I[:,[1,2]],I[:,[2,0]]]),1),axis=0)
L0=np.linalg.norm(P[E[:,0]]-P[E[:,1]],axis=1); out=[]
for n in (sys.argv[2:] or r.anims):
    worst=np.zeros(len(E))
    for k in range(16):
        X=r.skin(r.pose(n,r.length(n)*k/16),P,J,W); L1=np.linalg.norm(X[E[:,0]]-X[E[:,1]],axis=1)
        worst=np.maximum(worst,(L1-0.002)/(L0+0.002)); del X
    out.append((n,int((worst>2.5).sum())))
print(sys.argv[1],out)
