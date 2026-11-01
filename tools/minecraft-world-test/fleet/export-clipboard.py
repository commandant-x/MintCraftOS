#!/usr/bin/env python3
"""Export only the seven production nodes, without test transmitters or cached IO."""
import argparse
import base64
import copy
import hashlib
import json
import uuid
from pathlib import Path
import nbtlib as n


def quote(s):
    # Brigadier SNBT permits literal newlines, not JSON's backslash-n escape.
    return '"'+str(s).replace('\\','\\\\').replace('"','\\"')+'"'


def snbt(t):
    if isinstance(t,n.String):return quote(t)
    if isinstance(t,n.Compound):return '{'+','.join(quote(k)+':'+snbt(v) for k,v in t.items())+'}'
    for cls,prefix in ((n.IntArray,'I'),(n.ByteArray,'B'),(n.LongArray,'L')):
        if isinstance(t,cls):return '['+prefix+';'+','.join(str(int(x))+('b' if prefix=='B' else 'l' if prefix=='L' else '') for x in t)+']'
    if isinstance(t,n.List):return '['+','.join(snbt(x) for x in t)+']'
    for cls,suffix in ((n.Byte,'b'),(n.Short,'s'),(n.Int,''),(n.Long,'l'),(n.Float,'f'),(n.Double,'d')):
        if isinstance(t,cls):return str(float(t) if cls in (n.Float,n.Double) else int(t))+suffix
    raise TypeError(type(t))


def key(t):return tuple(int(x) for x in t)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--graph',type=Path,required=True);p.add_argument('--profile',required=True);p.add_argument('--reference',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    tag=n.parse_nbt(a.graph.read_text());allowed=('enable','keyboard','montage','mount','commands','autopilot','operations')
    nodes=[x for x in tag['nodes'] if any(str(x['title']).endswith('-'+s) for s in allowed)]
    if len(nodes)!=7:raise ValueError('Expected seven production nodes')
    ids={key(x['id']) for x in nodes};conns=[x for x in tag['conns'] if key(x['src']) in ids and key(x['tgt']) in ids]
    tag['nodes']=n.List[n.Compound](nodes);tag['conns']=n.List[n.Compound](conns)
    # Restore the previously verified draft-geometry display edge if missing.
    if a.reference:
        ref=n.parse_nbt(base64.b64decode(a.reference.read_bytes()).decode())
        existing={(key(c['src']),int(c['srcP']),key(c['tgt']),int(c['tgtP'])) for c in conns}
        by_id={key(x['id']):x for x in nodes}
        for c in ref['conns']:
            sig=(key(c['src']),int(c['srcP']),key(c['tgt']),int(c['tgtP']))
            if sig in existing or sig[0] not in ids or sig[2] not in ids:continue
            source=by_id[sig[0]]['outputs'][sig[1]];target=by_id[sig[2]]['inputs'][sig[3]]
            if str(source['name'])!='Geometry' or str(target['name'])!='Draft geometry':
                raise ValueError('Unexpected reference edge')
            tag['conns'].append(copy.deepcopy(c))
    remap={}
    for node in nodes:
        old=key(node['id']);u=uuid.uuid5(uuid.NAMESPACE_URL,'mintcraft-fleet-0.4.1/'+a.profile+'/'+str(old))
        parts=[(u.int>>shift)&0xffffffff for shift in (96,64,32,0)]
        remap[old]=n.IntArray([x if x<2**31 else x-2**32 for x in parts])
        node['id']=remap[old];node['title']=n.String('MintCraft '+a.profile+'-'+str(node['title']).split('-')[-1])
        for pins in ('inputs','outputs'):
            for pin in node[pins]:
                if 'value' in pin:pin['value']=n.Double(0)
                if 'stringValue' in pin:pin['stringValue']=n.String('')
        for k in ('err','failed'):
            if k in node['customData']:node['customData'][k]=n.Byte(0)
        if 'errMsg' in node['customData']:node['customData']['errMsg']=n.String('')
        if str(node['title']).endswith('-operations'):
            for index,value in ((14,''),(15,'0'),(16,''),(17,'')):
                node['elements'][index]['value']=n.String(value)
            node['elements'][9]['value']=n.Double(4)
        if str(node['title']).endswith('-mount'):
            fields=[e for e in node['elements'] if isinstance(e.get('value'),n.String)]
            rows=str(fields[8]['value']).splitlines()+str(fields[9]['value']).splitlines()
            active=[int(row.split(';')[1]) for row in rows if row.startswith('MCV1;')]
            if active:node['elements'][1]['value']=n.Double(min(active))
    for c in tag['conns']:
        c['src']=remap[key(c['src'])];c['tgt']=remap[key(c['tgt'])]
    sizes=[len(str(x['customData'].get('code','')).encode('utf-8'))+str(x['customData'].get('code','')).count('\0')+sum(2 for c in str(x['customData'].get('code','')) if ord(c)>65535) for x in nodes]
    if max(sizes)>=60000:raise ValueError('Lua node reaches 60,000 modified UTF bytes')
    text=snbt(tag);a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_bytes(base64.b64encode(text.encode()))
    print(json.dumps(dict(file=a.output.name,nodes=7,connections=len(tag['conns']),max_modified_utf=max(sizes),sha256=hashlib.sha256(a.output.read_bytes()).hexdigest())))


if __name__=='__main__':main()
