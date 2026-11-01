#!/usr/bin/env python3
"""Run impulses in a disposable, loopback-only VENATOR server instance."""
import argparse
import hashlib
import json
import shutil
import subprocess
import time
from pathlib import Path

CASES = ['side5', 'side12', 'down8', 'up8', 'roll2', 'pitch2', 'combined', 'inversion']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--server', type=Path, required=True)
    p.add_argument('--original-world', type=Path, required=True)
    p.add_argument('--probe', type=Path, required=True)
    p.add_argument('--java-home', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--cases', nargs='+', choices=CASES, default=CASES)
    p.add_argument('--wait-for-viewer', action='store_true')
    p.add_argument('--screenshots', type=Path)
    p.add_argument('--timeout', type=int, default=420)
    a = p.parse_args()
    server, original, output = a.server.resolve(), a.original_world.resolve(), a.output.resolve()
    properties = dict(line.split('=', 1) for line in (server / 'server.properties').read_text().splitlines()
                      if '=' in line and not line.startswith('#'))
    if properties.get('server-ip') != '127.0.0.1' or properties.get('level-name') != 'world':
        raise ValueError('Disposable server must use server-ip=127.0.0.1 and level-name=world')
    if original == server / 'world' or server in original.parents or original in server.parents:
        raise ValueError('Keep the pristine source world separate from the disposable server')
    if output == original or original in output.parents:
        raise ValueError('Test output must not modify the pristine source world')
    if not (original / 'level.dat').is_file():
        raise ValueError('Original world missing level.dat')
    output.mkdir(parents=True, exist_ok=True)
    for case in a.cases:
        dest = output / case
        dest.mkdir(exist_ok=False)
        old = server / 'mintcraft-shock-test'
        if old.exists():
            raise ValueError('Collect previous fixture output before another run')
        if (server / 'world').exists():
            (server / 'world').rename(dest / 'previous-working-world')
        shutil.copytree(original, server / 'world')
        shutil.copy2(a.probe, server / 'mods/mintcraft-test-probe.jar')
        started = time.time()
        run = dict(case=case, start_utc_epoch=started, source_world_copy=True,
                   viewer=a.wait_for_viewer, fixture_sha256=digest(a.probe),
                   controller_sha256=digest(server / 'mintcraft-controller.lua'),
                   supervisor_sha256=digest(server / 'mintcraft-operations.lua'))
        (dest / 'run.json').write_text(json.dumps(run, indent=2))
        java = a.java_home / 'bin' / ('java.exe' if __import__('os').name == 'nt' else 'java')
        args_file = 'win_args.txt' if __import__('os').name == 'nt' else 'unix_args.txt'
        cmd = [str(java), '-Xms512m', '-Xmx3g', '-XX:ActiveProcessorCount=2',
               '-Dmintcraft.shock=' + case,
               '-Dmintcraft.waitForViewer=' + str(a.wait_for_viewer).lower(),
               '@libraries/net/neoforged/neoforge/21.1.264/' + args_file, 'nogui']
        timed_out = False
        with (dest / 'console.log').open('w') as log:
            proc = subprocess.Popen(cmd, cwd=server, stdin=subprocess.PIPE,
                                    stdout=log, stderr=subprocess.STDOUT, text=True)
            (output / 'active-run.json').write_text(json.dumps(dict(case=case, pid=proc.pid, start=started)))
            try:
                code = proc.wait(timeout=a.timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                try:
                    proc.stdin.write('stop\n')
                    proc.stdin.flush()
                except (BrokenPipeError, OSError):
                    pass
                try:
                    code = proc.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    proc.terminate()
                    try:
                        code = proc.wait(timeout=20)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                        code = proc.wait(timeout=10)
        if old.exists():
            shutil.move(str(old), dest / 'fixture')
        (dest / 'exit.json').write_text(json.dumps(dict(exit_code=code, wall_timeout=timed_out,
                                                       wall_seconds=time.time() - started), indent=2))
        if a.screenshots:
            shots = []
            for path in a.screenshots.glob('observer-*.png'):
                epoch = int(path.stem.split('-')[1]) / 1000
                if started <= epoch <= time.time():
                    shots.append(dict(file=path.name, epoch=epoch, bytes=path.stat().st_size))
            (dest / 'screenshots.json').write_text(json.dumps(sorted(shots, key=lambda s: s['epoch']), indent=2))
        print(case, 'process exit', code, 'timeout', timed_out, flush=True)


if __name__ == '__main__':
    main()
