import json, os, subprocess, time
from pathlib import Path
out = Path(os.environ['CI_OUTPUT']); out.mkdir(parents=True, exist_ok=True)
def run(args, name, timeout=30):
    with (out / name).open('w') as f:
        subprocess.run(args, stdout=f, stderr=subprocess.STDOUT, check=True, timeout=timeout)
run(['xcrun', 'simctl', 'list', '-j'], 'simulator-before.json')
data = json.loads((out / 'simulator-before.json').read_text())
runtimes = {r['identifier']: r for r in data['runtimes'] if r.get('isAvailable') and 'tvOS' in r['identifier']}
choices = [(runtimes[r], d) for r, ds in data['devices'].items() if r in runtimes for d in ds if d.get('isAvailable')]
assert choices, 'No available configured tvOS device/runtime pair; stop before build'
choices.sort(key=lambda pair: (pair[1]['state'] == 'Booted', pair[0]['version'] == '27.2', tuple(int(v) for v in pair[0]['version'].split('.'))), reverse=True)
runtime, device = choices[0]; udid = device['udid']
(out / 'selected-device.json').write_text(json.dumps({'runtime': runtime, 'device': device}, indent=2))
(out / 'simulator-id.txt').write_text(udid)
with open(os.environ['GITHUB_ENV'], 'a') as f: f.write('TVOS_SIM_UDID=' + udid + '\n')
print('Selected configured simulator:', device['name'], runtime['version'], device['state'], udid, flush=True)
if device['state'] != 'Booted': run(['xcrun','simctl','boot',udid], 'boot.log')
run(['xcrun','simctl','bootstatus',udid,'-b'], 'bootstatus.log', 180)
for phase in ('initial', 'stable'):
    if phase == 'stable': time.sleep(20)
    run(['xcrun','simctl','list','devices','-j'], phase + '-devices.json')
    devices=json.loads((out / (phase + '-devices.json')).read_text())['devices']
    state=next(d['state'] for ds in devices.values() for d in ds if d['udid']==udid)
    assert state == 'Booted', f'Simulator became {state}; stop before build'
    run(['xcrun','simctl','io',udid,'screenshot',str(out / (phase + '-boot.png'))], phase + '-screenshot.log')
    assert (out / (phase + '-boot.png')).stat().st_size > 1000
print('BOOT GATE PASSED: two screenshots, stable boot for 20 seconds', flush=True)
