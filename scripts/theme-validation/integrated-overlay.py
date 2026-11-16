"""Run from exact clean source checkout; overlay only six audited UI fixtures."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess

source = Path.cwd()
harness = Path(__file__).resolve().parents[2]
out = Path(os.environ['CI_OUTPUT'])
expected_tree = '813d4e815de7e829074d892995e67b2d11832156'
allowed = {
    'Yattee/Core/AppEnvironment.swift',
    'Yattee/Services/CloudKit/CloudKitAvailability.swift',
    'Yattee/Testing/ViewerFocusUITestFixture.swift',
    'Yattee/Testing/ViewerHistorySmokeChecks.swift',
    'Yattee/Views/Profiles/TVViewerRoot.swift',
    'Yattee/Views/Home/TVContinueWatchingShelf.swift',
}
roots = ('Yattee', 'YatteeTests', 'YatteeTopShelf', 'Yattee.xcodeproj')
def git(*args):
    return subprocess.check_output(['git', '-C', str(source), *args], text=True).strip()
assert git('rev-parse', 'HEAD^{tree}') == expected_tree
git('diff', '--exit-code', '--', *roots)
tracked = set(git('ls-files', '--', *roots).splitlines())
harness_files = {str(p.relative_to(harness)) for root in roots
                 for p in (harness/root).rglob('*') if p.is_file()}
changed = {p for p in tracked | harness_files
           if not (source/p).is_file() or not (harness/p).is_file()
           or (source/p).read_bytes() != (harness/p).read_bytes()}
assert changed == allowed, sorted(changed)
manifest = {}
for name in sorted(allowed):
    target = source/name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(harness/name, target)
    manifest[name] = hashlib.sha256(target.read_bytes()).hexdigest()
changed_after = set(git('diff', '--name-only', '--', *roots).splitlines())
changed_after |= set(git('ls-files', '--others', '--exclude-standard', '--', *roots).splitlines())
assert changed_after == allowed, sorted(changed_after)
(out/'fixture-overlay-manifest.json').write_text(json.dumps({'production_tree':expected_tree,'fixture_sha256':manifest},indent=2))
(out/'fixture-overlay.diff').write_text(git('diff', '--', *roots))
print('Exact integrated production parity; only six audited simulator-fixture files changed; tests and project byte-identical')
