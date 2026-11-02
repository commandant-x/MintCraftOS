#!/usr/bin/env python3
"""Report vertical motion during a leg test with a non-motorized test guide."""
import argparse,csv,json,math
from pathlib import Path
from analyze_ground import analyze as ground

def analyze(path):
 guide=(path/'guide.txt').read_text()
 if 'vertical Y is free' not in guide:raise ValueError('missing vertical guide declaration')
 with (path/'chassis.csv').open(newline='') as f: rows=list(csv.DictReader(f))
 if [int(r['tick']) for r in rows]!=[230]+list(range(240,681,10)):raise ValueError('incomplete trace')
 if rows[0]['locked']!='true' or any(r['locked']!='false' for r in rows[1:]):raise ValueError('unexpected staff locks')
 base=rows[0];x0,y0,z0=(float(base[k]) for k in ('x','y','z'));ys=[float(r['y']) for r in rows];xz=[math.hypot(float(r['x'])-x0,float(r['z'])-z0) for r in rows]
 result=ground(path,free_chassis=True)
 result['interpretation']='the chassis is guided in X, Z and rotation but is free in Y; contact counts are not force measurements'
 return {'guide':'static physics constraint locks horizontal translation and all rotations; vertical translation remains free','initial_y':y0,'y_at_tick_250':float(rows[2]['y']),'minimum_y':min(ys),'maximum_y':max(ys),'final_y':ys[-1],'final_vertical_displacement_blocks':ys[-1]-y0,'max_horizontal_deviation_blocks':max(xz),'lower_leg_contact':result,'unguided_balance_tested_here':False,'walking_tested':False}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);print(json.dumps(analyze(p.parse_args().directory),indent=2))
