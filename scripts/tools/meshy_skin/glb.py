import json,struct,numpy as np
def load(path):
    b=open(path,'rb').read(); l=struct.unpack('<I',b[12:16])[0]; j=json.loads(b[20:20+l]); bin_=bytearray(b[20+l+8:])
    return j,bin_
def acc(j,bin_,i,copy=True):
    a=j['accessors'][i]; v=j['bufferViews'][a['bufferView']]
    n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    dt={5126:np.float32,5123:np.uint16,5125:np.uint32,5121:np.uint8}[a['componentType']]
    off=v.get('byteOffset',0)+a.get('byteOffset',0)
    arr=np.frombuffer(bytes(bin_),dtype=dt,count=a['count']*n,offset=off)
    return arr.reshape(a['count'],n) if n>1 else arr
