#!/usr/bin/env python3
"""Compare simulated Link output traces before/after the Cobalt capture refactor.

The legacy reference intentionally runs under native Lua 5.2, which accepts its
69 captures. Production compatibility is separately checked with real Cobalt.
"""
from pathlib import Path
import argparse
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--lua', default='lua5.2')
parser.add_argument('--previous-installer', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent

def literal(text):
    delimiter = '='
    while ']' + delimiter + ']' in text:
        delimiter += '='
    return '[' + delimiter + '[\n' + text + ']' + delimiter + ']'

with tempfile.TemporaryDirectory(prefix='mintcraft-flight-trace-') as temporary:
    temporary = Path(temporary)
    extract = temporary / 'extract.lua'
    extract.write_text('''package.path='./?.lua;'..package.path
local captured
assert(loadfile(arg[1],'t',{assert=assert,print=function() end,load=function()
 return function() return {install=function(files) captured=files end} end
end}))()
local source=require('system.libraries.packed_source').unpack(captured['system/services/flightd.lua'])
local out=assert(io.open(arg[2],'wb')) out:write(source) out:close()
''')
    original = temporary / 'original.lua'
    subprocess.run([args.lua, str(extract), str(Path(args.previous_installer).resolve()), str(original)], cwd=root, check=True)
    harness = (root / 'tests/altitude-sweep-flight.lua').read_text()
    needle = 'sendLinkSignal=function(first,_,value)\n'
    assert harness.count(needle) == 1
    traces = []
    for name, controller in [('original', original.read_text()), ('refactored', (root / 'system/services/flightd.lua').read_text())]:
        source = "local physical_trace=assert(io.open(arg[1],'wb'))\n" + harness
        source = source.replace(needle, needle + " physical_trace:write(first,'\\t',tostring(value),'\\n')\n", 1)
        source = source.replace('local flight=require("system.services.flightd")',
                                'local flight=assert(load(' + literal(controller) + ',"@' + name + '-flightd","t",_ENV))()\npackage.loaded["system.services.flightd"]=flight', 1)
        if name == 'original':
            source = '\n'.join(line for line in source.split('\n') if 'debug.getinfo(flight.step' not in line)
        source += '\nphysical_trace:close()\n'
        script, trace = temporary / (name + '.lua'), temporary / (name + '.trace')
        script.write_text(source)
        result = subprocess.run([args.lua, str(script), str(trace)], cwd=root, capture_output=True, text=True, timeout=300)
        if result.returncode:
            raise RuntimeError(name + ': ' + result.stdout[-2000:] + result.stderr[-2000:])
        traces.append(trace.read_bytes())
    assert traces[0] == traces[1], 'Simulated physical Link command sequences changed'
    print('Exact simulated Link trace preserved:', len(traces[0].splitlines()), 'writes; sweep, motors, mass adaptation and STOP scenarios passed')
