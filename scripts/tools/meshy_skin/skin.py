import numpy as np
from glb import *
def q2m(q):
    x,y,z,w=q
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
def trs(t,r,s):
    M=np.eye(4); M[:3,:3]=q2m(r)*np.array(s)[None,:]; M[:3,3]=t; return M
class Rig:
    def __init__(s,j,bn):
        s.j=j; s.bn=bn
        s.parent={}
        for i,n in enumerate(j['nodes']):
            for c in n.get('children',[]): s.parent[c]=i
        sk=j['skins'][0]; s.joints=sk['joints']
        s.ibm=acc(j,bn,sk['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
        s.anims={}
        for a in j['animations']:
            ch=[]
            for c in a['channels']:
                smp=a['samplers'][c['sampler']]
                ch.append((c['target']['node'],c['target']['path'],acc(j,bn,smp['input']),acc(j,bn,smp['output'])))
            s.anims[a['name']]=ch
    def length(s,name): return max(c[2].max() for c in s.anims[name])
    def pose(s,name,t):
        loc={i:[np.array(n.get('translation',[0,0,0]),float),np.array(n.get('rotation',[0,0,0,1]),float),np.array(n.get('scale',[1,1,1]),float)] for i,n in enumerate(s.j['nodes'])}
        for node,path,T,V in s.anims[name]:
            k=np.searchsorted(T,t)
            if k<=0: v=V[0]
            elif k>=len(T): v=V[-1]
            else:
                f=(t-T[k-1])/(T[k]-T[k-1]); v=V[k-1]*(1-f)+V[k]*f
                if path=='rotation':
                    a,b=V[k-1],V[k]
                    if np.dot(a,b)<0: b=-b
                    v=a*(1-f)+b*f; v/=np.linalg.norm(v)
            loc[node][{'translation':0,'rotation':1,'scale':2}[path]]=np.array(v,float)
        G={}
        def g(i):
            if i in G: return G[i]
            M=trs(*loc[i]); 
            if i in s.parent: M=g(s.parent[i])@M
            G[i]=M; return M
        return np.array([g(i)@s.ibm[k] for k,i in enumerate(s.joints)])
    def skin(s,mats,P,J,W):
        Ph=np.c_[P,np.ones(len(P))]
        out=np.zeros((len(P),3))
        for k in range(4):
            out+=W[:,k:k+1]*np.einsum('nij,nj->ni',mats[J[:,k]],Ph)[:,:3]
        return out
