import os, subprocess, time
from pathlib import Path
out=Path(os.environ['CI_OUTPUT']); udid=os.environ['TVOS_SIM_UDID']; app='com.seanjseymour.yatteeprofiles'
for name, extra in [('home', {}), ('search', {'YATTEE_FOCUS_UI_SEARCH':'1'}), ('settings', {'YATTEE_FOCUS_UI_SETTINGS':'1'})]:
    subprocess.run(['xcrun','simctl','terminate',udid,app], capture_output=True)
    env=os.environ.copy()
    flags={'YATTEE_FOCUS_UI_ITEMS':'1','YATTEE_FOCUS_UI_SETTINGS':'0','YATTEE_FOCUS_UI_SEARCH':'0','YATTEE_FOCUS_UI_SOURCES':'0','YATTEE_FOCUS_UI_VIEWER_NAME':'Alpha','YATTEE_HISTORY_SMOKE':'0',**extra}
    env.update({'SIMCTL_CHILD_'+k:v for k,v in flags.items()})
    with (out / (name+'-launch.log')).open('w') as log:
        subprocess.run(['xcrun','simctl','launch',udid,app,'-AppleLanguages','(en)','-AppleLocale','en_US'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=45)
    time.sleep(8)
    subprocess.run(['xcrun','simctl','io',udid,'screenshot',str(out/(name+'-standalone.png'))],check=True,timeout=30)
subprocess.run(['xcrun','simctl','terminate',udid,app],capture_output=True)
