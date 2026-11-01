#!/usr/bin/env python3
import csv,importlib.util,tempfile,unittest
from pathlib import Path
here=Path(__file__).parent;spec=importlib.util.spec_from_file_location('linkage',here/'analyze.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
source=Path('platforms/sputnik/experiments/spot-three-axis/straight-link/trace.csv')
class Tests(unittest.TestCase):
 def setUp(self):
  with source.open(newline='') as f:self.rows=list(csv.DictReader(f))
 def eval(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'trace.csv'
   with p.open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=self.rows[0]);w.writeheader();w.writerows(self.rows)
   return m.analyze(p)
 def test_return_verified(self):self.assertTrue(self.eval()['return_motion_observed'])
 def test_failed_return_stays_failure(self):
  for r in self.rows:
   if r['phase']=='released_off':r['target_tenths']='50'
  self.assertFalse(self.eval()['return_target_changed']);self.assertFalse(self.eval()['return_observed_and_stable'])
 def test_missing_phase_rejected(self):
  self.rows=[r for r in self.rows if r['phase']!='released_off']
  with self.assertRaises(ValueError):self.eval()
 def test_locked_observation_rejected(self):
  next(r for r in self.rows if r['phase']=='released_on')['locked']='true'
  with self.assertRaises(ValueError):self.eval()
 def test_invalid_signal_rejected(self):
  next(r for r in self.rows if r['phase']=='released_off')['signal']='15'
  with self.assertRaises(ValueError):self.eval()
if __name__=='__main__':unittest.main()
