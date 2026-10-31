#!/usr/bin/env python3
"""Score real server traces; retain motion, settling, protection and excursions separately."""
import argparse,csv,hashlib,json,math,re,shutil
from pathlib import Path
PHASES=[('hover',None,400,(0,0,0)),('climb',400,820,(0,0,1)),('descend',820,1240,(0,0,-1)),('forward',1240,1660,(1,0,0)),('reverse',1660,2080,(-1,0,0)),('left',2080,2500,(0,1,0)),('right',2500,2920,(0,-1,0)),('diagonal',2920,None,(1,1,0))]
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def stable(r):return abs(r['y']-r['target_y'])<=1 and abs(r['vy'])<=.1 and math.hypot(r['vx'],r['vz'])<=.2 and abs(r['pitch'])<=5 and abs(r['roll'])<=5 and r['active']==1

def analyze(folder):
 events=(folder/'events.tsv').read_text();rows=[{k:float(v) for k,v in r.items()} for r in csv.DictReader((folder/'flight.csv').open())]
 assert rows and all(all(math.isfinite(v) for v in r.values()) for r in rows)
 epoch=int(re.search(r'scenario epoch=(\d+)',events).group(1));release=int(re.search(r'^(\d+)\tRELEASE:',events,re.M).group(1));complete=re.search(r'^(\d+)\tCOMPLETE:',events,re.M);end=int(complete.group(1)) if complete else int(rows[-1]['tick'])+1
 faults=[(int(m.group(1)),m.group(2)) for m in re.finditer(r'^(\d+)\t((?:ABORT:|ERROR ).*)',events,re.M)]
 aborted=any(t<end for t,message in faults)
 cleanup_faults=[dict(tick=t,reason=message) for t,message in faults if t>=end]
 by_tick={int(r['tick']):r for r in rows};protected=[int(m.group(1)) for m in re.finditer(r'^(\d+)\tACK_REQUEST',events,re.M)]
 cases=[]
 for name,start,stop,intent in PHASES:
  samples=[r for r in rows if release<r['tick']<end and (start is None or r['universe_tick']-epoch>=start) and (stop is None or r['universe_tick']-epoch<stop)]
  if not samples:cases.append(dict(movement=name,status='NOT_EXECUTED'));continue
  first,last=samples[0],samples[-1];dx,dy,dz=(last[k]-first[k] for k in ['x','y','z']);f,l,v=intent;heading=math.radians(first['yaw']);along=dx*(f*math.sin(heading)-l*math.cos(heading))+dz*(f*math.cos(heading)+l*math.sin(heading));norm=math.hypot(f,l)
  if norm:along/=norm
  correct=(dy*v>.1) if v else (along>.2) if norm else True
  tail=samples[-60:];fresh=len(tail)==60 and all(b['universe_tick']==a['universe_tick']+1 for a,b in zip(tail,tail[1:]));settled=fresh and all(stable(r) for r in tail)
  protect=any(int(first['tick'])<=t<=int(last['tick']) for t in protected)
  pulse_end=next((r['tick'] for r in samples if start is not None and r['universe_tick']-epoch>=start+20),first['tick'])
  streak=0;observed=None
  for r in samples:
   if r['tick']<pulse_end:continue
   streak=streak+1 if stable(r) else 0
   if streak>=20:observed=(r['tick']-pulse_end)/20;break
  metrics=dict(samples=len(samples),position_delta=[dx,dy,dz],projected_horizontal_displacement=along if norm else None,max_height_error=max(abs(r['y']-r['target_y']) for r in samples),tail_height_error=max(abs(r['y']-r['target_y']) for r in tail),tail_height_span=max(r['y'] for r in tail)-min(r['y'] for r in tail),peak_abs_pitch=max(abs(r['pitch']) for r in samples),peak_abs_roll=max(abs(r['roll']) for r in samples),peak_vertical_speed=max(abs(r['vy']) for r in samples),peak_horizontal_speed=max(math.hypot(r['vx'],r['vz']) for r in samples),first_20_fresh_settling_seconds=observed,tail_60_fresh=bool(fresh),tail_60_stable=bool(settled),direction_observed=bool(correct),horizontal_protection=bool(protect))
  finished=(last['universe_tick']-epoch>=stop-1) if stop is not None else bool(complete)
  phase_fault=any(first['tick']<=t<=last['tick'] for t,message in faults if t<end)
  metrics['phase_complete']=bool(finished)
  passed=correct and settled and not protect and finished and not phase_fault
  cases.append(dict(movement=name,status='PASS' if passed else 'PROTECTED' if protect else 'FAIL',metrics=metrics,first_tick=int(first['tick']),last_tick=int(last['tick'])))
 yaw=0
 free=[r for r in rows if release<r['tick']<end]
 for a,b in zip(free,free[1:]):yaw+=(b['yaw']-a['yaw']+180)%360-180
 return dict(schema=1,source='real Minecraft dedicated server, Sable/Rapier physics',hardware_observation='actual shaft RPM and Redstone Link receiver levels',typewriter_physical_keys_tested=False,client_gui_tested=False,cold_start_tested=False,body_yaw_controlled=False,body_yaw_drift_degrees=yaw,controller_globally_qualified=False,completed=bool(complete),aborted=aborted,cleanup_faults=cleanup_faults,release_tick=release,scenario_epoch=epoch,frames=len(rows),free_frames=len(free),fresh_tick_gaps=sum(b['universe_tick']!=a['universe_tick']+1 for a,b in zip(rows,rows[1:])),cases=cases)

def plots(path,rows,result):
 import matplotlib
 matplotlib.use('Agg')
 import matplotlib.pyplot as plt
 from matplotlib.backends.backend_pdf import PdfPages
 with PdfPages(path,metadata={'CreationDate':None,'ModDate':None}) as pdf:
  for case in result['cases']:
   if 'first_tick' not in case:continue
   s=[r for r in rows if case['first_tick']<=r['tick']<=case['last_tick']];t=[(r['tick']-s[0]['tick'])/20 for r in s];fig,axes=plt.subplots(2,2,figsize=(11.7,8.3));fig.suptitle(case['movement']+' — '+case['status']+' — Minecraft / Rapier réel')
   axes[0,0].plot([r['x'] for r in s],[r['z'] for r in s]);axes[0,0].set(xlabel='X monde (m)',ylabel='Z monde (m)',title='Trajectoire');axes[0,0].set_aspect('equal',adjustable='datalim')
   axes[0,1].plot(t,[r['y'] for r in s],label='réelle');axes[0,1].plot(t,[r['target_y'] for r in s],'--',label='cible');axes[0,1].set(title='Altitude',xlabel='Temps (s)',ylabel='m');axes[0,1].legend()
   axes[1,0].plot(t,[r['pitch'] for r in s],label='tangage');axes[1,0].plot(t,[r['roll'] for r in s],label='roulis');axes[1,0].set(title='Assiette',xlabel='Temps (s)',ylabel='degrés');axes[1,0].legend()
   for i in range(1,5):axes[1,1].plot(t,[r['rpm'+str(i)] for r in s],label=str(i),lw=.8)
   axes[1,1].set(title='Régimes mesurés des quatre hélices',xlabel='Temps (s)',ylabel='RPM (module)');axes[1,1].legend(ncol=4)
   for ax in axes.flat:ax.grid(alpha=.25)
   fig.tight_layout(rect=(0,.04,1,.95));fig.text(.04,.015,'Entrées radio synthétiques ; moteurs préchauffés ; monde copié. PASS = mouvement + maintien final, pas qualification globale.',fontsize=8);pdf.savefig(fig);plt.close(fig)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--run',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--plots',action='store_true');a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
 result=analyze(a.run);(a.output/'results.json').write_text(json.dumps(result,indent=2)+'\n')
 for name in ['flight.csv','events.tsv','hardware.tsv','descriptors.txt','geometry.txt']:
  if (a.run/name).exists():shutil.copy2(a.run/name,a.output/name)
 if a.plots:
  rows=[{k:float(v) for k,v in r.items()} for r in csv.DictReader((a.run/'flight.csv').open())];plots(a.output/'movements.pdf',rows,result)
 print([(c['movement'],c['status']) for c in result['cases']])
if __name__=='__main__':main()
