#!/usr/bin/env python3
import csv,importlib.util,tempfile,unittest
from pathlib import Path
here=Path(__file__).parent;spec=importlib.util.spec_from_file_location('spot_check',here/'check_transmission.py');check=importlib.util.module_from_spec(spec);spec.loader.exec_module(check)
root=Path(__file__).resolve().parents[3];source=root/'platforms/sputnik/experiments/spot-one-motor/measurements.csv'
class EvidenceTest(unittest.TestCase):
 def setUp(self):
  with source.open(newline='') as f:self.rows=list(csv.DictReader(f))
 def evaluate(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'evidence.csv'
   with p.open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=self.rows[0]);w.writeheader();w.writerows(self.rows)
   return check.check(p)
 def test_observed(self):self.assertTrue(self.evaluate()['branch_isolation'])
 def test_missing_phase(self):
  self.rows.pop(2)
  with self.assertRaises(ValueError):self.evaluate()
 def test_cross_coupling(self):
  self.rows[1]['branch3_rpm']='0'
  with self.assertRaises(ValueError):self.evaluate()
 def test_dead_source(self):
  self.rows[2]['source_rpm']='0'
  with self.assertRaises(ValueError):self.evaluate()
 def test_not_finite(self):
  self.rows[3]['branch1_rpm']='nan'
  with self.assertRaises(ValueError):self.evaluate()
if __name__=='__main__':unittest.main()
