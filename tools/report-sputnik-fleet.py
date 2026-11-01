#!/usr/bin/env python3
"""Separate native construction, commissioning, preflight and actual flight results."""
import argparse
import csv
import hashlib
import json
import math
import re
import shutil
from pathlib import Path

PHASES = [('hover',320,800),('climb',800,1200),('descend',1200,1600),
          ('forward',1600,2000),('reverse',2000,2400),('left',2400,2800),
          ('right',2800,3200),('diagonal',3200,3600),('shock',3600,4400)]


def tilt(r):
    return math.degrees(math.acos(max(-1,min(1,math.cos(math.radians(r['pitch']))*math.cos(math.radians(r['roll']))))))


def fresh(rows):
    return bool(rows) and all(b['universe_tick']==a['universe_tick']+1 and b['tick']==a['tick']+1 for a,b in zip(rows,rows[1:]))


def stable(r):
    return r['active']==1 and abs(r['y']-r['target_y'])<=1 and abs(r['vy'])<=.1 and math.hypot(r['vx'],r['vz'])<=.2 and tilt(r)<=5


def analyze(folder, architecture):
    events=(folder/'events.tsv').read_text()
    rows=[]
    if (folder/'flight.csv').exists():
        with (folder/'flight.csv').open() as f:
            rows=[{k:float(v) for k,v in r.items()} for r in csv.DictReader(f)]
    if any(not math.isfinite(v) for r in rows for v in r.values()):
        raise ValueError('Non-finite trace')
    commissioned='COMMISSION_PASS:' in events
    release=re.search(r'^(\d+)\tRELEASE:',events,re.M)
    complete=re.search(r'^(\d+)\tCOMPLETE:',events,re.M)
    faults=list(re.finditer(r'^(\d+)\t(?:ABORT:|ERROR ).*$',events,re.M))
    stop=min([int(m.group(1)) for m in faults]+([int(complete.group(1))] if complete else [4400]))
    contract=json.loads((folder/'test-contract.json').read_text()) if (folder/'test-contract.json').exists() else {'steering':'lateral','provenance':'executed fixture v1/v2 sets steering checkbox false'}
    steering=contract['steering'];pure_balloon=architecture=='balloon-lift'
    result=dict(architecture=architecture,contract=contract,constructed='\tBUILT ' in events,
                commissioned=commissioned,released=bool(release),completed=bool(complete),
                faults=[m.group(0) for m in faults],controller_globally_qualified=False,phases=[])
    if not release:
        result['status']='WARMUP_NOT_VERIFIED' if 'GAS_WARMUP' in events else 'PREFLIGHT_REFUSED' if commissioned else 'COMMISSIONING_FAILED' if 'COMMISSION signal=' in events else 'CONFIGURATION_FAILED' if result['constructed'] else 'CONSTRUCTION_FAILED'
        result['phases']=[dict(name=n,status='NOT_EXECUTED') for n,_,_ in PHASES]
        return result,rows
    if not commissioned:
        result['status']='INVALID_COMMISSIONING'
        result['phases']=[dict(name=n,status='NOT_QUALIFIABLE') for n,_,_ in PHASES]
        return result,rows
    scored=[];last_target=None
    for r in rows:
        row=r.copy()
        if row['active']==1:last_target=row['target_y']
        elif last_target is not None:row['target_y']=last_target
        scored.append(row)
    for name,start,end in PHASES:
        # The ABORT row precedes fixture capture. A controller's cleared target
        # on that row is unavailable, not a new accepted altitude of zero.
        samples=[r.copy() for r in scored if start<=r['tick']<end and r['tick']<=stop]
        for i,r in enumerate(samples):
            if r['active']!=1 and i:
                r['target_y']=samples[i-1]['target_y']
        if not samples:
            result['phases'].append(dict(name=name,status='NOT_EXECUTED'));continue
        first,last=samples[0],samples[-1]
        dx,dz=last['x']-first['x'],last['z']-first['z']
        yaw=math.radians(first['yaw'])
        along=dx*math.sin(yaw)+dz*math.cos(yaw)
        lateral=-dx*math.cos(yaw)+dz*math.sin(yaw)
        yaw_delta=sum((b['yaw']-a['yaw']+180)%360-180 for a,b in zip(samples,samples[1:]))
        # Observe intent during the 60 tick pulse; final displacement alone can
        # hide a correct move followed by return-to-position guidance.
        pulse=[r for r in samples if r['tick']<start+80]
        fwd=[(r['x']-first['x'])*math.sin(yaw)+(r['z']-first['z'])*math.cos(yaw) for r in pulse]
        lat=[-(r['x']-first['x'])*math.cos(yaw)+(r['z']-first['z'])*math.sin(yaw) for r in pulse]
        ydelta=[r['y']-first['y'] for r in pulse]
        supported=not (pure_balloon and name in ('forward','reverse','left','right','diagonal')) and not (architecture!='tri' and steering=='lateral' and name in ('left','right','diagonal'))
        if name=='climb':intent=max(ydelta)>.2 and max(r['target_y'] for r in samples)>first['target_y']+.2
        elif name=='descend':intent=min(ydelta)<-.2 and min(r['target_y'] for r in samples)<first['target_y']-.2
        elif name=='forward':intent=max(fwd)>.2
        elif name=='reverse':intent=min(fwd)<-.2
        elif name in ('left','right'):
            # Tri: translation through tilt. Banks: yaw is evaluated separately
            # from sideways motion, without imposing a heading convention.
            intent=(max(lat)>.2 if name=='left' else min(lat)<-.2) if architecture=='tri' else (yaw_delta < -2 if name=='left' else yaw_delta > 2)
        elif name=='diagonal':intent=max(fwd)>.2 and (max(lat)>.2 if architecture=='tri' else yaw_delta < -2)
        else:intent=True
        if 'commands_valid' in first and name not in ('hover','shock'):
            key='vertical_demand' if name in ('climb','descend') else 'left_demand' if name in ('left','right') else 'forward_demand'
            accepted=any(r['commands_valid']==1 and abs(r[key])>.5 for r in pulse)
            intent=intent and accepted
        else:accepted=None
        tail=samples[-200:]
        entry=[r for r in scored if start-200<=r['tick']<start and r['tick']>=320]
        entry_stable=len(entry)==200 and fresh(entry) and all(stable(r) for r in entry)
        settled=len(tail)==200 and fresh(tail) and all(stable(r) for r in tail)
        phase_complete=last['tick']>=end-1
        protected=any(r.get('protection',0)!=0 for r in samples)
        fault=any(start<=int(m.group(1))<end for m in faults)
        status='ABORT' if fault else 'HOLD_ONLY_PASS' if not supported and accepted is not False and phase_complete and settled and not protected else 'PASS' if supported and phase_complete and settled and intent and not protected else 'PROTECTED' if phase_complete and settled and intent and protected else 'FAIL' if phase_complete else 'INCOMPLETE'
        result['phases'].append(dict(name=name,status=status,first_tick=int(first['tick']),last_tick=int(last['tick']),
                                     intent_observed=bool(intent) if supported else None,requested_motion_supported=supported,commands_received=accepted,phase_complete=phase_complete,tail_200_fresh_stable=settled,
                                     entry_200_fresh_stable=entry_stable if start>320 else None,
                                     peak_height_error_m=max(abs(r['y']-r['target_y']) for r in samples),
                                     tail_height_error_m=max(abs(r['y']-r['target_y']) for r in tail),
                                     tail_vertical_speed_m_s=max(abs(r['vy']) for r in tail),tail_horizontal_speed_m_s=max(math.hypot(r['vx'],r['vz']) for r in tail),tail_tilt_deg=max(tilt(r) for r in tail),
                                     peak_tilt_deg=max(tilt(r) for r in samples),peak_vertical_speed_m_s=max(abs(r['vy']) for r in samples),
                                     peak_horizontal_speed_m_s=max(math.hypot(r['vx'],r['vz']) for r in samples),
                                     forward_delta_m=along,left_delta_m=lateral,yaw_delta_deg=yaw_delta,
                                     fresh_tick_gaps=sum(not fresh([a,b]) for a,b in zip(samples,samples[1:]))))
    result['status']='ABORT' if faults else 'PASS' if complete and all(p['status']=='PASS' for p in result['phases']) else 'DOMAIN_PASS' if complete and all(p['status'] in ('PASS','HOLD_ONLY_PASS') for p in result['phases']) else 'FAIL'
    return result,rows


def plots(output,result,rows):
    import matplotlib.pyplot as plt
    from matplotlib.backends.backend_pdf import PdfPages
    with PdfPages(output/'movements.pdf',metadata={'CreationDate':None,'ModDate':None}) as pdf:
        for phase in result['phases']:
            if 'first_tick' not in phase:continue
            s=[r.copy() for r in rows if phase['first_tick']<=r['tick']<=phase['last_tick']]
            for i,r in enumerate(s):
                if r['active']!=1 and i:r['target_y']=s[i-1]['target_y']
            t=[(r['universe_tick']-s[0]['universe_tick'])/20 for r in s]
            fig,axs=plt.subplots(2,2,figsize=(12,8));fig.suptitle(result['architecture']+' / '+phase['name']+' — '+phase['status']+' — Minecraft réel')
            axs[0,0].plot(t,[r['y'] for r in s],label='observée');axs[0,0].plot(t,[r['target_y'] for r in s],'--',label='cible');axs[0,0].set(ylabel='m',title='Altitude');axs[0,0].legend()
            axs[0,1].plot(t,[tilt(r) for r in s]);axs[0,1].set(ylabel='degrés',title='Inclinaison totale')
            axs[1,0].plot(t,[r['vy'] for r in s],label='verticale');axs[1,0].plot(t,[math.hypot(r['vx'],r['vz']) for r in s],label='horizontale');axs[1,0].set(ylabel='m/s',title='Vitesses');axs[1,0].legend()
            for key in s[0]:
                if re.fullmatch(r'rpm\d+',key):axs[1,1].plot(t,[r[key] for r in s],label=key,lw=.8)
            if any(r.get('gas_volume',0)>0 for r in s):
                axs[1,1].plot(t,[r['gas_volume'] if r.get('gas_provider_associated',1) else None for r in s],label='gaz m³ si associé',ls='--')
            axs[1,1].set(title='Arbres réels et gaz éventuel',ylabel='RPM / m³');axs[1,1].legend(ncol=3,fontsize=7)
            for ax in axs.flat:ax.set_xlabel('s de jeu depuis le début de phase');ax.grid(alpha=.2)
            fig.tight_layout(rect=(0,.04,1,.95));fig.text(.04,.015,'Construction native, vérification mécanique avant armement ; charge et géométrie propres à ce modèle. Qualification globale : non.',fontsize=8)
            pdf.savefig(fig);fig.savefig(output/(phase['name']+'.png'),dpi=120);plt.close(fig)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--run',type=Path,required=True);p.add_argument('--architecture',choices=['tri','quad-banks','quad-balanced','quad-turns','balloon','balloon-lift'],required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    a.output.mkdir(parents=True,exist_ok=True);result,rows=analyze(a.run/'fixture',a.architecture)
    for name in ('flight.csv','events.tsv','hardware.tsv','geometry.txt','descriptors.txt','writer-report.txt','test-contract.json'):
        src=a.run/'fixture'/name
        if src.exists():shutil.copy2(src,a.output/name)
    for name in ('run.json','exit.json'):
        if (a.run/name).exists():result[name[:-5]]=json.loads((a.run/name).read_text())
    if (a.output/'flight.csv').exists():result['trace_sha256']=hashlib.sha256((a.output/'flight.csv').read_bytes()).hexdigest()
    (a.output/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    if rows:
        import matplotlib
        matplotlib.use('Agg');plots(a.output,result,rows)
    print(result['status'],[(x['name'],x['status']) for x in result['phases']])


if __name__=='__main__':main()
