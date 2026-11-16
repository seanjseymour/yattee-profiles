import os, subprocess, shutil
from pathlib import Path
out=Path(os.environ['CI_OUTPUT']); out.mkdir(parents=True,exist_ok=True)
commands={
 'final-devices.json':['xcrun','simctl','list','-j'],
 'system.log':['/usr/bin/log','show','--last','20m','--style','compact','--predicate','process CONTAINS "Simulator" OR process == "launchd_sim" OR process == "Yattee"'],
 'runner-processes.log':['ps','-axo','pid,ppid,state,comm'],
}
for name, cmd in commands.items():
    try:
        with (out/name).open('w') as f: subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=35)
    except Exception as e: (out/(name+'.error')).write_text(str(e))
crashes=out/'crashes'; crashes.mkdir(exist_ok=True)
root=Path.home()/'Library/Logs/DiagnosticReports'
for p in root.glob('*'):
    if p.is_file() and any(s in p.name for s in ('Simulator','launchd_sim','Yattee','FocusRemote')):
        shutil.copy2(p, crashes/p.name)
selected=out/'selected-device.json'
if selected.exists():
    import json
    d=json.loads(selected.read_text())['device']
    if d['state'] != 'Booted':
        subprocess.run(['xcrun','simctl','shutdown',d['udid']],capture_output=True,timeout=30)
