-- Read/execute an actual installed common SDK; mutate only this fixture's refs.
local bridge,root,base=unpack(arg)
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local store=require('store')
local ref=base..'/bridge-fixture/releases/test/runtime.json'
local original=s.decode(ref);assert(original)
local config=s.read('/etc/config/mise');local results={}
for _,path in ipairs({root,root..'/application',root:match('^(.*)/[^/]+$')})do
  local rc=s.run({'/usr/bin/lua',bridge,'preflight',path},{output=base..'/binding-output',timeout=10})
  assert(rc~=0,'Shared runtime overlap was accepted: '..path)
  results[#results+1]={name='reject application/shared storage overlap: '..path,passed=true,exit=rc}
end
assert(s.run({'/usr/bin/lua',bridge,'preflight',base},{output=base..'/binding-output',timeout=10})==0,s.read(base..'/binding-output'))
local function probe(name,value,mode,uid,expected)
  s.write(ref,value,mode or 420);assert(s.fs.chmod(ref,string.format('%o',mode or 420)))
  if uid then assert(s.fs.chown(ref,uid,uid))end
  local rc=s.run({'/usr/bin/lua',bridge,'inspect',ref},{output=base..'/binding-output',timeout=10})
  assert((rc==0)==expected,name..': '..(s.read(base..'/binding-output')or''))
  results[#results+1]={name=name,passed=true,exit=rc}
end
probe('actual verified shared SDK',original,nil,nil,true)
for _,change in ipairs({{provider='foreign'},{instance='missing-fixed-sdk'},{node='99.0.0'},
 {library_manifest_sha256=string.rep('0',64)},{storage_root='/root/forbidden'},{schema_version=999}})do
  local value=s.json.parse(s.json.stringify(original));for k,v in pairs(change)do value[k]=v end
  probe('reject '..next(change),value,nil,nil,false)
end
probe('reject group/world writable binding',original,438,nil,false)
probe('reject another UID binding',original,420,65001,false)
s.write(ref,original,420)
local argv={'/usr/bin/lua',bridge,'exec',ref,'node','-e',[[const a=require('node:assert/strict');a.equal(process.argv[1],'two words');a.equal(require('node:fs').readFileSync(0,'utf8'),'stdin preserved\n');console.log(process.version);]],'two words'}
s.write(base..'/binding-input','stdin preserved\n')
assert(s.run(argv,{stdin=base..'/binding-input',output=base..'/binding-output',timeout=10})==0,s.read(base..'/binding-output'))
assert(s.read(base..'/binding-output')=='v'..original.node..'\n')
results[#results+1]={name='public fixed exec preserves arguments/stdin',passed=true}
assert(s.run({'/usr/bin/lua',bridge,'exec',ref,'node','-e','process.exit(37)'},{output=base..'/binding-output',timeout=10})==37)
results[#results+1]={name='public fixed exec preserves exit status',passed=true}
assert(s.run({'/usr/bin/lua',bridge,'exec',ref,'npm','config','get','prefix'},{output=base..'/binding-output',timeout=10})==0,s.read(base..'/binding-output'))
assert(s.read(base..'/binding-output')==base..'/bridge-fixture/releases/test/global\n',s.read(base..'/binding-output'))
results[#results+1]={name='npm prefix belongs to application release',passed=true}
local work=base..'/binding-library-check'
assert(s.run({'/usr/bin/lua',bridge,'check',ref,work},{output=base..'/binding-output',timeout=30})==0,s.read(base..'/binding-output'))
results[#results+1]={name='actual fixed private library manifest/loader check',passed=true}
assert(s.read('/etc/config/mise')==config)
s.write(base..'/binding-device.json',{passed=true,results=results})
print(s.json.stringify({passed=true,results=results}))
