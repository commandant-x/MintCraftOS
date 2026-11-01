#!/usr/bin/env python3
"""Generate separate, non-actuating Sputnik gait phase prototypes."""
from pathlib import Path
import importlib.util
root=Path(__file__).resolve().parents[4]
spec=importlib.util.spec_from_file_location('sputnik_build',root/'tools/build-sputnik.py')
import sys
sys.path.insert(0,str(root/'tools'))
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
out=Path(__file__).parent;template=(out/'gait-template.lua').read_text()
for name,n in [('bipede',2),('quadrupede',4)]:
 code=template.replace('__LEGS__',str(n))
 (out/(name+'.lua')).write_text(code)
 (out/(name+'.clipboard.txt')).write_text(b.clipboard('marche-'+name,code))
