#!/usr/bin/env python3
"""Read-only byte/mode audit against a previous direct-deployment manifest."""
import argparse
import json
from pathlib import Path
import shlex
import subprocess
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('deployment',type=Path);p.add_argument('evidence',type=Path);a=p.parse_args()
manifest=json.loads(a.deployment.read_text())
assert manifest['host']in ('192.168.30.7','192.168.30.93')
code="""package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local m=s.json.parse(io.read('*a'));local work=m.stage..'/audit';s.mkdir(work,448)
local results={};local preserved=0
for _,r in ipairs(m.files)do
 if r.config then preserved=preserved+1
 else
  local st=s.fs.lstat(r.target)
  local ok=st and st.type=='reg'and st.uid==0 and tonumber(tostring(st.modedec),8)==r.mode and s.sha(r.target,work)==r.sha256
  results[#results+1]={target=r.target,passed=not not ok};assert(ok,'Direct file differs: '..r.target)
 end
end
print(s.json.stringify({passed=true,arch=s.nixio.uname().machine,boot_id=s.boot_id(),files=results,configs_preserved=preserved,scope='exact bytes/modes from explicit development deployment; not package ownership/dependency verification'}))
"""
r=subprocess.run(['ssh','-o','BatchMode=yes','root@'+manifest['host'],'lua -e '+shlex.quote(code)],input=json.dumps(manifest).encode(),capture_output=True)
if r.returncode:raise SystemExit(r.stderr.decode().strip())
result=json.loads(r.stdout);a.evidence.parent.mkdir(parents=True,exist_ok=True);a.evidence.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'host':manifest['host'],'passed':result['passed'],'files_verified':len(result['files']),'configs_preserved':result['configs_preserved']}))
