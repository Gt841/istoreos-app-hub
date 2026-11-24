#!/usr/bin/env python3
"""Install only provenance-checked real packages on the explicitly named test host."""
import argparse,hashlib,io,json,re,shlex,subprocess,tarfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('host',choices=['192.168.30.7','192.168.30.93']);p.add_argument('--audit',type=Path,required=True);p.add_argument('--source-audit',type=Path,required=True);p.add_argument('--destination',required=True);p.add_argument('--expected-boot',required=True);p.add_argument('--expect-storage',default='');p.add_argument('--evidence',type=Path,required=True);a=p.parse_args()
audit=json.loads(a.audit.read_text());source=json.loads(a.source_audit.read_text());assert audit['passed']and source['passed'];assert source['build_id']in a.destination and re.fullmatch(r'/mnt/[A-Za-z0-9_./-]+',a.destination) and '..'not in a.destination.split('/')
q=shlex.quote
log={}
def ssh(command,input=None):
 try:return subprocess.run(['ssh','root@'+a.host,command],input=input,text=True,capture_output=True,check=True).stdout
 except subprocess.CalledProcessError as error:
  log['failed_command']={'command':command,'stdout':error.stdout,'stderr':error.stderr,'exit_code':error.returncode}
  a.evidence.parent.mkdir(parents=True,exist_ok=True);a.evidence.write_text(json.dumps({'status':'failed','host':a.host,'build_id':source['build_id'],'log':log},indent=2)+'\n')
  raise
assert ssh('cat /proc/sys/kernel/random/boot_id').strip()==a.expected_boot
log['before']=ssh('opkg list-installed')
installed={line.split(' - ')[0]for line in log['before'].splitlines()}
packages=audit['packages'];assert len(packages)==5
for package in packages.values():
 for dependency in package['metadata'].get('Depends','').split(', '):
  name=dependency.split(' ')[0];assert name in installed or name in packages,'missing dependency: '+name
 path=Path(package['file']);assert hashlib.sha256(path.read_bytes()).hexdigest()==package['sha256'];assert source['build_id']in path.parts
available=int(ssh("df -Pk /overlay | awk 'NR==2{print $4}'").strip())*1024
required=2*sum(int(package['metadata'].get('Installed-Size',0))for package in packages.values())+20*1024*1024
assert available>required,(available,required)
log['overlay_free_bytes']=available;log['overlay_required_bytes']=required
ssh('test ! -e '+q(a.destination)+' && mkdir -m 700 -p '+q(a.destination))
files=[];sums=[]
for name in('mise','ks-cli','mise-runtime','luci-app-mise','app-meta-mise'):
 package=packages[name];path=Path(package['file']);target=a.destination+'/'+path.name
 subprocess.run(['scp',str(path),'root@'+a.host+':'+target],check=True,capture_output=True)
 files.append(target);sums.append(package['sha256']+'  '+path.name)
log['sha256']=ssh('cd '+q(a.destination)+' && sha256sum -c -',input='\n'.join(sums)+'\n')
command='opkg --noaction --force-reinstall install '+' '.join(map(q,files));log['dry_run']=ssh(command)
a.evidence.parent.mkdir(parents=True,exist_ok=True)
# Persist the pre-install record even if opkg fails partway through.
a.evidence.write_text(json.dumps({'status':'installing','host':a.host,'build_id':source['build_id'],'log':log},indent=2)+'\n')
try:
 log['install']=ssh('opkg --force-reinstall install '+' '.join(map(q,files)))
 log['after']=ssh('opkg list-installed')
 expected_files=[]
 for package in packages.values():
  package_path=Path(package['file'])
  if tarfile.is_tarfile(package_path):
   with tarfile.open(package_path)as outer:payload=next(outer.extractfile(member).read()for member in outer if member.name.removeprefix('./').startswith('data.tar'))
  else:
   member=next(name for name in subprocess.check_output(['ar','t',str(package_path)],text=True).splitlines()if name.startswith('data.tar'));payload=subprocess.check_output(['ar','p',str(package_path),member])
  with tarfile.open(fileobj=io.BytesIO(payload))as data:
   for member in data:
    name=member.name.removeprefix('./')
    if member.isfile()and not name.startswith('etc/'):
     expected_files.append(hashlib.sha256(data.extractfile(member).read()).hexdigest()+'  /'+name)
 log['installed_file_sha256']=ssh('sha256sum -c -',input='\n'.join(expected_files)+'\n')
 log['installed_files_verified']=len(expected_files)

 actual=dict(line.split(' - ',1)for line in log['after'].splitlines()if' - 'in line)
 for name,package in packages.items():assert actual[name]==package['metadata']['Version'],(name,actual[name])
 log['registry']=ssh('readlink /usr/share/linkease/apps.d/40-mise.json; readlink /usr/share/linkeasefull/desktop-apps.d/40-mise.json')
 assert log['registry'].splitlines()==['/usr/share/mise/mise-plugin.json']*2
 log['cli']=ssh("printf '%s' '{\"op\":\"read\"}' | /usr/sbin/mise-runtime request")
 state=json.loads(log['cli']);assert state['ok']and state['value']['path']==a.expect_storage
 assert ssh('cat /proc/sys/kernel/random/boot_id').strip()==a.expected_boot
 a.evidence.write_text(json.dumps({'status':'passed','host':a.host,'build_id':source['build_id'],'log':log},indent=2)+'\n')
 print('five audited packages installed; exact versions, both registrations and backend storage state verified')
except Exception:
 a.evidence.write_text(json.dumps({'status':'failed','host':a.host,'build_id':source['build_id'],'log':log},indent=2)+'\n');raise
