#!/usr/bin/env python3
"""Provision the missing x64 test-host iStoreEnhance backend without a package build.

Refuses existing installations. Uses the exact official binary pinned by the
iStoreEnhance package; the ARM host's existing service is never changed.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shlex
import subprocess
import tarfile

HUB = Path(__file__).resolve().parents[3]
BINARY_SHA = '0c555344a635028ac38ad2ab3ef2d110855f7b7f60f39f8db990e70ae5e3ba1d'
STAGE = '/mnt/mise-runtime/acceptance/M7-local-istoreenhance'
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--binary', type=Path, required=True)
p.add_argument('--evidence', type=Path, required=True)
a = p.parse_args()
binary = a.binary.read_bytes()
assert hashlib.sha256(binary).hexdigest() == BINARY_SHA
assert binary[:4] == b'\x7fELF' and int.from_bytes(binary[18:20], 'little') == 62
config = ("config istoreenhance\n\toption enabled '1'\n\toption port '5443'\n"
          "\toption adminport '5003'\n\toption cache '" + STAGE + "/cache'\n").encode()
files = [('/usr/sbin/iStoreEnhance', binary, 0o755),
         ('/etc/init.d/istoreenhance', (HUB/'apps/istoreenhance/istoreenhance/files/istoreenhance.init').read_bytes(), 0o755),
         ('/etc/config/istoreenhance', config, 0o600)]
manifest = {'host': '192.168.30.7', 'stage': STAGE, 'version': '0.9.1',
            'mode': 'direct-test-files', 'package_database_modified': False,
            'official_archive_sha256': 'd117d3529ce4ae170f7ba284ce89112535337c97ce86997275b93dcf373b0ce9',
            'files': [{'target': path, 'key': str(i), 'sha256': hashlib.sha256(data).hexdigest(), 'mode': mode}
                      for i, (path, data, mode) in enumerate(files)],
            'rollback': 'lua ' + STAGE + '/apply.lua rollback ' + STAGE}
script = r'''package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs=s.fs
local action,base=arg[1],arg[2];local m=assert(s.decode(base..'/manifest.json'))
assert(s.nixio.uname().machine=='x86_64');require('store').filesystem(base)
if action=='apply'then
 for _,r in ipairs(m.files)do
  assert(not fs.lstat(r.target),'Existing installation must be preserved: '..r.target)
  assert(s.sha(base..'/'..r.key,base)==r.sha256)
 end
 for _,port in ipairs({5443,5003})do
  local sock=assert(s.nixio.socket('inet','stream'))
  assert(sock:bind('127.0.0.1',port),'Port in use');sock:close()
 end
 assert(not fs.lstat('/etc/rc.d/S99istoreenhance'))
 for _,r in ipairs(m.files)do
  s.write(r.target,s.read(base..'/'..r.key),r.mode)
  assert(fs.chmod(r.target,string.format('%o',r.mode)))
  assert(s.sha(r.target,base)==r.sha256)
 end
 assert(s.run({'/etc/init.d/istoreenhance','enable'},{output=base..'/enable.log'})==0)
 assert(s.run({'/etc/init.d/istoreenhance','start'},{output=base..'/start.log'})==0)
 print('Local iStoreEnhance service provisioned; package database unchanged')
elseif action=='rollback'then
 for _,r in ipairs(m.files)do assert(s.sha(r.target,base)==r.sha256,'Changed since deployment: '..r.target)end
 assert(fs.readlink('/etc/rc.d/S99istoreenhance')=='../init.d/istoreenhance')
 assert(s.run({'/etc/init.d/istoreenhance','stop'},{output=base..'/stop.log'})==0)
 assert(s.run({'/etc/init.d/istoreenhance','disable'},{output=base..'/disable.log'})==0)
 for _,r in ipairs(m.files)do assert(fs.unlink(r.target))end
 print('Owned test service files removed; persistent cache/evidence retained')
else error('Invalid action')end
'''

def ssh(command, data=None):
    return subprocess.run(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10',
                           'root@192.168.30.7', command], input=data, capture_output=True, check=True)

q = shlex.quote
prepare = ("package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path;local s=require('system');"
           "local p=" + json.dumps(STAGE) + ";require('store').filesystem(p);assert(not s.fs.lstat(p));s.mkdir(p,448)")
ssh('lua -e ' + q(prepare))
payload = io.BytesIO()
with tarfile.open(fileobj=payload, mode='w:gz') as archive:
    for name, data in [('manifest.json', (json.dumps(manifest, indent=2)+'\n').encode()),
                       ('apply.lua', script.encode())] + [(str(i), data) for i, (_, data, _) in enumerate(files)]:
        member = tarfile.TarInfo(name)
        member.size = len(data)
        member.mode = 0o600
        archive.addfile(member, io.BytesIO(data))
ssh('tar -xz --no-same-owner -C ' + q(STAGE), payload.getvalue())
a.evidence.parent.mkdir(parents=True, exist_ok=True)
a.evidence.write_text(json.dumps(manifest, indent=2)+'\n')
result = ssh('lua ' + q(STAGE+'/apply.lua') + ' apply ' + q(STAGE))
manifest['applied'] = True
a.evidence.write_text(json.dumps(manifest, indent=2)+'\n')
print(result.stdout.decode().strip())
