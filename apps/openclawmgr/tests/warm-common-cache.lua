-- Only content-addressed, verified raw archives are reused from M3 evidence.
-- No SDK, receipt, library installation or application data is copied.
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs=s.fs
local source,target,work=assert(arg[1]),assert(arg[2]),assert(arg[3])
require('store').validate(source);require('store').validate(target);s.mkdir(work,448)
local lib=require('libraries').definition(s.nixio.uname().machine)
local artifacts={lib.libc,lib.gcc}
for _,e in ipairs(s.decode('/usr/share/mise-runtime/catalog.json').entries)do
  if e.tool=='node'and e.version=='24.21.0'and e.npm=='11.12.1'and e.arch==s.nixio.uname().machine and e.abi=='glibc'then
    for _,a in ipairs(e.artifacts)do artifacts[#artifacts+1]=a end;break
  end
end
assert(#artifacts==4)
local results={}
for _,a in ipairs(artifacts)do
  local src,dst=source..'/cache/'..a.sha256,target..'/cache/'..a.sha256
  assert(fs.lstat(src).type=='reg'and s.sha(src,work)==a.sha256,'Invalid/missing raw source archive')
  if fs.lstat(dst)then assert(fs.lstat(dst).type=='reg'and s.sha(dst,work)==a.sha256)
  else
    local part=work..'/'..a.sha256;assert(s.run({'cp','--',src,part})==0)
    assert(s.sha(part,work)==a.sha256);assert(fs.rename(part,dst))
  end
  results[#results+1]={sha256=a.sha256,bytes=fs.stat(dst).size}
end
local report={passed=true,scope='verified raw archives only',source=source,target=target,artifacts=results}
s.write(work..'/result.json',report);print(s.json.stringify(report))
