## Merges the animations of several Meshy exports (same mesh and skeleton) into
## one .glb: python3 merge_anims.py out.glb base.glb:Name [other.glb:Name ...]
import sys, json, struct
from glb import load
out=sys.argv[1]; specs=[a.rsplit(':',1) for a in sys.argv[2:]]
j,bn=load(specs[0][0]); bn=bytearray(bn)
names=[n.get('name') for n in j['nodes']]
j['animations'][0]['name']=specs[0][1]
del j['animations'][1:]
for path,name in specs[1:]:
    k,kb=load(path)
    assert [n.get('name') for n in k['nodes']]==names, path+': different node order'
    for a in k['animations'][:1]:
        amap={}
        def copy_acc(i):
            if i in amap: return amap[i]
            ac=dict(k['accessors'][i]); v=k['bufferViews'][ac['bufferView']]
            data=bytes(kb[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']])
            while len(bn)%4: bn.append(0)
            nv={'buffer':0,'byteOffset':len(bn),'byteLength':len(data)}
            if 'byteStride' in v: nv['byteStride']=v['byteStride']
            bn.extend(data); j['bufferViews'].append(nv)
            ac['bufferView']=len(j['bufferViews'])-1; j['accessors'].append(ac)
            amap[i]=len(j['accessors'])-1; return amap[i]
        samplers=[dict(s,input=copy_acc(s['input']),output=copy_acc(s['output'])) for s in a['samplers']]
        j['animations'].append({'name':name,'channels':a['channels'],'samplers':samplers})
while len(bn)%4: bn.append(0)
j['buffers'][0]['byteLength']=len(bn)
js=json.dumps(j,separators=(',',':')).encode(); js+=b' '*((4-len(js)%4)%4)
open(out,'wb').write(struct.pack('<III',0x46546C67,2,12+8+len(js)+8+len(bn))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(bn),0x004E4942)+bytes(bn))
print('animations',[a['name'] for a in j['animations']])
