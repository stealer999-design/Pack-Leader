## Repairs Meshy's auto-skinning on Rival Kael (see README): the bat, the hands
## resting on the thighs, then any point that still tears when posed.
import numpy as np, sys, json, struct, io
sys.path.insert(0,'.')
from glb import *; from skin import *
from PIL import Image
src,dst=sys.argv[1],sys.argv[2]
j,bn=load(src); rig=Rig(j,bn)
p=j['meshes'][0]['primitives'][0]; a=p['attributes']
P=acc(j,bn,a['POSITION']).astype(float); J0=acc(j,bn,a['JOINTS_0']).astype(int); W0=acc(j,bn,a['WEIGHTS_0']).astype(float)
I=acc(j,bn,p['indices']).reshape(-1,3).astype(np.int64); UV=acc(j,bn,a['TEXCOORD_0'])
NB=len(rig.joints); N=len(P)
D=np.zeros((N,NB))
for k in range(4): np.add.at(D,(np.arange(N),J0[:,k]),W0[:,k])
JP=np.array([np.linalg.inv(m)[:3,3] for m in rig.ibm])
ti=j['materials'][0]['pbrMetallicRoughness']['baseColorTexture']['index']
im=j['images'][j['textures'][ti]['source']]; v=j['bufferViews'][im['bufferView']]
A=np.asarray(Image.open(io.BytesIO(bytes(bn[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]))).convert('RGB')).astype(float)
h,w,_=A.shape
C=A[np.clip((UV[:,1]*h).astype(int),0,h-1),np.clip((UV[:,0]*w).astype(int),0,w-1)]
gr=C[:,1]/np.maximum(C[:,0],1)
skin=(C[:,0]>100)&(gr>0.66)&(gr<0.86)
jeans=(C.max(1)<100)&(gr>0.82)
def seg_d(p,a,b):
    ab=b-a; t=np.clip(((p-a)@ab)/(ab@ab),0,1); return np.linalg.norm(p-(a+t[:,None]*ab),axis=1)
LARM=[8,9,10,11]; RARM=[12,13,14,15]
GENERIC = len(sys.argv) > 3 and sys.argv[3] == "--generic"
if not GENERIC:
    # 1) the bat belongs to the right hand
    Ab=np.array([-0.215,0.86,-0.11]); Bb=np.array([-0.385,0.34,0.175]); K=np.array([-0.2,0.955,-0.15])
    Dleg=np.min([seg_d(P,JP[x],JP[y]) for x,y in [(20,21),(21,22),(22,23)]],0)
    bat=(seg_d(P,Ab,Bb)<0.055)&(P[:,1]<0.86)&(Dleg>0.07)
    bat|=(seg_d(P,K,Bb)<0.06)&~jeans&(P[:,1]<0.99)&~skin
    # 2) below the shoulders only skin (hands, forearms) follows the arms
    for ids,sg in [(LARM,1),(RARM,-1)]:
        region=(P[:,1]<1.2)&(np.sign(P[:,0])==sg)&~bat
        arm=region&skin&(P[:,1]>0.7)
        other=[b for b in range(NB) if b not in ids]
        D[np.ix_(arm,other)]=0
        D[np.ix_(region&~arm,ids)]=0
    D[bat]=0; D[bat,15]=1
# welded neighbours
_,wid=np.unique(np.round(P,5),axis=0,return_inverse=True); wid=wid.ravel(); nW=wid.max()+1
E=np.unique(np.sort(np.concatenate([I[:,[0,1]],I[:,[1,2]],I[:,[2,0]]]),1),axis=0)
EW=np.unique(np.sort(wid[E],1),axis=0); EW=EW[EW[:,0]!=EW[:,1]]
rep=np.zeros(nW,int); rep[wid]=np.arange(N)
PW=P[rep]
def weld_avg(D):
    S=np.zeros((nW,NB)); c=np.zeros(nW); np.add.at(S,wid,D); np.add.at(c,wid,1); return S/c[:,None]
DW=weld_avg(D)
def fix_empty(DW):
    e=DW.sum(1)<1e-6
    for i in np.where(e)[0]:
        order=np.argsort(np.linalg.norm(JP-PW[i],axis=1)); DW[i,order[0]]=1
    return DW
DW=fix_empty(DW)
frames=[(n,rig.length(n)*k/14) for n in rig.anims for k in range(14)]
mats=[rig.pose(n,t) for n,t in frames]
L0=np.linalg.norm(PW[EW[:,0]]-PW[EW[:,1]],axis=1)
def top4(DW):
    Jn=np.argsort(-DW,1)[:,:4]; Wn=np.take_along_axis(DW,Jn,1); Wn/=np.maximum(Wn.sum(1,keepdims=True),1e-9); return Jn,Wn
def stretch(DW):
    Jn,Wn=top4(DW); worst=np.zeros(len(EW))
    for M in mats:
        X=rig.skin(M,PW,Jn,Wn); L1=np.linalg.norm(X[EW[:,0]]-X[EW[:,1]],axis=1)
        worst=np.maximum(worst,(L1-0.004)/(L0+0.004))
    return worst
for it in range(12):
    s=stretch(DW); bad=s>1.7
    deg=np.zeros(nW); nb=np.zeros(nW)
    np.add.at(deg,EW.ravel(),1); np.add.at(nb,EW[bad].ravel(),1)
    frac=nb/np.maximum(deg,1)
    print('pass',it,'stretched edges',bad.sum(),'bad points',(frac>=0.5).sum())
    badv=frac>=0.5
    if badv.sum()==0: break
    # replace bad points' weights with the mean of their good neighbours
    S=np.zeros((nW,NB)); c=np.zeros(nW)
    good=~badv
    for x,y in [(0,1),(1,0)]:
        m=good[EW[:,y]]
        np.add.at(S,EW[m,x],DW[EW[m,y]]); np.add.at(c,EW[m,x],1)
    upd=badv&(c>0)
    DW[upd]=S[upd]/c[upd,None]
    # isolated clumps with no good neighbour: plain neighbour mean
    left=badv&(c==0)
    if left.any():
        S2=np.zeros((nW,NB)); c2=np.zeros(nW)
        for x,y in [(0,1),(1,0)]: np.add.at(S2,EW[:,x],DW[EW[:,y]]); np.add.at(c2,EW[:,x],1)
        DW[left]=S2[left]/np.maximum(c2[left,None],1)
# 3) triangles that still tear (fused hand/thigh contact): cut them
s=stretch(DW)
emap={tuple(e):k for k,e in enumerate(EW)}
tw=wid[I]
def es(a,b):
    k=emap.get((min(a,b),max(a,b))); return s[k] if k is not None else 0
torn=np.array([max(es(t[0],t[1]),es(t[1],t[2]),es(t[2],t[0]))>2.5 for t in tw])
print('triangles cut',torn.sum(),'of',len(I))
Jn,Wn=top4(DW)
J=Jn[wid].astype(np.uint8); W=Wn[wid].astype(np.float32)
def put(i,arr):
    ac=j['accessors'][i]; v=j['bufferViews'][ac['bufferView']]; off=v.get('byteOffset',0)+ac.get('byteOffset',0)
    b=arr.tobytes(); bn[off:off+len(b)]=b
put(a['WEIGHTS_0'],W); put(a['JOINTS_0'],J)
keep=I[~torn].ravel().astype(acc(j,bn,p['indices']).dtype)
put(p['indices'],keep); j['accessors'][p['indices']]['count']=int(len(keep))
js=json.dumps(j,separators=(',',':')).encode(); js+=b' '*((4-len(js)%4)%4)
binp=bytes(bn)+b'\0'*((4-len(bn)%4)%4)
out=struct.pack('<III',0x46546C67,2,12+8+len(js)+8+len(binp))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(binp),0x004E4942)+binp
open(dst,'wb').write(out)
