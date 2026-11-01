#!/usr/bin/env python3
"""Regression checks: capture, stale clocks and latched protection cannot pass."""
import csv
import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('shock_report', Path(__file__).with_name('report-sputnik-shocks.py'))
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


class ShockReport(unittest.TestCase):
    def fixture(self, folder, protected=False, stale=False, abort=False):
        rows = []
        for tick in range(600, 1805):
            r = dict(tick=tick, universe_tick=tick + 10000, x=0, y=100, z=0,
                     pitch=0, yaw=0, roll=0, vx=0, vy=0, vz=0, target_y=100,
                     active=1, protection=int(protected and tick > 800))
            if stale and tick == 1700:
                r['universe_tick'] -= 1
            if tick == 801:
                r['vx'] = 5  # observed impulse, not merely an event label
            if tick >= 1800:
                r.update(active=0, y=999, target_y=0)  # fixture capture, excluded
            rows.append(r)
        with (folder / 'flight.csv').open('w') as f:
            w = csv.DictWriter(f, fieldnames=rows[0]); w.writeheader(); w.writerows(rows)
        (folder / 'events.tsv').write_text('800\tSHOCK side5 test\n' +
                                         ('1200\tABORT: fixture capture\n' if abort else '1800\tCOMPLETE: cleanup\n'))

    def score(self, **kwargs):
        with tempfile.TemporaryDirectory() as name:
            folder = Path(name); self.fixture(folder, **kwargs)
            return report.analyze(folder, 'side5')[0]

    def test_cleanup_does_not_spoil_flight_or_enter_peaks(self):
        r = self.score(); self.assertEqual(r['status'], 'PASS'); self.assertEqual(r['peak_height_error_m'], 0)

    def test_frozen_clock_cannot_qualify(self):
        self.assertEqual(self.score(stale=True)['status'], 'FAIL')

    def test_stable_but_protected_is_not_pass(self):
        self.assertEqual(self.score(protected=True)['status'], 'PROTECTED')

    def test_fixture_capture_cannot_count_as_recovery(self):
        self.assertEqual(self.score(abort=True)['status'], 'ABORT')

    def test_inverted_euler_branch_is_not_upright(self):
        self.assertAlmostEqual(report.tilt(dict(pitch=0, roll=180)), 180)
        self.assertAlmostEqual(report.tilt(dict(pitch=90, roll=0)), 90)

    def test_event_without_physical_response_is_not_pass(self):
        with tempfile.TemporaryDirectory() as name:
            folder = Path(name); self.fixture(folder)
            text = (folder / 'flight.csv').read_text().replace('5,0,0,100', '0,0,0,100')
            (folder / 'flight.csv').write_text(text)
            result = report.analyze(folder, 'side5')[0]
            self.assertFalse(result['disturbance_observed'])
            self.assertEqual(result['status'], 'FAIL')

    def test_incomplete_but_quiet_recording_cannot_pass(self):
        with tempfile.TemporaryDirectory() as name:
            folder = Path(name); self.fixture(folder)
            lines = (folder / 'flight.csv').read_text().splitlines()
            (folder / 'flight.csv').write_text('\n'.join(lines[:-5]) + '\n')
            (folder / 'events.tsv').write_text('800\tSHOCK side5 test\n')
            result = report.analyze(folder, 'side5')[0]
            self.assertTrue(result['tail_200_fresh_stable'])
            self.assertEqual(result['status'], 'FAIL')

    def test_moving_target_to_hide_height_error_cannot_pass(self):
        with tempfile.TemporaryDirectory() as name:
            folder = Path(name); self.fixture(folder)
            with (folder / 'flight.csv').open() as f:
                rows = list(csv.DictReader(f))
            for row in rows:
                if 1000 <= int(row['tick']) < 1800:
                    row['y'] = row['target_y'] = '101'
            with (folder / 'flight.csv').open('w') as f:
                w = csv.DictWriter(f, fieldnames=rows[0]); w.writeheader(); w.writerows(rows)
            result = report.analyze(folder, 'side5')[0]
            self.assertTrue(result['tail_200_fresh_stable'])
            self.assertFalse(result['target_preserved'])
            self.assertEqual(result['status'], 'FAIL')


if __name__ == '__main__':
    unittest.main()
