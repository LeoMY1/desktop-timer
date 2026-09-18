#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
if [ ! -f work/p3-build/tests/StudyCore.o ]; then bash scripts/test-p3.sh; fi
xcrun swiftc -target arm64-apple-macosx13.0 -I Sources/CSQLite -I work/p3-build/tests Tests/StudyProcessProbe/main.swift work/p3-build/tests/StudyCore.o -o work/p3-build/tests/ProcessProbe
python3 - <<'PY'
from pathlib import Path
import subprocess,json,uuid,time
root=Path.cwd(); out=root/'work/p3-evidence/process'; out.mkdir(parents=True,exist_ok=True)
run=out/str(uuid.uuid4()); run.mkdir()
probe=root/'work/p3-build/tests/ProcessProbe'
live=subprocess.Popen([str(probe),'live',str(run/'normal-data'),str(out/'live-time.json')])
crash=subprocess.run([str(probe),'crash',str(run/'crash-data'),str(out/'before-crash.json')])
time.sleep(1)
subprocess.run([str(probe),'recover',str(run/'crash-data'),str(out/'after-crash.json')],check=True)
before=json.loads((out/'before-crash.json').read_text()); after=json.loads((out/'after-crash.json').read_text())
assert crash.returncode==-9
assert abs(before['savedSeconds']-after['seconds'])<0.0001 and after['phase']=='stopped' and after['endReason']=='interrupted'
assert before['elapsedSeconds']>after['seconds']+2
print('Actual SIGKILL recovery passed.',flush=True)
assert live.wait()==0
subprocess.run([str(probe),'recover',str(run/'normal-data'),str(out/'after-normal-restart.json')],check=True)
normal=json.loads((out/'live-time.json').read_text()); restored=json.loads((out/'after-normal-restart.json').read_text())
assert normal['allPassed'] and abs(normal['totalSeconds']-restored['seconds'])<0.0001 and restored['phase']=='stopped'
(out/'process-checks.json').write_text(json.dumps({'allPassed':True,'checks':['real_65_second_display','real_pause_exclusion','resume_adds_elapsed','normal_restart_no_offline_accrual','SIGKILL_checkpoint_only']},indent=2))
print('Real-time and process checks: 5/5 passed.',flush=True)
PY
