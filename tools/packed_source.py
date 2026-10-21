"""Deterministic bounded LZSS + ASCII85 for installed Lua source only."""
import base64
from collections import defaultdict, deque

CODEC = 'system/libraries/packed_source.lua'
PLAIN = {CODEC, 'boot.lua', 'startup.lua', 'system/boot/recovery.lua',
         'system/libraries/safe_write.lua', 'system/libraries/installer.lua'}
PREFIX = '-- MintCraft packed source 1\n'


def encode(data):
 hits=defaultdict(lambda:deque(maxlen=32));out=bytearray();i=0;n=len(data)
 while i<n:
  flag_at=len(out);out.append(0);flags=0
  for bit in range(8):
   if i>=n:break
   key=data[i:i+4]; best=0;offset=0
   for pos in reversed(hits[key]):
    distance=i-pos
    if distance>65535:break
    length=4
    while length<258 and i+length<n and data[pos+length]==data[i+length]:length+=1
    if length>best:best=length;offset=distance
   count=best if best>=4 else 1
   if best>=4:
    flags|=1<<bit;out.extend((offset//256,offset%256,best-3))
   else:out.append(data[i])
   for j in range(i,i+count):hits[data[j:j+4]].append(j)
   i+=count
  out[flag_at]=flags
 return base64.b85encode(out).decode()


def checksum(data):
    import zlib
    return '%08x' % zlib.adler32(data)


def pack(path, source):
    if path in PLAIN or not path.endswith('.lua'):
        return source
    data = source.encode('utf-8')
    result = (PREFIX + 'return assert(load(require("system.libraries.packed_source").decode([['
              + encode(data) + ']],' + str(len(data)) + ',"' + checksum(data)
              + '"),"@/' + path + '","t",_ENV))(...)\n')
    return result if len(result.encode('utf-8')) < len(data) else source
