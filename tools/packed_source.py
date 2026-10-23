"""Deterministic LZSS + compact ASCII; retain the legacy ASCII85 encoder."""
import base64
from collections import defaultdict, deque

CODEC = 'system/libraries/packed_source.lua'
PLAIN = {CODEC, 'boot.lua', 'startup.lua', 'system/boot/recovery.lua',
         'system/libraries/safe_write.lua', 'system/libraries/installer.lua',
         'system/libraries/packed_source_v2.lua', 'system/libraries/packed_source_v3.lua', 'system/libraries/installer_v2.lua'}
PREFIX = '-- MintCraft packed source 3\n'


def encode(data, hit_limit=32):
 hits=defaultdict(lambda:deque(maxlen=hit_limit));out=bytearray();i=0;n=len(data)
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


def compact_ascii(raw):
    # 118 ASCII symbols, no NUL, whitespace controls, ESC, DEL or brackets.
    alphabet = bytes(c for c in range(1, 127) if c not in (9, 10, 11, 12, 13, 27, 91, 93))
    out = bytearray()
    for i in range(0, len(raw), 6):
        block = raw[i:i + 6]
        value = int.from_bytes(block, 'big')
        digits = []
        for _ in range(len(block) + 1):
            digits.append(alphabet[value % 118])
            value //= 118
        assert value == 0
        out.extend(reversed(digits))
    return out.decode('ascii')


def checksum(data):
    import zlib
    return '%08x' % zlib.adler32(data)


def pack(path, source):
    if path in PLAIN or not path.endswith('.lua'):
        return source
    data = source.encode('utf-8')
    import zlib
    compressor = zlib.compressobj(9, wbits=-15)
    raw = compressor.compress(data) + compressor.flush()
    result = (PREFIX + 'return assert(load(require("system.libraries.packed_source_v3").decode([['
              + compact_ascii(raw) + ']],' + str(len(data)) + ',"' + checksum(data)
              + '"),"@/' + path + '","t",_ENV))(...)\n')
    return result if len(result.encode('utf-8')) < len(data) else source
