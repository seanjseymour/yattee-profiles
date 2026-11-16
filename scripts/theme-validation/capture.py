import os,subprocess,time,json
from pathlib import Path
out=Path(os.environ['CI_OUTPUT']); udid=os.environ['TVOS_SIM_UDID']; app='com.seanjseymour.yatteeprofiles'
def command(args, **kw): return subprocess.run(args,check=True,timeout=40,**kw)
def terminate(): subprocess.run(['xcrun','simctl','terminate',udid,app],capture_output=True,timeout=20)
def launch(theme,mode,screen='home',items=1):
    terminate()
    container=subprocess.check_output(['xcrun','simctl','get_app_container',udid,app,'data'],text=True,timeout=20).strip()
    (Path(container)/'Documents/theme-validation-state.txt').unlink(missing_ok=True)
    flags={'YATTEE_FOCUS_UI_ITEMS':str(items),'YATTEE_FOCUS_UI_SETTINGS':str(int(screen=='settings')),'YATTEE_FOCUS_UI_SEARCH':str(int(screen=='search')),'YATTEE_FOCUS_UI_SOURCES':'0','YATTEE_FOCUS_UI_VIEWER_NAME':'Alexandria Catherine Seymour'}
    if theme is not None: flags['YATTEE_THEME']=theme
    if mode is not None: flags['YATTEE_MODE']=mode
    env=os.environ.copy(); env.update({'SIMCTL_CHILD_'+k:v for k,v in flags.items()})
    with (out/f'{theme}-{mode}-{screen}-{items}-launch.log').open('w') as log:
        command(['xcrun','simctl','launch',udid,app,'-AppleLanguages','(en)','-AppleLocale','en_US'],env=env,stdout=log,stderr=subprocess.STDOUT)
    time.sleep(3)
def report():
    container=subprocess.check_output(['xcrun','simctl','get_app_container',udid,app,'data'],text=True,timeout=20).strip()
    path=Path(container)/'Documents/theme-validation-state.txt'
    return path.read_text().strip()
def check(expected,name):
    for _ in range(25):
        try:
            actual=report()
            if actual==expected: break
        except OSError: actual='missing'
        time.sleep(.4)
    (out/(name+'-state.txt')).write_text(actual)
    command(['xcrun','simctl','io',udid,'screenshot',str(out/(name+'.png'))])
    assert actual==expected,(name,expected,actual)
for theme in ['horizon','slate']:
    for mode in ['light','dark']:
        for screen in ['home','search','settings']:
            launch(theme,mode,screen)
            check(f'{theme}|{mode}|{mode}',f'{theme}-{mode}-{screen}')
        for items in [0,5]:
            launch(theme,mode,items=items)
            check(f'{theme}|{mode}|{mode}',f'{theme}-{mode}-home-{items}')
        launch(None,None)
        check(f'{theme}|{mode}|{mode}',f'{theme}-{mode}-persisted-relaunch')
    command(['xcrun','simctl','ui',udid,'appearance','light'])
    launch(theme,'system')
    check(f'{theme}|system|light',f'{theme}-system-light')
    command(['xcrun','simctl','ui',udid,'appearance','dark'])
    check(f'{theme}|system|dark',f'{theme}-system-live-dark')
    command(['xcrun','simctl','ui',udid,'appearance','light'])
    check(f'{theme}|system|light',f'{theme}-system-live-light')
    launch(theme,'dark')
    check(f'{theme}|dark|dark',f'{theme}-override-dark-on-light-system')
    command(['xcrun','simctl','ui',udid,'appearance','dark'])
    launch(theme,'light')
    check(f'{theme}|light|light',f'{theme}-override-light-on-dark-system')
terminate()
print('All four rendered looks, persisted relaunch and live System inheritance assertions passed')
