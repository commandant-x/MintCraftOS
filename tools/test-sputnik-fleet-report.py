#!/usr/bin/env python3
import csv
import importlib.util
import tempfile
import unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('fleet',Path(__file__).with_name('report-sputnik-fleet.py'))
fleet=importlib.util.module_from_spec(spec);spec.loader.exec_module(fleet)


class FleetReport(unittest.TestCase):
    def fixture(self,path,events,stale=False,reset=False):
        (path/'events.tsv').write_text(events)
        rows=[]
        for tick in range(320,801):
            rows.append(dict(tick=tick,universe_tick=tick+1000-(1 if stale and tick==700 else 0),x=0,y=100,z=0,
                             target_y=0 if reset and tick==800 else 100,active=0 if reset and tick==800 else 1,
                             pitch=0,yaw=0,roll=0,vx=0,vy=0,vz=0,protection=0))
        with (path/'flight.csv').open('w') as f:
            w=csv.DictWriter(f,fieldnames=rows[0]);w.writeheader();w.writerows(rows)

    def analyze(self,events,**kwargs):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder);self.fixture(path,events,**kwargs)
            return fleet.analyze(path,'tri')[0]

    def test_uncommissioned_flight_cannot_qualify(self):
        r=self.analyze('40\tBUILT tri\n320\tRELEASE: test\n')
        self.assertEqual(r['status'],'INVALID_COMMISSIONING')
        self.assertTrue(all(p['status']=='NOT_QUALIFIABLE' for p in r['phases']))

    def test_mechanical_refusal_is_not_a_controller_failure(self):
        r=self.analyze('40\tBUILT tri\n140\tCOMMISSION signal=10\n200\tERROR bad shaft\n')
        self.assertEqual(r['status'],'COMMISSIONING_FAILED')
        self.assertTrue(all(p['status']=='NOT_EXECUTED' for p in r['phases']))

    def test_preflight_refusal_does_not_invent_flight(self):
        r=self.analyze('40\tBUILT tri\n200\tCOMMISSION_PASS: test\n300\tERROR model refused\n')
        self.assertEqual(r['status'],'PREFLIGHT_REFUSED')
        self.assertFalse(r['released'])

    def test_one_good_hover_does_not_qualify_the_whole_architecture(self):
        r=self.analyze('40\tBUILT tri\n200\tCOMMISSION_PASS: test\n320\tRELEASE: test\n')
        self.assertEqual(r['phases'][0]['status'],'PASS')
        self.assertEqual(r['status'],'FAIL')
        self.assertFalse(r['controller_globally_qualified'])

    def test_stale_tail_cannot_pass(self):
        r=self.analyze('40\tBUILT tri\n200\tCOMMISSION_PASS: test\n320\tRELEASE: test\n',stale=True)
        self.assertEqual(r['phases'][0]['status'],'FAIL')

    def test_controller_cleared_target_is_not_a_new_zero_altitude(self):
        r=self.analyze('40\tBUILT tri\n200\tCOMMISSION_PASS: test\n320\tRELEASE: test\n800\tABORT: controller stopped\n',reset=True)
        self.assertEqual(r['status'],'ABORT')
        self.assertEqual(r['phases'][1]['peak_height_error_m'],0)

    def test_locked_gas_warmup_is_not_flight_or_controller_refusal(self):
        r=self.analyze('40\tBUILT tri\n200\tCOMMISSION_PASS: test\n300\tGAS_WARMUP force mismatch\n')
        self.assertEqual(r['status'],'WARMUP_NOT_VERIFIED')
        self.assertTrue(all(p['status']=='NOT_EXECUTED' for p in r['phases']))

    def test_unsupported_strafe_does_not_claim_a_successful_turn(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder);self.fixture(path,'40\tBUILT quad\n200\tCOMMISSION_PASS: test\n320\tRELEASE: test\n')
            with (path/'flight.csv').open() as f:rows=list(csv.DictReader(f))
            for row in rows:
                row['tick']=str(int(row['tick'])+2080);row['universe_tick']=str(int(row['universe_tick'])+2080)
            with (path/'flight.csv').open('w') as f:
                w=csv.DictWriter(f,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
            r=fleet.analyze(path,'quad-balanced')[0]
            phase=next(p for p in r['phases'] if p['name']=='left')
            self.assertEqual(phase['status'],'HOLD_ONLY_PASS')
            self.assertFalse(phase['requested_motion_supported'])
            self.assertIsNone(phase['intent_observed'])


if __name__=='__main__':unittest.main()
