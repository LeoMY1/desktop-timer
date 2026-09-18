from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import tempfile
import zipfile

root = Path(__file__).resolve().parents[1]
out = root / 'outputs/P5-v1'
evidence = out / 'evidence'
evidence.mkdir(parents=True, exist_ok=True)
reports = {
    'core-checks.json': 'core/core-checks.json',
    'geometry-checks.json': 'geometry-checks.json',
    'ui-checks.json': 'ui/ui-checks.json',
    'process-checks.json': 'process/process-checks.json',
    'release-boundary.json': 'release-boundary.json',
    'upgrade-compatibility.json': 'upgrade-compatibility.json',
    'native-final.json': 'native-final.json',
}
for name, relative in reports.items():
    source = root / 'work/p5-evidence' / relative
    assert json.loads(source.read_text())['allPassed'], source
    shutil.copy2(source, evidence / name)
for source in (root / 'work/p5-evidence/ui').glob('*.png'):
    shutil.copy2(source, evidence / source.name)
for name in ['user-guide.md', 'p5-testing.md', 'p5-self-test.md']:
    shutil.copy2(root / 'docs' / name, out / name)
staging_parent = Path(tempfile.mkdtemp(prefix='package-', dir=root / 'work/p5-build'))
staging = staging_parent / 'StudyTimer-1.0.0'
staging.mkdir()
shutil.copytree(out / 'StudyTimer.app', staging / 'StudyTimer.app')
for name in ['user-guide.md', 'p5-testing.md', 'p5-self-test.md']:
    shutil.copy2(out / name, staging / name)
shutil.copytree(evidence, staging / 'evidence')
app_zip = out / 'StudyTimer-1.0.0-arm64.zip'
subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(staging), str(app_zip)], check=True)
source_zip = out / 'StudyTimer-1.0.0-source.zip'
with zipfile.ZipFile(source_zip, 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in ['AGENTS.md', 'README.md', 'Package.swift', '.gitignore', 'Sources', 'Tests', 'scripts', 'resources', 'docs', 'design']:
        item = root / name
        for file in sorted(item.rglob('*') if item.is_dir() else [item]):
            if file.is_file() and file.name != '.DS_Store':
                archive.write(file, Path('StudyTimer-1.0.0-source') / file.relative_to(root))
for path in [source_zip, app_zip]:
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None
        assert not any(name.endswith('study.sqlite3') for name in archive.namelist())
        if path == source_zip:
            assert sum(name.endswith('/AGENTS.md') for name in archive.namelist()) == 1
        else:
            assert not any(name.endswith('.command') or 'StudyTimer-Checks.app' in name for name in archive.namelist())
verify = Path(tempfile.mkdtemp(prefix='unzip-', dir=root / 'work/p5-build'))
subprocess.run(['ditto', '-x', '-k', str(app_zip), str(verify)], check=True)
app = verify / 'StudyTimer-1.0.0/StudyTimer.app'
subprocess.run(['codesign', '--verify', '--strict', '--verbose=2', str(app)], check=True)
assert (app / 'Contents/MacOS/StudyTimer').stat().st_mode & 0o111
assert (app / 'Contents/MacOS/StudyTimer').read_bytes() == (out / 'StudyTimer.app/Contents/MacOS/StudyTimer').read_bytes()
report = {'allPassed': True, 'checks': ['ZIP CRCs valid', 'One root AGENTS in source', 'No user/test databases in archives', 'No test launcher or internal app in daily package', 'Extracted application signature valid', 'Extracted executable permissions and bytes retained']}
(evidence / 'package-checks.json').write_text(json.dumps(report, indent=2))
# Include the verification report in the daily package, then verify archive integrity again.
shutil.copy2(evidence / 'package-checks.json', staging / 'evidence/package-checks.json')
subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(staging), str(app_zip)], check=True)
with zipfile.ZipFile(app_zip) as archive:
    assert archive.testzip() is None
(out / 'SHA256.json').write_text(json.dumps({path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in [app_zip, source_zip]}, indent=2))
print(out)
