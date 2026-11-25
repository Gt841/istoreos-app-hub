#!/usr/bin/env python3
"""Deploy explicit development files to the two authorized test hosts.

No IPK/APK build, package DB edit or SDK/data copying. Backups stay private on
the target disk; evidence contains only paths, modes and SHA256, never secrets.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import shlex
import subprocess
import tarfile

HUB=Path(__file__).resolve().parents[3]
HOSTS={
 '192.168.30.7':('x86_64','/mnt/mise-runtime/acceptance'),
 '192.168.30.93':('aarch64','/mnt/nvme0n1-1/Configs/mise-runtime-acceptance-20261123'),
}
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('host',choices=HOSTS)
p.add_argument('--label',required=True)
p.add_argument('--exec-user',required=True,type=Path)
p.add_argument('--python-launch-musl',type=Path)
p.add_argument('--python-launch-glibc',type=Path)
p.add_argument('--with-openclaw',action='store_true')
p.add_argument('--evidence',required=True,type=Path)
a=p.parse_args()
assert re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*',a.label)
arch,base=HOSTS[a.host]
stage=base+'/direct-deploy/'+a.label
records=[]
def add(source,target,mode=None,config=False):
 if source.is_symlink():return
 assert source.is_file(),source
 data=source.read_bytes()
 records.append({'source':str(source.relative_to(HUB))if source.is_relative_to(HUB)else str(source),
  'target':target,'mode':mode if mode is not None else (source.stat().st_mode&0o777),
  'config':config,'sha256':hashlib.sha256(data).hexdigest(),'payload':data})
core=HUB/'apps/mise/mise-runtime/files'
for source in sorted(core.rglob('*')):
 if not source.is_file() or '__pycache__' in source.parts or source.suffix=='.pyc':continue
 name=str(source.relative_to(core))
 target='/usr/sbin/mise-runtime'if name=='mise-runtime'else'/usr/share/mise-runtime/'+name
 mode=0o755 if name in ('mise-runtime','main.lua','execute.lua')or name.startswith('native/bin/')else 0o644
 add(source,target,mode)
for name,source in [('exec-user',a.exec_user),('python-launch-musl',a.python_launch_musl),('python-launch-glibc',a.python_launch_glibc)]:
 if source is None:continue
 elf=source.read_bytes()
 assert elf[:4]==b'\x7fELF'and int.from_bytes(elf[18:20],'little')==(62 if arch=='x86_64'else 183),'wrong helper ELF architecture: '+name
 add(source,'/usr/share/mise-runtime/native/bin/'+name,0o755)
legacy=HUB/'apps/mise/mise/files'
for name,target,mode in [('mise.sh','/lib/functions/mise.sh',0o644),
                         ('mise-istore','/usr/sbin/mise-istore',0o755),
                         ('mise-exec','/usr/sbin/mise-exec',0o755)]:
 add(legacy/name,target,mode)
apps=['mise']+(['openclawmgr']if a.with_openclaw else [])
for app in apps:
 package=HUB/'apps'/app/('luci-app-'+app)
 for source in sorted((package/'luasrc').rglob('*')):
  if source.is_file():add(source,'/usr/lib/lua/luci/'+str(source.relative_to(package/'luasrc')),0o644)
 for source in sorted((package/'htdocs').rglob('*')):
  if source.is_file():add(source,'/www/'+str(source.relative_to(package/'htdocs')),0o644)
 for source in sorted((package/'root').rglob('*')):
  if not source.is_file()or source.is_symlink():continue
  name=str(source.relative_to(package/'root'))
  if name.startswith('etc/uci-defaults/'):continue
  # Git tracks the executable bit, not the developer checkout's group umask.
  # Match installation modes instead of copying group-writable source modes.
  mode=0o600 if name.startswith('etc/config/')else(0o755 if source.stat().st_mode&0o111 else 0o644)
  add(source,'/'+name,mode,name.startswith('etc/config/'))
assert len({r['target']for r in records})==len(records)
for index,r in enumerate(records):r['key']=f'{index:04d}'
manifest={'schema_version':1,'mode':'direct-file-development','host':a.host,'arch':arch,'stage':stage,
 'label':a.label,'files':[{k:v for k,v in r.items()if k!='payload'}for r in records],
 'package_database_modified':False,'SDK_or_application_data_copied':False}

APPLY=r'''package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local store=require('store');local fs=s.fs
local action,base=arg[1],arg[2]
local manifest=s.decode(base..'/manifest.json');assert(manifest.arch==s.nixio.uname().machine)
store.filesystem(base)
local function safe(path)
 assert(path:sub(1,1)=='/'and not path:find('[%c]')and not path:find('/../',1,true))
 local parent=path:match('^(.*)/[^/]+$');local current=''
 for part in parent:gmatch('[^/]+')do
  current=current..'/'..part;local st=fs.lstat(current)
  assert(not st or st.type=='dir','refusing non-directory/symlink parent: '..current)
 end
end
if action=='apply'then
 s.mkdir(base..'/before',448);s.mkdir(base..'/work',448)
 local plan={schema_version=1,boot_id=s.boot_id(),files={}}
 -- Validate and save all previous bytes before the first target mutation.
 for _,r in ipairs(manifest.files)do
  safe(r.target);local st=fs.lstat(r.target)
  local item={target=r.target,key=r.key,config=r.config,mode=r.mode,sha256=r.sha256}
  if r.config and st then item.action='preserve-config'
  else
   assert(not st or st.type=='reg','refusing non-regular target: '..r.target)
   assert(s.sha(base..'/payload/'..r.key,base..'/work')==r.sha256,'staging checksum mismatch')
   item.before=st and{mode=st.modedec,uid=st.uid,gid=st.gid,sha256=s.sha(r.target,base..'/work')}or nil
   if st and item.before.sha256==r.sha256 and tonumber(tostring(st.modedec),8)==r.mode then item.action='unchanged'
   else
    item.action='update'
    if st then s.write(base..'/before/'..r.key,s.read(r.target),384)end
   end
  end
  plan.files[#plan.files+1]=item
 end
 s.write(base..'/before-index.json',plan)
 for _,item in ipairs(plan.files)do
  if item.action=='update'then
   s.mkdir(item.target:match('^(.*)/[^/]+$'),493)
   s.write(item.target,s.read(base..'/payload/'..item.key),item.mode)
   assert(fs.chmod(item.target,string.format('%o',item.mode)))
   assert(s.sha(item.target,base..'/work')==item.sha256)
  end
 end
 plan.applied=true;s.write(base..'/result.json',plan);print(s.json.stringify(plan))
elseif action=='restore'then
 local plan=s.decode(base..'/before-index.json');assert(plan)
 for i=#plan.files,1,-1 do
  local item=plan.files[i]
  if item.action=='update'and not item.config then
   safe(item.target)
   assert(s.sha(item.target,base..'/work')==item.sha256,'target changed since deployment; preserve it: '..item.target)
   if item.before then
    assert(s.sha(base..'/before/'..item.key,base..'/work')==item.before.sha256)
    s.write(item.target,s.read(base..'/before/'..item.key),tonumber(tostring(item.before.mode),8))
    assert(fs.chmod(item.target,tostring(item.before.mode)))
    assert(fs.chown(item.target,item.before.uid,item.before.gid))
   else assert(fs.unlink(item.target))end
  end
 end
 print('Code restored; configuration, accounts and runtime/application data retained')
else error('unknown deployment operation')end
'''
def ssh(command,input=None):
 return subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=10','root@'+a.host,command],input=input,capture_output=True,check=True)
q=shlex.quote
# Validate the persistent staging disk before mkdir, not after an overlay fallback.
prepare="package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path;local s=require('system');local t="+json.dumps(stage)+";assert(not s.fs.lstat(t));require('store').filesystem(t);s.mkdir(t,448)"
ssh('lua -e '+q(prepare))
archive=io.BytesIO()
with tarfile.open(fileobj=archive,mode='w:gz')as tar:
 def entry(name,data,mode=0o600):
  member=tarfile.TarInfo(name);member.size=len(data);member.mode=mode;tar.addfile(member,io.BytesIO(data))
 entry('manifest.json',(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode())
 entry('apply.lua',APPLY.encode())
 if a.with_openclaw:entry('bootstrap-openclawmgr.sh',(HUB/'apps/openclawmgr/luci-app-openclawmgr/root/etc/uci-defaults/99-openclawmgr').read_bytes())
 for r in records:entry('payload/'+r['key'],r['payload'])
ssh('tar -xz --no-same-owner -C '+q(stage),input=archive.getvalue())
result=ssh('lua '+q(stage+'/apply.lua')+' apply '+q(stage))
report=json.loads(result.stdout)
manifest['result']=report
manifest['rollback']='lua '+stage+'/apply.lua restore '+stage
a.evidence.parent.mkdir(parents=True,exist_ok=True)
a.evidence.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
if a.with_openclaw:
 result=ssh('/bin/sh '+q(stage+'/bootstrap-openclawmgr.sh'))
 manifest['account_bootstrap_exit']=result.returncode
ssh('rm -f /tmp/luci-indexcache /tmp/luci-indexcache.*; rm -rf /tmp/luci-modulecache; /etc/init.d/rpcd reload >/dev/null 2>&1')
manifest['completed']=True
a.evidence.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'host':a.host,'files':len(records),'updated':sum(x['action']=='update'for x in report['files']),
 'unchanged':sum(x['action']=='unchanged'for x in report['files']),'rollback':manifest['rollback'],'mode':manifest['mode']}))
