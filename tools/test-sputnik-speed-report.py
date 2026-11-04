#!/usr/bin/env python3
"""Reject fabricated, stale or assisted stable windows in the independent audit."""
import importlib.util,unittest,copy
from pathlib import Path
spec=importlib.util.spec_from_file_location('speed',Path(__file__).with_name('report-sputnik-speed.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class AuditTest(unittest.TestCase):
 def setUp(self):
  self.rows={t:dict(tick=t,universe_tick=t,active=1.,protection=0.,staff_locked=0.,observed_mass=100.,pitch=0.,roll=0.,vx=0.,vy=0.,vz=2.,target_y=170.,y=170.,x=0.,z=t*.1) for t in range(1,101)}
  self.stage=dict(window_first_tick=1,window_last_tick=100,window_samples=100,window_mean_m_s=2.,window_first_universe_tick=1,window_last_universe_tick=100)
 def check(self):return m.audit(self.rows,self.stage,dict(vertical=0,angle=0),0)
 def test_valid(self):self.assertEqual(self.check(),2.)
 def test_peak(self):
  self.rows[50]['vz']=3.
  with self.assertRaises(AssertionError):self.check()
 def test_stale(self):
  self.rows[50]['universe_tick']=49
  with self.assertRaises(AssertionError):self.check()
 def test_lock(self):
  self.rows[50]['staff_locked']=1.
  with self.assertRaises(AssertionError):self.check()
 def test_missing(self):
  del self.rows[50]
  with self.assertRaises(KeyError):self.check()
 def test_reported_mean(self):
  self.stage['window_mean_m_s']=20.
  with self.assertRaises(AssertionError):self.check()
if __name__=='__main__':unittest.main()
