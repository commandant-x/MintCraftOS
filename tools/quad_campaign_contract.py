"""Versioned campaign fixtures, movement protocols and independently scored criteria."""
import copy, math
SCHEMA=1
MOVEMENTS={
 'hover':'Maintien sans touche pendant toute la simulation.',
 'cold-hover':'Même maintien, quatre rotors initialement immobiles, sans contact au sol modélisé.',
 'climb':'Espace entre 5 et 10 s, puis relâchement et maintien de la hauteur atteinte.',
 'descend':'Shift entre 5 et 10 s, puis relâchement et maintien.',
 'forward':'W entre 5 et 10 s, freinage au relâchement.',
 'reverse':'S entre 5 et 10 s, freinage au relâchement.',
 'left':'Q entre 5 et 10 s, mode déplacement latéral.',
 'right':'D entre 5 et 10 s, mode déplacement latéral.',
 'forward-left':'W+Q entre 5 et 10 s, mode déplacement latéral.',
 'forward-right':'W+D entre 5 et 10 s, mode déplacement latéral.',
 'reverse-left':'S+Q entre 5 et 10 s, mode déplacement latéral.',
 'reverse-right':'S+D entre 5 et 10 s, mode déplacement latéral.',
 'turn-left':'W+Q entre 5 et 10 s, mode virage de trajectoire. Aucune rotation du nez exigée.',
 'turn-right':'W+D entre 5 et 10 s, mode virage de trajectoire. Aucune rotation du nez exigée.',
 'climb-forward':'W+Espace entre 5 et 10 s : translation et montée simultanées.',
 'descend-left':'W+Q+Shift entre 5 et 10 s, mode latéral : diagonale et descente.',
 'vertical-cycle':'Espace de 5 à 10 s, maintien 10–15 s, Shift 15–20 s, puis maintien.',
 'reverse-command':'W de 5 à 10 s, S de 10 à 15 s, puis freinage.',
 'brake':'W de 5 à 10 s, relâchement, délai de freinage mesuré sur 15 observations consécutives.',
 'slalom':'W continu de 5 à 10 s, Q/D alternées toutes les 1,25 s, mode virage de trajectoire.',
 'gust':'Aucune touche ; vent monde (5,0,-3) m/s de 5 à 10 s, puis maintien.',
 'load-swing':'Aucune touche ; charge ponctuelle de 12 kg sur corde 5 m, inclinée initialement de 20°, ajoutée à 5 s.',
 'recovery-diagonal':'Aucune touche ; perturbation de 15° autour de l’axe diagonal X/Z à 5 s.',
 'recovery-inverted':'Aucune touche ; inversion instantanée de 180° à 5 s. Perte d’altitude publiée.',
}
CRITERIA={
 'complete':'60 s de simulation terminées, aucune faute du contrôleur ni sortie de l’enveloppe déclarée.',
 'tail_height_peak':'Erreur de hauteur maximale sur les 10 dernières secondes < 1 m.',
 'tail_height_rms':'Erreur de hauteur RMS sur les 10 dernières secondes < 0,5 m.',
 'tail_height_span':'Excursion de hauteur crête-à-crête sur les 10 dernières secondes < 1 m.',
 'tail_tilt':'Inclinaison maximale sur les 10 dernières secondes < 5°.',
 'tail_speed_rms':'Vitesse totale RMS sur les 10 dernières secondes < 0,35 m/s.',
 'final_speed':'Vitesse totale finale < 0,3 m/s.',
 'active_attitude':'Erreur de suivi d’assiette RMS < 5° et maximale < 10° pendant les phases actives, après 2 s de transition.',
 'active_height':'Pour une translation horizontale : erreur de hauteur maximale < 1 m sur la même fenêtre active.',
 'active_vertical_rate':'Quand Espace/Shift est maintenu : erreur RMS de vitesse verticale < 1 m/s après 2 s de transition.',
 'motion':'Preuve physique du mouvement demandé (déplacement signé, vitesse ou courbure), indépendante du drapeau de commande.',
 'braking':'Pour une commande horizontale : vitesse horizontale < 0,3 m/s pendant 15 observations fraîches consécutives au plus 6 s après relâchement.',
 'transient_height':'Erreur de hauteur transitoire maximale < 2 m ; bornes distinctes 5 m au démarrage à froid/charge/perturbation diagonale, 15 m en inversion.',
 'transient_tilt':'Inclinaison maximale < 35° hors essais explicites de récupération.',
 'recovery':'Après perturbation : 20 observations consécutives à inclinaison < 5°, vitesse horizontale < 0,3 m/s et vitesse verticale absolue < 0,3 m/s en moins de 15 s.',
 'rope':'Extension numérique maximale du câble < 0,03 m pour la charge pendulaire.',
}

def fixtures():
 def make(ident,positions=None,kind='bearing',sails=12,mass=32,inertia=None,**kw):
  positions=positions or [(-3,0,5),(3,0,5),(-3,0,-5),(3,0,-5)]
  rotors=[]
  for i,(x,y,z) in enumerate(positions):
   n=sails[i] if isinstance(sails,list) else sails
   rotors.append(dict(kind=kind,x=x,y=y,z=z,dx=0,dy=1,dz=0,source=256,sails=n,members=1,thrust=.2 if kind=='bearing' else 1,airflow=.05 if kind=='bearing' else .1))
  if inertia is None:
   # Declared synthetic mass distribution: half on arms, half in central body.
   inertia=[mass*.5+mass/8*sum(p[2]**2+p[1]**2 for p in positions),mass*.5+mass/8*sum(p[0]**2+p[2]**2 for p in positions),mass*.5+mass/8*sum(p[0]**2+p[1]**2 for p in positions)]
  return dict(id=ident,mass=mass,inertia=inertia,rotors=rotors,radius=max(math.sqrt(sum(a*a for a in p)) for p in positions)+4,**kw)
 f=[make('reference',inertia=[250,400,230]),
    make('square-x',[(-3,0,3),(3,0,3),(-3,0,-3),(3,0,-3)]),
    make('cross-plus',[(0,0,4),(4,0,0),(0,0,-4),(-4,0,0)]),
    make('narrow',[(-1.5,0,7),(1.5,0,7),(-1.5,0,-7),(1.5,0,-7)]),
    make('wide',[(-7,0,1.5),(7,0,1.5),(-7,0,-1.5),(7,0,-1.5)]),
    make('skew',[(-4,0,5),(2,0,4),(-3,0,-5),(4,0,-3)]),
    make('small-propellers',kind='small'),
    make('modular-6',sails=6),make('modular-24',sails=24),
    make('mixed-propellers',sails=[8,12,16,20]),
    make('light-16kg',mass=16),make('heavy-96kg',mass=96),
    make('low-inertia',inertia=[62.5,100,57.5]),
    make('very-low-inertia',inertia=[20,32,18.4]),
    make('slow-radio',inertia=[62.5,100,57.5],delay=3,spoolFactor=.5,noise=.01,attitudeNoise=.1),
    make('radio-5ticks',delay=5,noise=.01),
    make('shifted-com',comX=.6,comZ=-.5),
    make('coupled-inertia',inertia=[250,400,230,45,-30,40]),
    make('high-altitude',altitude=220,wind=[2,0,-1]),
    make('weak-one-rotor',rotorFactors=[.7,1,1,1]),
    make('pressure-mismatch',pressureFactor=.8),
    make('telemetry-delay',poseDelay=2,noise=.01),
    make('paired-rotors'),make('insufficient-lift',kind='small',mass=2000)]
 for r in f[-2]['rotors']:r['members']=2
 return f


def rms(values): return math.sqrt(sum(v*v for v in values)/len(values)) if values else None

def evaluate(rows,event,name,seconds):
 """Score true physical traces; absent phases, missing motion and refusal cannot pass."""
 if event['status']=='REFUSED':return dict(status='REFUSED',failures=['configuration_refused'],reason=event['reason'],criteria={},metrics={})
 checks={};metrics={}
 def criterion(key,condition):checks[key]=bool(condition)
 criterion('complete',event['status']=='COMPLETE' and len(rows)==seconds*20+1 and abs(rows[-1]['t']-seconds)<1e-6)
 if not rows:return dict(status='FAIL',failures=list(checks),reason=event['reason'],criteria=checks,metrics=metrics)
 tail=[r for r in rows if r['t']>seconds-10]
 speed=lambda r:math.sqrt(r['vx']**2+r['vy']**2+r['vz']**2)
 hspeed=lambda r:math.hypot(r['vx'],r['vz'])
 errors=[abs(r['y']-r['target_y']) for r in tail]
 metrics.update(final_height_error=abs(rows[-1]['y']-rows[-1]['target_y']),min_altitude=min(r['y'] for r in rows),max_altitude=max(r['y'] for r in rows),max_tilt=max(r['tilt'] for r in rows),final_speed=speed(rows[-1]),transient_height_peak=max(abs(r['y']-r['target_y']) for r in rows),max_rope_extension=max(r['rope_stretch'] for r in rows))
 if tail:
  metrics.update(tail_height_peak=max(errors),tail_height_rms=rms(errors),tail_height_span=max(r['y'] for r in tail)-min(r['y'] for r in tail),tail_tilt=max(r['tilt'] for r in tail),tail_speed_rms=rms([speed(r) for r in tail]),tail_vertical_rms=rms([r['vy'] for r in tail]))
 for key,bound in [('tail_height_peak',1),('tail_height_rms',.5),('tail_height_span',1),('tail_tilt',5),('tail_speed_rms',.35),('final_speed',.3)]:criterion(key,metrics.get(key,math.inf)<bound)
 bound=15 if name=='recovery-inverted' else 5 if name in ('cold-hover','load-swing','recovery-diagonal') else 2
 criterion('transient_height',metrics['transient_height_peak']<bound)
 if not name.startswith('recovery-'):criterion('transient_tilt',metrics['max_tilt']<35)
 if name=='load-swing':criterion('rope',metrics['max_rope_extension']<.03)
 active=[r for r in rows if (7<=r['t']<10) or (name=='reverse-command' and 12<=r['t']<15) or (name=='vertical-cycle' and 17<=r['t']<20)]
 moving=any(abs(r[k])>0 for r in rows for k in ('forward','left','vertical'))
 if moving:
  criterion('active_attitude',bool(active) and rms([r['attitude_error'] for r in active])<5 and max(r['attitude_error'] for r in active)<10)
  metrics['active_attitude_rms']=rms([r['attitude_error'] for r in active])
  vertical=[r for r in active if r['vertical']!=0]
  if vertical:
   metrics['active_vertical_rate_rms']=rms([r['vy']-4*r['vertical'] for r in vertical]);criterion('active_vertical_rate',metrics['active_vertical_rate_rms']<1)
  else:
   metrics['active_height_peak']=max(abs(r['y']-r['target_y']) for r in active) if active else None;criterion('active_height',bool(active) and metrics['active_height_peak']<1)
 at=lambda t:min(rows,key=lambda r:abs(r['t']-t))
 p0,p1=at(5),at(10);dx,dz=p1['x']-p0['x'],p1['z']-p0['z'];dy=p1['y']-p0['y'];metrics.update(active_dx=dx,active_dy=dy,active_dz=dz,peak_horizontal_speed=max(hspeed(r) for r in rows))
 evidence=True
 if name in ('forward','brake'):evidence=dz>1
 elif name=='climb-forward':evidence=dz>1 and dy>3
 elif name=='reverse':evidence=dz< -1
 elif name=='left':evidence=dx< -1
 elif name=='right':evidence=dx>1
 elif name in ('forward-left','forward-right','reverse-left','reverse-right','descend-left'):
  left=name.endswith('left');forward=not name.startswith('reverse');evidence=(dx<-.5 if left else dx>.5) and (dz>.5 if forward else dz<-.5)
  if name=='descend-left':evidence=evidence and dy< -3
 elif name=='reverse-command':evidence=dz>1 and at(14.5)['vz']<-.3
 elif name=='climb':evidence=dy>3
 elif name=='descend':evidence=dy< -3
 elif name=='vertical-cycle':evidence=dy>3 and at(20)['y']<at(15)['y']-3
 elif name=='slalom':
  a=[r for r in rows if 5<=r['t']<10];evidence=dz>1 and min(r['vx'] for r in a)<-.3 and max(r['vx'] for r in a)>.3
 elif name.startswith('turn-'):
  a=[r for r in rows if 5<=r['t']<10 and hspeed(r)>.5];turn=0
  for x,y in zip(a,a[1:]):turn+=math.degrees(math.atan2(y['vx']*x['vz']-y['vz']*x['vx'],x['vx']*y['vx']+x['vz']*y['vz']))
  metrics['trajectory_turn_deg']=turn;evidence=len(a)>20 and (turn< -10 if name=='turn-left' else turn>10)
 if moving:criterion('motion',evidence)
 horizontal=any(r['forward']!=0 or r['left']!=0 for r in rows)
 if horizontal:
  release=15 if name=='reverse-command' else 10;count=0;stop=None
  for r in rows:
   if r['t']<release:continue
   count=count+1 if hspeed(r)<.3 else 0
   if count>=15:stop=r['t']-release;break
  metrics['brake_seconds']=stop;criterion('braking',stop is not None and stop<=6)
 if name.startswith('recovery-'):
  count=0;settled=None
  for r in rows:
   if r['t']<5:continue
   count=count+1 if r['tilt']<5 and hspeed(r)<.3 and abs(r['vy'])<.3 else 0
   if count>=20:settled=r['t']-5;break
  metrics['recovery_seconds']=settled;criterion('recovery',settled is not None and settled<=15)
 failures=[k for k,v in checks.items() if not v]
 return dict(status='FAIL' if failures else 'PASS',failures=failures,reason=event['reason'],criteria=checks,metrics=metrics)
