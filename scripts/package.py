from pathlib import Path
import hashlib, json, plistlib, shutil, subprocess, tempfile, zipfile

root = Path(__file__).resolve().parents[1]
out = root / 'outputs'
app = out / 'StudyTimer.app'
reports = ['core/core-checks.json', 'geometry-checks.json', 'process/process-checks.json', 'ui/ui-checks.json', 'release-checks.json']
for name in reports:
    path = root / 'work/evidence' / name
    if not path.exists() or not json.loads(path.read_text()).get('allPassed'):
        raise SystemExit('Run bash scripts/test.sh successfully before packaging: ' + name)
release = json.loads((root / 'work/evidence/release-checks.json').read_text())
binary = app / 'Contents/MacOS/StudyTimer'
if release['binarySHA256'] != hashlib.sha256(binary.read_bytes()).hexdigest():
    raise SystemExit('Application changed after verification; rerun scripts/test.sh')
subprocess.run(['codesign', '--verify', '--strict', str(app)], check=True)
version = plistlib.loads((app / 'Contents/Info.plist').read_bytes())['CFBundleShortVersionString']
stage = Path(tempfile.mkdtemp(prefix='package-', dir=root / 'work')) / ('desktop-timer-' + version)
stage.mkdir()
shutil.copytree(app, stage / 'StudyTimer.app')
shutil.copy2(root / 'LICENSE', stage / 'LICENSE')
(stage / 'docs').mkdir()
for name in ['user-guide.md', 'validation.md']:
    shutil.copy2(root / 'docs' / name, stage / 'docs' / name)
(stage / 'evidence').mkdir()
for name in reports:
    shutil.copy2(root / 'work/evidence' / name, stage / 'evidence' / Path(name).name)
app_zip = out / f'desktop-timer-{version}-arm64.zip'
source_zip = out / f'desktop-timer-{version}-source.zip'
subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(stage), str(app_zip)], check=True)
files = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=root).decode().split('\0')
with zipfile.ZipFile(source_zip, 'w', zipfile.ZIP_DEFLATED) as archive:
    for relative in sorted(set(files)):
        file = root / relative
        if relative and file.is_file():
            archive.write(file, Path(f'desktop-timer-{version}-source') / relative)
for path in [app_zip, source_zip]:
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None
        assert not any(n.endswith('study.sqlite3') or '/work/' in n or n.endswith('.command') for n in archive.namelist())
verify = Path(tempfile.mkdtemp(prefix='verify-package-', dir=root / 'work'))
subprocess.run(['ditto', '-x', '-k', str(app_zip), str(verify)], check=True)
subprocess.run(['codesign', '--verify', '--strict', str(verify / stage.name / 'StudyTimer.app')], check=True)
(out / 'SHA256.json').write_text(json.dumps({f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in [app_zip, source_zip]}, indent=2))
print(app_zip)
print(source_zip)
