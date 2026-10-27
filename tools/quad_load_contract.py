"""Fixed-source suspended-load profiles; same historical motion criteria plus cable settling."""
import copy,math
from quad_campaign_contract import fixtures,evaluate

def fixtures_load():
 reference=next(f for f in fixtures() if f['id']=='reference');out=[]
 for ident,mass,length,load,offset,angle in [('reference',32,5,12,0,20),('offset',32,5,12,2,20),('heavy-load',32,5,32,0,20),('long-rope',32,10,12,0,20),('large-board',96,5,32,2,20),('short-rope',32,2,12,0,20),('large-swing',32,5,12,0,40),('light-load',32,5,4,0,20)]:
  f=copy.deepcopy(reference);f.update(id=ident,mass=mass,inertia=[250*mass/32,400*mass/32,230*mass/32],ropeLength=length,ropeMass=load,anchorX=offset,ropeAngle=angle,ropeLoad=True,sampledVelocity=True,sensorFrame='body');out.append(f)
 return out

def evaluate_load(rows,event,name,seconds):
 score=evaluate(rows,event,name,seconds)
 if score['status']=='REFUSED':return score
 tail=[r for r in rows if r['t']>seconds-10]
 score['metrics']['tail_cable_peak']=max((r['rope_angle'] for r in tail),default=None)
 score['criteria']['cable_settled']=len(tail)>=20 and score['metrics']['tail_cable_peak']<5
 score['criteria']['fresh_observations']=bool(rows) and all(abs(b['t']-a['t']-.05)<1e-6 for a,b in zip(rows,rows[1:]))
 score['failures']=[k for k,v in score['criteria'].items() if not v]
 score['status']='FAIL' if score['failures'] else 'PASS'
 return score
