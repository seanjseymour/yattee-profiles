from pathlib import Path
import subprocess,hashlib,json
candidate='99b6de08b2c994f51bd81eaabc0649a6729c395c'
tree='ab0a550213b591dcc69d57650aeca6b307989ded'
assert subprocess.check_output(['git','rev-parse',candidate+'^{tree}'],text=True).strip()==tree
allowed={
 'Yattee/Core/AppEnvironment.swift',
 'Yattee/Services/CloudKit/CloudKitAvailability.swift',
 'Yattee/Testing/ViewerFocusUITestFixture.swift',
 'Yattee/Views/Profiles/TVViewerRoot.swift',
 'Yattee/Views/Home/TVContinueWatchingShelf.swift',
}
changed=set(subprocess.check_output(['git','diff','--name-only',candidate,'HEAD','--','Yattee','YatteeTests','YatteeTopShelf','Yattee.xcodeproj'],text=True).splitlines())
assert changed==allowed,(changed,allowed)
print('Full production source tree matches local candidate 1cf40497:',tree)
print('Remote mirror commit:',candidate)
print('Harness commit:',subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip())
print('Five audited fixture-only deltas:',sorted(allowed))
print(subprocess.check_output(['git','diff',candidate,'HEAD','--',*sorted(allowed)],text=True))
