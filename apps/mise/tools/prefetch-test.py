#!/usr/bin/env python3
"""Prefetch pinned raw archives on the developer SSD, verify, then seed test cache.

This never installs/copies an SDK, library or receipt. Actual target installation
and probes still run through mise-runtime. Evidence distinguishes cache seeding
from a successful on-device origin/ks-cli network download.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import time
import uuid

HUB=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('host',choices=['192.168.30.7','192.168.30.93'])
p.add_argument('--target',required=True)
p.add_argument('--tools',nargs='+',choices=['python','go','zig','rust','java'],required=True)
p.add_argument('--evidence',type=Path,required=True)
a=p.parse_args()
work=Path(os.environ['BUILD_CACHE_WORK_DIR']).resolve()
assert work.is_relative_to('/var/cache/build-cache')
cache=work/'raw-runtime-archives';cache.mkdir(parents=True,exist_ok=True)
catalog_path=HUB/'apps/mise/mise-runtime/files/catalog.json'
catalog=json.loads(catalog_path.read_text())
q=shlex.quote
def ssh(command,stdin=None):
 return subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=10','root@'+a.host,command],stdin=stdin,capture_output=True,check=True)
arch=ssh('uname -m').stdout.decode().strip()
assert arch in ('x86_64','aarch64')
remote_sha=ssh('sha256sum /usr/share/mise-runtime/catalog.json').stdout.decode().split()[0]
assert remote_sha==hashlib.sha256(catalog_path.read_bytes()).hexdigest(),'Device catalog differs; deploy current catalog first'
artifacts={}
for entry in catalog['entries']:
 if entry['tool']in a.tools and entry['arch']==arch and entry['availability']=='available':
  for artifact in entry['artifacts']:
   item=artifacts.setdefault(artifact['sha256'],{**artifact,'entries':[]})
   item['entries'].append(entry['id'])
assert artifacts
report={'schema_version':1,'host':a.host,'arch':arch,'target':a.target,'tools':a.tools,
 'catalog_sha256':remote_sha,'scope':'developer-origin download and verified raw archive transfer only; SDK installation and target network acceptance separate',
 'artifacts':[],'passed':False}
def save():
 a.evidence.parent.mkdir(parents=True,exist_ok=True)
 a.evidence.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
def digest(file):
 h=hashlib.sha256()
 with file.open('rb')as stream:
  for chunk in iter(lambda:stream.read(1024*1024),b''):h.update(chunk)
 return h.hexdigest()
def download(item):
 file=cache/item['sha256'];reused=file.is_file()and not file.is_symlink()and digest(file)==item['sha256']
 if not reused:
  assert not file.is_symlink()
  part=cache/(item['sha256']+'.part.'+uuid.uuid4().hex)
  try:
   subprocess.run(['curl','--disable','-fsSL','--connect-timeout','15','--max-time','300','--retry','2','-o',str(part),item['url']],check=True,capture_output=True)
   assert digest(part)==item['sha256'],'Origin archive digest mismatch: '+item['url']
   part.replace(file)
  finally:part.unlink(missing_ok=True)
 size=file.stat().st_size
 assert not item.get('bytes')or item['bytes']==size,'Origin archive size mismatch'
 return file,{**item,'bytes':size,'developer_cache_reused':reused}
stage=a.target+'/work/prefetch-'+uuid.uuid4().hex
PREP="""package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local store=require('store');local root,stage,size=os.getenv('PREFETCH_ROOT'),os.getenv('PREFETCH_STAGE'),tonumber(os.getenv('PREFETCH_BYTES'));require('contract').path(root)
store.validate(root,size+2*1024*1024*1024,30000);s.mkdir(stage,448);assert(s.fs.realpath(stage)==stage and s.fs.stat(stage).uid==0)
"""
VERIFY="""package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local root,stage,hash,size=os.getenv('PREFETCH_ROOT'),os.getenv('PREFETCH_STAGE'),os.getenv('PREFETCH_SHA256'),tonumber(os.getenv('PREFETCH_BYTES'));require('store').validate(root)
require('contract').digest(hash);local file=stage..'/'..hash;assert(s.fs.lstat(file).type=='reg'and s.fs.stat(file).size==size and s.sha(file,stage)==hash)
local target=root..'/cache/'..hash;local old=s.fs.lstat(target);assert(not old or old.type=='reg','Unsafe cache target')
assert(s.fs.rename(file,target));assert(s.sha(target,stage)==hash)
"""
save()
try:
 with ThreadPoolExecutor(max_workers=2)as pool:
  futures=[pool.submit(download,item)for item in artifacts.values()]
  for future in as_completed(futures):
   file,item=future.result()
   environment='env PREFETCH_ROOT='+q(a.target)+' PREFETCH_STAGE='+q(stage)+' PREFETCH_BYTES='+str(item['bytes'])
   ssh(environment+' lua -e '+q(PREP))
   command='set -e\ncat > '+q(stage+'/'+item['sha256'])+'\n'+environment+' PREFETCH_SHA256='+item['sha256']+' lua -e '+q(VERIFY)
   with file.open('rb')as stream:ssh(command,stdin=stream)
   item['target_verified']=True;report['artifacts'].append(item);save()
   print(f"{a.host}: verified raw archive {len(report['artifacts'])}/{len(artifacts)} {item['bytes']} bytes",flush=True)
 ssh('rmdir '+q(stage))
 report['passed']=True;save()
except Exception as error:
 report['error']=str(error);report['preserved_stage']=stage;save();raise
