from pathlib import Path
import subprocess,hashlib,json
candidate='7563cac5276b8926a98e4fc665a1bdb54fd89135'
tree='53f3e3f7c18f0e62fcf68ac9ee19fdb8a0b6cc47'
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
print('Full production source tree matches local candidate cc2b4ad6:',tree)
print('Remote mirror commit:',candidate)
print('Harness commit:',subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip())
print('Five audited fixture-only deltas:',sorted(allowed))
print(subprocess.check_output(['git','diff',candidate,'HEAD','--',*sorted(allowed)],text=True))
