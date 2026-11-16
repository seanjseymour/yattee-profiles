"""Fail closed before installing a pinned, unsigned CI fixture app."""
import hashlib
import json
import os
from pathlib import Path
import re
import urllib.request

RUN = 43827981405
HEAD = '25d6e5197108f93e89784227243bd0d08c3f1e6a'
REPO = 'seanjseymour/yattee-profiles'
out = Path(os.environ['CI_OUTPUT'])

def verify_run():
    request = urllib.request.Request(
        f'https://api.github.com/repos/{REPO}/actions/runs/{RUN}',
        headers={'Authorization': 'Bearer ' + os.environ['GH_TOKEN'],
                 'Accept': 'application/vnd.github+json',
                 'X-GitHub-Api-Version': '2022-11-28'})
    with urllib.request.urlopen(request, timeout=30) as response:
        run = json.load(response)
    (out / 'compile-run.json').write_text(json.dumps(run, indent=2))
    assert run['id'] == RUN
    assert run['repository']['full_name'] == REPO
    assert run['head_sha'] == HEAD
    assert run['head_branch'] == 'validation/horizon-slate-compile-cc2b4ad6'
    assert run['path'] == '.github/workflows/theme-compile.yml'
    assert run['run_attempt'] == 1
    assert run['status'] == 'completed' and run['conclusion'] == 'success'
    print('Verified successful compile run, repository, head, workflow and attempt')

def verify_files():
    inputs = Path(os.environ['APP_ARTIFACT'])
    expected = {
        'production_local_commit': 'cc2b4ad6315dd673c221786a92f85f3079b19417',
        'production_remote_commit': '7563cac5276b8926a98e4fc665a1bdb54fd89135',
        'production_tree': '53f3e3f7c18f0e62fcf68ac9ee19fdb8a0b6cc47',
        'fixture_source_commit': '93e2838b250541e9b5af26d73524dbc79877a5b0',
        'architecture': 'arm64', 'signing': False, 'runtime_tests_executed': False,
    }
    manifest = json.loads((inputs / 'source-manifest.json').read_text())
    assert manifest == expected, manifest
    verified = {}
    for archive, checksum in [('clean-candidate-app.tar.gz', 'clean-app.sha256'),
                              ('synthetic-fixture-app.tar.gz', 'fixture-app.sha256')]:
        line = (inputs / checksum).read_text().strip()
        match = re.fullmatch(r'([a-f0-9]{64})\s+(.+)', line)
        assert match and Path(match[2]).name == archive, checksum
        with (inputs / archive).open('rb') as stream:
            actual = hashlib.file_digest(stream, 'sha256').hexdigest()
        assert actual == match[1], archive
        verified[archive] = actual
    (out / 'verified-app-inputs.json').write_text(json.dumps({'manifest': manifest, 'sha256': verified}, indent=2))
    print('Verified exact source manifest and both app archive SHA-256 hashes')

if __name__ == '__main__':
    import sys
    if sys.argv[1] == 'run':
        verify_run()
    elif sys.argv[1] == 'files':
        verify_files()
    else:
        raise ValueError('Expected run or files')
