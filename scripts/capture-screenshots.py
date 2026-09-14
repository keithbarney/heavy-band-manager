#!/usr/bin/env python3
"""Build once and capture selected native core screens on the saved project devices."""
import argparse,os,plistlib,subprocess,tempfile
from pathlib import Path
repo=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--band',choices=['night-shift','minor-threat'],default='night-shift');p.add_argument('--story',action='store_true');p.add_argument('--devices',default='iphone,ipad');p.add_argument('--appearances',default='light,dark');p.add_argument('--screens',default='calendar,day-detail,availability-automatic,availability-manual,settings,band');p.add_argument('--output-root',type=Path,required=True);p.add_argument('--derived-data',type=Path,default=Path('/tmp/heavy-band-manager-screenshot-build'));a=p.parse_args()
devices={'iphone':'F8B9CCD6-B79A-47B2-8553-1AAE8DFA3C80','ipad':'5F3838DB-3E87-46A1-93C6-F8E84363CD5C'}
def select(value,valid):
 result=value.split(',')
 if not result or set(result)-set(valid) or len(result)!=len(set(result)):p.error(f'Invalid selection: {value}')
 return result
selected=select(a.devices,devices);select(a.appearances,['light','dark']);select(a.screens,['calendar','day-detail','availability-automatic','availability-manual','settings','band','confirmation','personal-calendar'])
if a.output_root.resolve()==(repo/'screenshots').resolve():p.error('Use a temporary native source root; compose separately before publishing marketing cards')
work=Path(tempfile.mkdtemp(prefix='band-native-capture-'));log=work/'capture.log';python=os.environ.get('SCREENSHOT_PYTHON','/Users/keithbarney/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3')
def run(args,check=True):
 with log.open('a') as out:subprocess.run(args,cwd=repo,stdout=out,stderr=subprocess.STDOUT,check=check)
print(f'Native capture log/results retained: {work}',flush=True)
run(['xcodegen','generate'])
run(['xcodebuild','-project','HeavyBandManager.xcodeproj','-scheme','HeavyBandManagerScreenshots','-configuration','Debug','-destination',f'platform=iOS Simulator,id={devices[selected[0]]}','-derivedDataPath',str(a.derived_data),'-parallel-testing-enabled','NO','AVAILABILITY_TAB_PREVIEW_CONDITION=AVAILABILITY_TAB_PREVIEW','build-for-testing'])
products=a.derived_data/'Build/Products';original=next(products.glob('HeavyBandManagerScreenshots_*.xctestrun'));data=plistlib.loads(original.read_bytes());target=data['HeavyBandManagerScreenshotTests']
for env in ['EnvironmentVariables','TestingEnvironmentVariables']:
 target.setdefault(env,{}).update(SCREENSHOT_SCREENS=a.screens,SCREENSHOT_APPEARANCES=a.appearances,SCREENSHOT_STORY='1' if a.story else '0',SCREENSHOT_BAND=a.band)
config=products/'MarketingSelected.xctestrun';config.write_bytes(plistlib.dumps(data))
try:
 for device in selected:
  udid=devices[device];result=work/f'{device}.xcresult';attachments=work/f'{device}-attachments'
  run(['xcrun','simctl','bootstatus',udid,'-b'])
  if a.screens == 'personal-calendar':
   if ',' in a.appearances:raise ValueError('Capture Apple Calendar in one explicit appearance at a time')
   run(['xcrun','simctl','ui',udid,'appearance',a.appearances])
   run(['xcrun','simctl','terminate',udid,'com.apple.mobilecal'],check=False)
  run(['xcodebuild','test-without-building','-xctestrun',str(config),'-destination',f'platform=iOS Simulator,id={udid}','-parallel-testing-enabled','NO','-only-testing:HeavyBandManagerScreenshotTests/ScreenshotTests/testCoreScreens','-resultBundlePath',str(result)])
  run(['xcrun','xcresulttool','export','attachments','--path',str(result),'--output-path',str(attachments)])
  run([python,str(repo/'scripts/export-marketing-sources.py'),'--attachments',str(attachments),'--result',str(result),'--device',device,'--output',str(a.output_root),'--app',str(products/'Debug-iphonesimulator/HeavyBandManager.app'),'--band',a.band]+(['--story'] if a.story else []))
  print(f'Captured selected {device} sources.',flush=True)
finally:config.unlink(missing_ok=True)
print(f'Native sources ready for composition: {a.output_root}')
