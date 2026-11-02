#!/usr/bin/env python3
import csv,importlib.util,tempfile,unittest
from pathlib import Path
here=Path(__file__).parent;spec=importlib.util.spec_from_file_location('audit',here/'analyze.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
source=Path('platforms/sputnik/experiments/spot-universal-transmission/axial/trace.csv')
class AuditTest(unittest.TestCase):
 def setUp(self):
  with source.open(newline='') as f:self.rows=list(csv.DictReader(f))
 def audit(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'trace.csv'
   with p.open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=self.rows[0]);w.writeheader();w.writerows(self.rows)
   return m.audit(p)
 def test_actual(self):self.assertAlmostEqual(self.audit()['measured_axial_extension'],1)
 def test_missing(self):
  self.rows.pop(1)
  with self.assertRaises(ValueError):self.audit()
 def test_lost_transmission(self):
  self.rows[1]['shaft_rpm']='0'
  with self.assertRaises(ValueError):self.audit()
 def test_false_geometry(self):
  self.rows[1]['endpoint_distance']='3'
  with self.assertRaises(ValueError):self.audit()
 def test_nonfinite(self):
  self.rows[0]['target_joint_rpm']='nan'
  with self.assertRaises(ValueError):self.audit()
if __name__=='__main__':unittest.main()
