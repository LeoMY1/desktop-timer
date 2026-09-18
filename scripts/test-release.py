from pathlib import Path
import hashlib, json, os, plistlib, subprocess, tempfile
root = Path(__file__).resolve().parents[1]
output = root / 'work/evidence'
output.mkdir(parents=True, exist_ok=True)
app = root / 'outputs/StudyTimer.app'
binary = app / 'Contents/MacOS/StudyTimer'
checks = []
for flag in ['--acceptance-mode', '--ui-check']:
    data = Path(tempfile.mkdtemp(prefix='rejected-mode-', dir=output))
    run = subprocess.run([str(binary), flag], env=dict(os.environ, STUDY_TIMER_DATA_DIR=str(data)), capture_output=True)
    checks.append({'name': flag + ' rejected before opening data', 'passed': run.returncode == 2 and not (data / 'study.sqlite3').exists()})
symbols = subprocess.check_output(['nm', str(binary)]).decode()
checks.append({'name': 'No simulation/check entrypoints', 'passed': all(s not in symbols for s in ['UICheckClock','advanceAcceptance','runUICheck'])})
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
checks.append({'name': 'Stable data identity', 'passed': info['CFBundleIdentifier'] == 'local.study-timer.p4'})
run = subprocess.run(['codesign', '--verify', '--strict', str(app)], capture_output=True)
checks.append({'name': 'Local signature valid', 'passed': run.returncode == 0})
result = {'allPassed': all(c['passed'] for c in checks), 'checks': checks, 'binarySHA256': hashlib.sha256(binary.read_bytes()).hexdigest()}
(output / 'release-checks.json').write_text(json.dumps(result, indent=2))
print(f'Release checks: {sum(c["passed"] for c in checks)}/{len(checks)}')
assert result['allPassed']
