#!/usr/bin/env python3
"""Audit actual SDK IPKs before installing on the test devices."""
import argparse,hashlib,io,json,re,subprocess,tarfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--arch',choices=['x86_64','aarch64_generic'],required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
expected={'mise','ks-cli','mise-runtime','luci-app-mise','app-meta-mise'};found={}
def members(path):
 if tarfile.is_tarfile(path):
  with tarfile.open(path)as outer:return{m.name.removeprefix('./'):outer.extractfile(m).read()for m in outer if m.isfile()}
 return{n:subprocess.check_output(['ar','p',str(path),n])for n in subprocess.check_output(['ar','t',str(path)],text=True).splitlines()}
for path in sorted(a.directory.rglob('*.ipk')):
 outer=members(path)
 control=next(v for k,v in outer.items()if k.startswith('control.tar'))
 payload=next(v for k,v in outer.items()if k.startswith('data.tar'))
 with tarfile.open(fileobj=io.BytesIO(control))as c:
  text=next(c.extractfile(m).read().decode()for m in c if m.name.removeprefix('./')=='control')
 metadata=dict(line.split(': ',1)for line in text.splitlines()if ': 'in line and not line.startswith(' '))
 name=metadata['Package'];assert name in expected and name not in found,name
 assert metadata['Architecture']in(a.arch,'all'),metadata
 with tarfile.open(fileobj=io.BytesIO(payload))as t:
  files={m.name.removeprefix('./'):m for m in t}
  def data(name):return t.extractfile(files[name]).read()
  def executable(name):assert files[name].mode&0o111,name
  if name=='mise-runtime':
   for n in('usr/sbin/mise-runtime','usr/share/mise-runtime/main.lua','usr/share/mise-runtime/execute.lua','usr/share/mise-runtime/native/bin/uci'):executable(n)
   for dep in('mise','lua','luci-lib-jsonc','luci-lib-nixio','curl','tar','xz-utils','zstd','ks-cli','coreutils-stat','block-mount'):assert re.search(r'(?:^|, )'+re.escape(dep)+r'(?:[ ,(]|$)',metadata['Depends']),dep
   catalog=json.loads(data('usr/share/mise-runtime/catalog.json'));assert len(catalog['entries'])>=44
  if name=='luci-app-mise':
   link=files['usr/share/linkease/apps.d/40-mise.json'];assert link.issym()and link.linkname=='/usr/share/mise/mise-plugin.json'
   executable('usr/share/mise/register-desktop.sh')
   assert data('www/luci-static/resources/mise/app.js')==Path('apps/mise/luci-app-mise/htdocs/luci-static/resources/mise/app.js').read_bytes()
   assert data('www/luci-static/resources/mise/style.css')==Path('apps/mise/luci-app-mise/htdocs/luci-static/resources/mise/style.css').read_bytes()
   acl=json.loads(data('usr/share/rpcd/acl.d/luci-app-mise.json'));assert 'file'not in acl['luci-app-mise']['write']
   assert 'usr/lib/lua/luci/controller/mise.lua'in files
   assert 'usr/lib/lua/luci/model/mise/transport.lua'in files
  if name=='mise':
   executable('usr/bin/mise');assert re.search(r'2026\.8\.14-(?:r)?26$',metadata['Version']),metadata['Version']
   assert b'MISE_NODE_VERIFY=0'not in data('lib/functions/mise.sh')
   assert data('lib/functions/mise.sh')==Path('apps/mise/mise/files/mise.sh').read_bytes()
   assert data('usr/sbin/mise-istore')==Path('apps/mise/mise/files/mise-istore').read_bytes()
   assert b'storage_root'in data('etc/config/mise')
  if name in('mise','ks-cli'):
   binary=data('usr/bin/'+name);assert binary[:4]==b'\x7fELF';machine=int.from_bytes(binary[18:20],'little');assert machine==(62 if a.arch=='x86_64'else 183)
  if name=='app-meta-mise':
   assert not any(n.startswith(('usr/share/linkease/','usr/share/linkeasefull/')) or (n.startswith('www/') and m.isfile() and not n.startswith('www/luci-static/resources/app-icons/')) for n,m in files.items())
 found[name]={'file':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'metadata':metadata,'files':len(files)}
assert set(found)==expected,(set(found),expected)
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps({'passed':True,'arch':a.arch,'packages':found},indent=2)+'\n');print('five actual IPKs passed metadata, dependencies, payload, modes, registry and architecture audit')
