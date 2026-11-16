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
# Each scenario saves its own failure and continues. A state assertion must
# never suppress remaining theme/mode screenshots. Exit nonzero after coverage.
failures=[]
def scenario(name, action):
    try:
        action()
    except Exception as error:
        failures.append({'scenario':name,'error':repr(error)})
        (out/(name+'-failure.txt')).write_text(repr(error))
        try: command(['xcrun','simctl','io',udid,'screenshot',str(out/(name+'-failure.png'))])
        except Exception: pass

def launch_and_check(theme,mode,screen,items,name,expected):
    launch(theme,mode,screen,items)
    check(expected,name)

# tvOS simctl ui appearance is unsupported on this runtime (exit 45).
# Do not relabel explicit overrides or a launch report as live System proof.
system_coverage={
    'live_system_toggle':'UNPROVEN',
    'reason':'tvOS simulator rejects simctl ui appearance (exit 45); no host toggle executed',
    'opposing_system_override':'UNPROVEN',
    'explicit_light_dark_and_persistence':'covered separately by the scenarios below'
}
(out/'system-coverage.json').write_text(json.dumps(system_coverage,indent=2))

for theme in ['horizon','slate']:
    for mode in ['light','dark']:
        for screen,items in [('home',1),('search',1),('settings',1),('home',0),('home',5)]:
            name=f'{theme}-{mode}-{screen}-{items}'
            scenario(name,lambda:launch_and_check(theme,mode,screen,items,name,f'{theme}|{mode}|{mode}'))
        name=f'{theme}-{mode}-persisted-relaunch'
        scenario(name,lambda:launch_and_check(None,None,'home',1,name,f'{theme}|{mode}|{mode}'))
terminate()
(out/'capture-failures.json').write_text(json.dumps(failures,indent=2))
if failures: raise AssertionError(f'{len(failures)} capture/state scenarios failed; all four looks attempted; see capture-failures.json')
print('All four explicit Light/Dark looks and persisted relaunch assertions passed. Live System toggling and opposing-system overrides remain UNPROVEN; see system-coverage.json.')
