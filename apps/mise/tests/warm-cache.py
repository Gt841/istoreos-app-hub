#!/usr/bin/env python3
"""Reuse only verified raw M3 archives; never copy an SDK, library or receipt."""
import argparse,json,shlex,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('host');p.add_argument('source');p.add_argument('target');p.add_argument('evidence',type=Path);p.add_argument('--version',default='24.21.0');p.add_argument('--abi',choices=['glibc','musl'],default='glibc');a=p.parse_args()
code="""package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local sys=require('system');local c=require('contract');local store=require('store');local r=sys.json.parse(io.read('*a'));c.path(r.source);c.path(r.target);assert(r.source~=r.target);local ctx=store.open(r.target);assert(not sys.fs.lstat(r.target..'/.lock'));local arch=sys.nixio.uname().machine;local lib=require('libraries').definition(arch);local artifacts={lib.libc,lib.gcc};local catalog=assert(sys.decode('/usr/share/mise-runtime/catalog.json'))
for _,e in ipairs(catalog.entries)do if e.tool=='node'and e.version==r.version and e.arch==arch and e.abi==r.abi and #e.artifacts==1 then artifacts[#artifacts+1]=e.artifacts[1];break end end
assert(#artifacts==3);local work=r.target..'/work/m4-warm-'..sys.nixio.getpid();sys.mkdir(work,448);local results={}
for _,artifact in ipairs(artifacts)do
 local source=r.source..'/cache/'..artifact.sha256;local target=r.target..'/cache/'..artifact.sha256
 assert(sys.fs.lstat(source).type=='reg'and sys.sha(source,work)==artifact.sha256)
 if not sys.fs.lstat(target)then assert(sys.run({'cp','--',source,work..'/payload'})==0);assert(sys.sha(work..'/payload',work)==artifact.sha256);assert(sys.fs.rename(work..'/payload',target))else assert(sys.fs.lstat(target).type=='reg'and sys.sha(target,work)==artifact.sha256)end
 results[#results+1]={sha256=artifact.sha256,bytes=sys.fs.stat(target).size}
end
sys.remove(work);io.write(sys.json.stringify({scope='verified raw archives only; fresh package-managed SDK and library installation still required',source=r.source,target=r.target,artifacts=results}))
"""
raw=subprocess.check_output(['ssh','root@'+a.host,'lua -e '+shlex.quote(code)],input=json.dumps({'source':a.source,'target':a.target,'version':a.version,'abi':a.abi}).encode())
value=json.loads(raw);a.evidence.parent.mkdir(parents=True,exist_ok=True);a.evidence.write_text(json.dumps(value,indent=2)+'\n');print('three raw archives verified and reused; no installed payload copied')
