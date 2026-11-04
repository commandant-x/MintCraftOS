#!/usr/bin/env python3
"""Build the tested two-node graph with explicit experimental frequencies."""
from pathlib import Path
import importlib.util,sys
root=Path(__file__).resolve().parents[5];here=Path(__file__).resolve().parent
sys.path.insert(0,str(root/'tools'))
spec=importlib.util.spec_from_file_location('sputnik_build',root/'tools/build-sputnik.py');build=importlib.util.module_from_spec(spec);spec.loader.exec_module(build)
operator=(here/'operator-node.lua').read_text();controller=(here/'gait-wireless.lua').read_text()
nodes=[('spot-operator',operator,20,40),('spot-wireless-gait',controller,600,40)]
edges=[('spot-operator','Enable','spot-wireless-gait','Enable'),('spot-operator','Start','spot-wireless-gait','Start')]
(here/'spot-quadruped-wireless.clipboard.txt').write_text(build.graph_clipboard(nodes,edges)+'\n')
