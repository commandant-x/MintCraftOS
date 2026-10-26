from pathlib import Path
import csv,json,hashlib,zipfile,io
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path('/workspace/MintCraftOS');out=root/'platforms/sputnik/reports/quad-ringing-0.3.2';work=Path('/tmp/sputnik-ringing-033/native-correct')
fig,axes=plt.subplots(2,3,figsize=(15,8),sharex=True)
for row,movement in enumerate(('hover','brake')):
 for rpm,color in ((256,'#b62525'),(128,'#1565b5'),(64,'#19814a')):
  path=work/f'reference-rpm{rpm}-tilt3'/f'{movement}.csv';rows=list(csv.DictReader(path.open()));d={k:np.array([float(r[k]) for r in rows]) for k in rows[0]}
  axes[row,0].plot(d['t'],d['y']-d['target_y'],label=f'{rpm} RPM source',color=color,lw=.8)
  axes[row,1].plot(d['t'],d['attitude_error'],label=f'{rpm} RPM source',color=color,lw=.8)
  axes[row,2].plot(d['t'],d['vy'],label=f'{rpm} RPM source',color=color,lw=.8)
 for col,(label,band) in enumerate((('Erreur altitude (m)',.3),('Erreur assiette (°)',2),('Vitesse verticale (m/s)',.2))):
  ax=axes[row,col];ax.axhspan(0 if col==1 else -band,band,color='#cccccc',alpha=.4);ax.set(ylabel=label,xlim=(0,60),xlabel='Temps (s)',title=('Maintien sans touche' if row==0 else 'W entre 5 et 10 s puis freinage'));ax.grid(alpha=.25)
  if row==1:ax.axvspan(5,10,color='#dddd66',alpha=.15)
axes[0,0].legend(fontsize=9)
fig.suptitle('Même contrôleur Sputnik 0.3.2 — 32 kg, 12 voiles, inclinaison initiale 3°\nIntervention sur le vrai régime source simulé, pas seulement sur le champ de configuration',fontsize=13)
fig.tight_layout(rect=(0,0,1,.92));fig.savefig(out/'rpm-and-transients.png',dpi=150);plt.close(fig)
# Exact discrimination between first stable second and permanent suffix on a historical PASS.
z=zipfile.ZipFile(root/'platforms/sputnik/reports/quad-campaign-0.3.2/campaign-traces-fpv.zip');rows=list(csv.DictReader(io.StringIO(z.read('traces/reference/fpv/forward-left.csv').decode())));d={k:np.array([float(r[k]) for r in rows]) for k in rows[0]}
fig,axes=plt.subplots(3,1,figsize=(12,8),sharex=True)
axes[0].plot(d['t'],d['y']-d['target_y'],lw=.8);axes[0].axhspan(-.3,.3,color='#cccccc',alpha=.4);axes[0].set_ylabel('Erreur altitude (m)')
axes[1].plot(d['t'],d['attitude_error'],lw=.8);axes[1].axhspan(0,2,color='#cccccc',alpha=.4);axes[1].set_ylabel('Erreur assiette (°)')
axes[2].plot(d['t'],d['vy'],label='Vy',lw=.8);axes[2].plot(d['t'],np.hypot(d['vx'],d['vz']),label='V horizontale',lw=.8);axes[2].axhspan(-.2,.2,color='#cccccc',alpha=.4);axes[2].set(ylabel='Vitesses (m/s)',xlabel='Temps (s)');axes[2].legend()
for ax in axes:
 ax.axvspan(5,10,color='#dddd66',alpha=.2);ax.axvline(14.15,color='#1a9d51',ls='--',label='Première seconde stable');ax.axvline(47.8,color='#b62525',ls='--',label='Stabilité durable');ax.grid(alpha=.25);ax.set_xlim(0,60)
axes[0].legend(fontsize=8);fig.suptitle('Référence, diagonale W+Q : PASS historique, mais quatre sorties de la bande après une première seconde stable\nNouvelles bandes de diagnostic : 0,3 m / 2° / Vy 0,2 m/s / Vh 0,3 m/s ; aucune qualification Minecraft',fontsize=11)
fig.tight_layout(rect=(0,0,1,.93));fig.savefig(out/'first-window-vs-durable.png',dpi=150);plt.close(fig)
print('Figures complete')
