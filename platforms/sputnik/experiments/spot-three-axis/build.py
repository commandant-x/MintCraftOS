#!/usr/bin/env python3
"""Build the Sputnik preview node with bundled pure geometry; no actuator output."""
from pathlib import Path
import importlib.util,sys
root=Path(__file__).resolve().parents[4];here=Path(__file__).resolve().parent
sys.path.insert(0,str(root/'tools'))
spec=importlib.util.spec_from_file_location('sputnik_build',root/'tools/build-sputnik.py');build=importlib.util.module_from_spec(spec);spec.loader.exec_module(build)
code='local IK=(function()\n'+(here/'leg_ik.lua').read_text()+'\nend)()\nlocal GAIT=(function()\n'+(here/'wave_gait.lua').read_text()+'\nend)()\n'+(here/'preview-node.lua').read_text()
(here/'spot-preview.lua').write_text(code)
(here/'spot-preview.clipboard.txt').write_text(build.clipboard('spot-trois-axes-apercu',code))
