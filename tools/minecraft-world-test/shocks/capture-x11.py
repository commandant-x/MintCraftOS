#!/usr/bin/env python3
"""Capture an actual X11 Minecraft window near shocks; never render synthetic frames."""
import argparse
import json
import subprocess
import time
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--active', type=Path, required=True, help='run.py output/active-run.json')
p.add_argument('--server', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--display', default=':99')
p.add_argument('--size', default='1280x720')
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=True)
last = 0
try:
    while True:
        try:
            case = json.loads(a.active.read_text())['case']
            with (a.server / 'mintcraft-shock-test/flight.csv').open('rb') as f:
                f.seek(0, 2); f.seek(max(0, f.tell() - 4096))
                row = f.read().decode().splitlines()[-1].split(',')
            tick = int(row[0])
            if 740 <= tick <= 1050 and time.time() - last >= .45:
                last = time.time()
                name = f'{case}-tick{tick}-wall{int(last * 1000)}.png'
                start = time.time()
                proc = subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-f', 'x11grab',
                                       '-video_size', a.size, '-i', a.display, '-frames:v', '1',
                                       '-update', '1', str(a.output / name)],
                                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                record = dict(case=case, file=name, nearest_observed_server_tick=tick,
                              universe_tick=int(row[1]), capture_start_epoch=start,
                              capture_end_epoch=time.time(), exit_code=proc.returncode)
                with (a.output / 'index.jsonl').open('a') as f:
                    f.write(json.dumps(record) + '\n')
        except (OSError, ValueError, IndexError, KeyError):
            pass
        time.sleep(.08)
except KeyboardInterrupt:
    pass
