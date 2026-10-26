"""Declared point-load reconfiguration fixtures; no controller sees the true COM."""
import copy
from quad_campaign_contract import fixtures,evaluate

def fixtures_com():
 reference=next(f for f in fixtures() if f['id']=='reference')
 out=[]
 def point(at,mass,position):return dict(at=at,payload=dict(mass=mass,position=list(position)))
 def moved(ident,positions):
  f=copy.deepcopy(reference);f.update(id=ident,chassisMass=16,chassisInertia=[125,200,115],inertia=[133,200,123],initialLoad=dict(payload=dict(mass=16,position=[0,-1,0])),changes=[point(5+i*15,16,p) for i,p in enumerate(positions)])
  return f
 out.append(moved('same-mass-right',[(4,-1,0)]))
 out.append(moved('same-mass-corner',[(4,-1,6)]))
 out.append(moved('same-mass-reverse',[(4,-1,6),(-4,-1,-6),(0,-1,0)]))
 for ident,position,drop in [('added-load',[3,-2,4],False),('added-far-and-dropped',[8,-2,6],True)]:
  f=copy.deepcopy(reference);f.update(id=ident,chassisMass=32,chassisInertia=[250,400,230],changes=[point(5,12,position)])
  if drop:f['changes'].append(point(20,0,[0,0,0]))
  out.append(f)
 f=moved('initial-unknown-corner',[]);f['initialLoad']['payload']['position']=[4,-1,6];out.append(f)
 f=moved('moving-load-ramp',[]);f['changes']=[point(5+i*.05,16,[4*i/40,-1,6*i/40]) for i in range(41)];out.append(f)
 f=moved('six-sails-corner',[(4,-1,6)])
 for rotor in f['rotors']:rotor['sails']=6
 out.append(f)
 f=copy.deepcopy(reference);f.update(id='heavy-with-added-load',mass=96,inertia=[750,1200,690],chassisMass=96,chassisInertia=[750,1200,690],changes=[point(5,24,[4,-2,5])]);out.append(f)
 f=moved('mixed-sails-corner',[(4,-1,6)])
 for rotor,sails in zip(f['rotors'],[8,12,16,20]):rotor['sails']=sails
 out.append(f)
 f=moved('delayed-noisy-right',[(4,-1,0)]);f.update(delay=3,spoolFactor=.5,noise=.01,attitudeNoise=.1);out.append(f)
 f=moved('outside-physical-support',[(8,-1,12)]);f['expected_unachievable']=True;out.append(f)
 for f in out:
  f.update(sensorFrame='body',sampledVelocity=True)
  if f['id']=='moving-load-ramp':f['episodes']=[dict(start=5,end=7)]
  elif f['changes']:f['episodes']=[dict(start=c['at'],end=c['at']) for c in f['changes']]
  else:f['episodes']=[dict(start=0,end=0)]
 return out

def evaluate_com(rows,event,movement,seconds,fixture):
 # Retain every historical criterion, then add point-load/hold-specific evidence.
 original=evaluate(rows,event,movement,seconds)
 if event['status']=='REFUSED':return dict(historical=original,status='REFUSED',checks={},episodes=[])
 checks=dict(complete=event['status']=='COMPLETE' and len(rows)==seconds*20+1)
 checks['fresh_observations']=bool(rows) and all(abs(b['t']-a['t']-.05)<1e-6 for a,b in zip(rows,rows[1:]))
 checks['unchanged_altitude_target']=bool(rows) and max(abs(r['target_y']-rows[0]['target_y']) for r in rows)<1e-6
 episodes=[]
 release=0 if movement=='hover' else 10
 for i,ep in enumerate(fixture['episodes']):
  start=max(ep['end'],release);end=fixture['episodes'][i+1]['start'] if i+1<len(fixture['episodes']) else seconds
  data=[r for r in rows if start<=r['t']<end or (end==seconds and r['t']==end)]
  count=0;settled=None
  for r in data:
   ok=abs(r['vy'])<=.1 and (r['vx']**2+r['vz']**2)**.5<=.2 and r['tilt']<=5 and abs(r['y']-r['target_y'])<=1
   count=count+1 if ok else 0
   if count>=20 and settled is None:settled=r['t']-start
  tail=[r for r in data if r['t']>end-5]
  steady=len(tail)>=20 and max(abs(r['y']-r['target_y']) for r in tail)<1 and max(r['tilt'] for r in tail)<5 and sum(r['vy']**2 for r in tail)/len(tail)<.04 and sum(r['vx']**2+r['vz']**2 for r in tail)/len(tail)<.04
  episodes.append(dict(start=start,end=end,stationary20_seconds=settled,tail_stable=steady,peak_height_error=max((abs(r['y']-r['target_y']) for r in data),default=None),peak_tilt=max((r['tilt'] for r in data),default=None)))
 checks['measured_stationary20']=all(e['stationary20_seconds'] is not None and e['stationary20_seconds']<=15 for e in episodes)
 checks['all_episode_tails_stable']=all(e['tail_stable'] for e in episodes)
 # A successful motion still needs the signed displacement/turn evidence.
 checks['motion_observed']=original['criteria'].get('motion',True)
 return dict(historical=original,status='PASS' if all(checks.values()) else 'FAIL',checks=checks,episodes=episodes)
