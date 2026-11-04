#!/usr/bin/env python3
from pathlib import Path
import importlib.util,sys
root=Path(__file__).resolve().parents[5];here=Path(__file__).resolve().parent
sys.path.insert(0,str(root/'tools'))
spec=importlib.util.spec_from_file_location('sputnik_build',root/'tools/build-sputnik.py');build=importlib.util.module_from_spec(spec);spec.loader.exec_module(build)
code=(here/'gait-node.lua').read_text();(here/'spot-quadruped-gait.clipboard.txt').write_text(build.clipboard('spot-quadruped-gait-experiment',code)+'\n')
