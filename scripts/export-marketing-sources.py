#!/usr/bin/env python3
"""Export successful native core XCTest attachments to a separate source inventory."""
import argparse,hashlib,json,plistlib,subprocess
from datetime import datetime,timezone
from pathlib import Path
from PIL import Image
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--story',action='store_true');p.add_argument('--band',choices=['night-shift','minor-threat'],default='night-shift');p.add_argument('--attachments',type=Path,required=True);p.add_argument('--result',type=Path,required=True);p.add_argument('--device',choices=['iphone','ipad'],required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--app',type=Path,required=True);a=p.parse_args()
repo=Path(__file__).resolve().parents[1]
if a.output.resolve()==(repo/'screenshots').resolve():raise ValueError('Native inputs must not overwrite canonical marketing cards')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=a.output/'manifest.json';m=json.loads(manifest.read_text()) if manifest.exists() else {'images':{}}
info=plistlib.loads((a.app/'Info.plist').read_bytes());revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip();dirty=bool(subprocess.check_output(['git','status','--porcelain'],cwd=repo,text=True))
ids={'calendar':1,'day-detail':2,'availability-automatic':8,'availability-manual':8,'settings':3,'band':11,'confirmation':12,'personal-calendar':13}
source_hashes={str(p.relative_to(repo)):sha(p) for p in (repo/'HeavyBandManager').rglob('*.swift') if p.name!='Secrets.swift'}
artwork_hashes={str(p.relative_to(repo)):sha(p) for p in (repo/'Fixtures/MinorThreat').iterdir() if p.suffix in ['.jpg','.png']} if a.band=='minor-threat' else {}
runtime_cache={}
def runtime_for(device_id):
 if device_id not in runtime_cache:
  devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','-j'],text=True))['devices']
  identifier=next(r for r,ds in devices.items() if any(d['udid']==device_id for d in ds))
  runtimes=json.loads(subprocess.check_output(['xcrun','simctl','list','runtimes','-j'],text=True))['runtimes']
  runtime_cache[device_id]=next(r for r in runtimes if r['identifier']==identifier)
 return runtime_cache[device_id]
count=0
for test in json.loads((a.attachments/'manifest.json').read_text()):
 for item in test['attachments']:
  name=item['suggestedHumanReadableName']
  for appearance in ['light','dark']:
   for slug,number in ids.items():
    if not name.startswith(f'core-{appearance}-{slug}_'):continue
    source=a.attachments/item['exportedFileName'];key=f'{a.device}/{appearance}/{number}-{a.device}-{appearance}-{slug}.png';dest=a.output/key;dest.parent.mkdir(parents=True,exist_ok=True)
    with Image.open(source) as im:
     dimensions=list(im.size);expected=[1320,2868] if a.device=='iphone' else [2064,2752]
     if dimensions!=expected:raise ValueError(f'Wrong native device dimensions: {dimensions}')
     im.convert('RGB').save(dest)
    m['images'][key]={'kind':'native','sha256':sha(dest),'dimensions':dimensions,'device':a.device,'appearance':appearance,'screen':slug,'capture':{'capturedAt':datetime.fromtimestamp(item['timestamp'],timezone.utc).isoformat(),'application':'Band Practice','version':info['CFBundleShortVersionString'],'build':info['CFBundleVersion'],'bundleIdentifier':info['CFBundleIdentifier'],'configuration':'Debug; AVAILABILITY_TAB_PREVIEW','sourceRevision':revision,'sourceDirty':dirty,'sourceDeviceID':item['deviceId'],'nativeDimensions':dimensions,'appearance':appearance,'locale':'en_US','timeZone':'America/Los_Angeles','fixture':a.band,'artwork_sha256':artwork_hashes,'dataMode':'Isolated in-memory AvailabilityTabPreview; --screenshot-mode; '+('--screenshot-story; ' if a.story else '')+'no external writes; '+('Minor Threat local artwork; fictional availability and rehearsals' if a.band=='minor-threat' else 'normal initials and band icon approved'),'resultBundle':str(a.result.resolve()),'attachmentFile':item['exportedFileName'],'attachmentName':name,'attachmentSha256':sha(source),'source_sha256':source_hashes,'nativeWalkthrough':test.get('testIdentifier')}}
    if slug == 'personal-calendar':
     runtime=runtime_for(item['deviceId'])
     m['images'][key]['capture'].update(application='Apple Calendar', version=runtime['name'], build=runtime['buildversion'], bundleIdentifier='com.apple.mobilecal', configuration='Simulator system Calendar', dataMode='Manually staged fictional rehearsals in simulator-local Band Practice calendar using standalone helper; not an app sync test', source_sha256={'scripts/BandCalendarDemo.swift':sha(repo/'scripts/BandCalendarDemo.swift')})
    count+=1
if not count:raise ValueError('No core attachments found')
m['scope']='native-core';m['updatedAt']=datetime.now(timezone.utc).isoformat();manifest.write_text(json.dumps(m,indent=2)+'\n');print(f'Exported {count} native {a.device} captures to {a.output}')
