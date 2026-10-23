#!/usr/bin/env python3
"""Create a self-contained decoder probe for the actual bundled Cobalt interpreter."""
from pathlib import Path
import sys
root = Path(__file__).resolve().parent.parent
helper = (root / 'system/libraries/packed_source_v2.lua').read_text()
cases = (root / 'tests/fixtures/packed-v2.lua').read_text()
alphabet = bytes(c for c in range(1, 127) if c not in (9, 10, 11, 12, 13, 27, 91, 93)).decode('ascii')
probe = ('local codec=(function()\n' + helper + '\nend)()\n'
         'local cases=(function()\n' + cases + '\nend)()\n'
         'local alphabet=[[' + alphabet + ']] assert(#alphabet==118)\n'
         'for _,r in ipairs(cases) do assert(codec.decode(r.encoded,#r.source,r.digest)==r.source) end\n'
         'local env=setmetatable({require=function() return codec end},{__index=_G})\n'
         'local fn=assert(load(cases[3].wrapper,"fixture","t",env))\n'
         'local a,b=fn(41) assert(a==42 and b=="value")\n')
if len(sys.argv) > 2:
    runtime = Path(sys.argv[2])
    def literal(text):
        delimiter = '='
        while ']' + delimiter + ']' in text:
            delimiter += '='
        return '[' + delimiter + '[\n' + text + ']' + delimiter + ']'
    paths = [p.relative_to(runtime) for folder in ('system', 'apps')
             for p in (runtime / folder).rglob('*.lua')]
    paths += [Path('boot.lua'), Path('startup.lua')]
    probe += 'local modules={\n'
    for path in paths:
        original = (root / path).read_bytes().decode('utf-8').replace('\r\n', '\n')
        encoded = (runtime / path).read_text()
        probe += '{expected=' + literal(original) + ',encoded=' + literal(encoded) + '},\n'
    probe += '}\nfor _,m in ipairs(modules) do local decoded=codec.unpack(m.encoded) assert(decoded==m.expected) assert(load(decoded,"runtime-module","t",{})) end\n'
probe += 'return #cases\n'
Path(sys.argv[1]).write_text(probe)
