#!/usr/bin/env python3
"""Build and test native fleet variants in a disposable VENATOR server copy."""
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

CASES = ['tri', 'quad', 'hex', 'octo', 'quad-banks', 'quad-balanced', 'quad-turns', 'balloon', 'balloon-lift']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--server', type=Path, required=True)
    source = p.add_mutually_exclusive_group(required=True)
    source.add_argument('--original-world', type=Path)
    source.add_argument('--graph-template', type=Path,
                        help='Production clipboard; generate a new world instead of copying a private save')
    p.add_argument('--probe', type=Path, required=True)
    p.add_argument('--java-home', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--architectures', nargs='+', choices=CASES, default=CASES)
    p.add_argument('--controller-for', action='append', default=[], metavar='CASE=LUA',
                   help='Explicit production/candidate controller for one architecture; archived and hashed')
    p.add_argument('--speed', action='store_true', help='Measure native sustained-speed envelopes instead of the fixed movement sequence')
    p.add_argument('--speed-directions', nargs='+', choices=['forward','reverse','left','right','forward_left','forward_right','reverse_left','reverse_right','up','down'])
    p.add_argument('--wait-for-viewer', action='store_true')
    p.add_argument('--screenshots', type=Path)
    p.add_argument('--timeout', type=int, default=900)
    a = p.parse_args()
    server, output = a.server.resolve(), a.output.resolve()
    original = a.original_world.resolve() if a.original_world else None
    template = a.graph_template.resolve() if a.graph_template else None
    controllers = {}
    for value in a.controller_for:
        case, separator, path = value.partition('=')
        controller = Path(path).resolve()
        if not separator or case not in CASES or case in controllers or not controller.is_file():
            p.error('--controller-for requires a unique supported CASE and an existing Lua file')
        controllers[case] = controller
    if output == server or server in output.parents:
        raise ValueError('Keep campaign output outside the disposable server')
    if template and (template == server / 'world' or server / 'world' in template.parents):
        raise ValueError('Keep the graph template outside the world moved between cases')
    properties = dict(line.split('=', 1) for line in (server / 'server.properties').read_text().splitlines()
                      if '=' in line and not line.startswith('#'))
    if properties.get('server-ip') != '127.0.0.1' or properties.get('level-name') != 'world':
        raise ValueError('Disposable server must use server-ip=127.0.0.1 and level-name=world')
    if original and (original == server / 'world' or server in original.parents or original in server.parents):
        raise ValueError('Keep the pristine source world separate from the disposable server')
    if original and (output == original or original in output.parents):
        raise ValueError('Test output must not modify the pristine source world')
    if original and not (original / 'level.dat').is_file():
        raise ValueError('Original world missing level.dat')
    if template and not template.is_file():
        raise ValueError('Production graph template missing')
    output.mkdir(parents=True, exist_ok=True)
    failed = []
    for case in a.architectures:
        dest = output / case
        dest.mkdir(exist_ok=False)
        old = server / 'mintcraft-fleet-test'
        if old.exists():
            raise ValueError('Collect previous fixture output before another run')
        if (server / 'world').exists():
            (server / 'world').rename(dest / 'previous-working-world')
        if original:
            shutil.copytree(original, server / 'world')
        if case in controllers:
            shutil.copy2(controllers[case], server / 'mintcraft-generic-controller.lua')
        shutil.copy2(a.probe, server / 'mods/mintcraft-test-probe.jar')
        # Keep exactly what this JVM will load, even if development continues
        # while a multi-case campaign is running.
        for name in ('mintcraft-generic-controller.lua', 'mintcraft-generic-setup.lua', 'mintcraft-operations.lua'):
            shutil.copy2(server / name, dest / name)
        case_template = None
        if template:
            case_template = dest / 'template.clipboard.txt'
            shutil.copy2(template, case_template)
        started = time.time()
        run = dict(case=case, start_utc_epoch=started, speed_campaign=a.speed, source_world_copy=bool(original),
                   viewer=a.wait_for_viewer, fixture_sha256=digest(a.probe),
                   controller_sha256=digest(server / 'mintcraft-generic-controller.lua'),
                   supervisor_sha256=digest(server / 'mintcraft-operations.lua'))
        if template:
            run['graph_template_sha256'] = digest(case_template)
        (dest / 'run.json').write_text(json.dumps(run, indent=2))
        java = a.java_home / 'bin' / ('java.exe' if __import__('os').name == 'nt' else 'java')
        args_file = 'win_args.txt' if __import__('os').name == 'nt' else 'unix_args.txt'
        cmd = [str(java), '-Xms512m', '-Xmx3g', '-XX:ActiveProcessorCount=2',
               '-Dmintcraft.fleet=' + case,
               '-Dmintcraft.waitForViewer=' + str(a.wait_for_viewer).lower(),
               '@libraries/net/neoforged/neoforge/21.1.264/' + args_file, 'nogui']
        if template:
            cmd.insert(4, '-Dmintcraft.graphTemplate=' + str(case_template))
        if a.speed:
            cmd.insert(4, '-Dmintcraft.speed=true')
            if a.speed_directions:
                cmd.insert(4, '-Dmintcraft.speedDirections=' + ','.join(a.speed_directions))
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
        events_path = dest / 'fixture/events.tsv'
        events = events_path.read_text() if events_path.exists() else ''
        # The fixture deliberately halts Minecraft even on an exception; JVM
        # exit 0 alone is therefore not evidence that a flight ran/completed.
        executed = '\tRELEASE:' in events
        completed = '\tCOMPLETE:' in events and '\tEXPORT:' in events
        if a.speed:
            summary = dest / 'fixture/speed-results.json'
            completed = summary.exists() and json.loads(summary.read_text()).get('complete') is True
        fixture_error = (dest / 'fixture/error.txt').exists()
        if timed_out or code != 0 or fixture_error or not completed:
            failed.append(case)
        (dest / 'exit.json').write_text(json.dumps(dict(exit_code=code, wall_timeout=timed_out,
                                                       wall_seconds=time.time() - started,
                                                       flight_executed=executed, sequence_completed=completed,
                                                       fixture_error=fixture_error), indent=2))
        if a.screenshots:
            shots = []
            for path in a.screenshots.glob('observer-*.png'):
                epoch = int(path.stem.split('-')[1]) / 1000
                if started <= epoch <= time.time():
                    shots.append(dict(file=path.name, epoch=epoch, bytes=path.stat().st_size))
            (dest / 'screenshots.json').write_text(json.dumps(sorted(shots, key=lambda s: s['epoch']), indent=2))
        print(case, 'process exit', code, 'timeout', timed_out, flush=True)
    if failed:
        print('Incomplete or failed fixture cases: ' + ', '.join(failed), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
