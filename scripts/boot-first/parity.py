from pathlib import Path
import subprocess, hashlib
source=Path('.'); candidate=Path('../candidate')
allowed={
 'Yattee/Core/AppEnvironment.swift',
 'Yattee/Services/CloudKit/CloudKitAvailability.swift',
 'Yattee/Testing/ViewerFocusUITestFixture.swift',
 'Yattee/Testing/ViewerHistorySmokeChecks.swift',
 'Yattee/Views/Home/HomeHorizontalCards.swift',
 'Yattee/Views/Home/HomeView.swift',
}
def paths(root):
    return set(subprocess.check_output(['git','-C',str(root),'ls-files','Yattee','YatteeTopShelf','Yattee.xcodeproj'],text=True).splitlines())
changed=set()
for name in sorted(paths(source)|paths(candidate)):
    a=source/name;b=candidate/name
    if not a.exists() or not b.exists() or a.read_bytes()!=b.read_bytes(): changed.add(name)
assert changed==allowed, f'Unexpected production/harness delta: {changed ^ allowed}'
print('Candidate: c4fe5578dd6624315f5c285539774be4a7b50b9c')
print('Evidence: a5424bc75667bd59e3d9997c937dc3c7c4727a09')
print('Only the six existing fixture/accessibility files differ; other app, Top Shelf and project files byte-identical.')
for name in sorted(allowed): print('EXISTING HARNESS DELTA',name)
for name in ('Yattee/Views/Profiles/TVViewerRoot.swift','Yattee/Views/Navigation/UnifiedTabView.swift','Yattee/Views/Search/SearchView.swift'):
    if (source/name).exists(): print('SHA256',name,hashlib.sha256((source/name).read_bytes()).hexdigest())
