-- Public first-use initialization on explicitly task-owned disk directories.
-- MISE_RUNTIME_ROOT='' isolates configuration: the system UCI is never changed.
local share,work=arg[1],arg[2]
package.path=share..'/lib/?.lua;'..package.path
local sys=require('system')
local candidates=require('storage-paths').discover('')
assert(work:match('^/mnt/[^/]+/acceptance/direct%-deploy/[%w._-]+/storage%-settings%-probe$'))
assert(not sys.fs.lstat(work),'refusing to reuse test work directory')
sys.mkdir(work,448)
local hash=sys.sha('/etc/config/mise',work)
local results={}
for _,candidate in ipairs(candidates)do
  local mount=candidate:match('^(/mnt/[^/]+)/')
  local root=mount..'/Configs/Runtime-probe-'..sys.nixio.getpid()
  assert(not sys.fs.lstat(root),'refusing to replace an existing path')
  sys.write(work..'/request.json',{op='settings',path=root,acceleration=false})
  local rc=sys.run({'/usr/bin/lua',share..'/main.lua','request'},
    {stdin=work..'/request.json',output=work..'/response.json',env={MISE_RUNTIME_ROOT=''},timeout=30})
  local response=sys.decode(work..'/response.json')
  assert(rc==0 and response and response.ok,sys.json.stringify(response))
  assert(response.value.path==root and response.value.online and not response.value.storage_locked)
  assert(#response.value.runtimes==0 and sys.decode(root..'/.storage.json'))
  local home=sys.fs.lstat(root..'/home');assert(home and home.type=='dir'and home.uid==0)
  assert(sys.sha('/etc/config/mise',work)==hash,'system settings unexpectedly changed')
  -- Only remove the root created above, after proving it was initialized by us.
  assert(sys.decode(root..'/.storage.json').mount==mount)
  sys.remove(root);assert(not sys.fs.lstat(root))
  results[#results+1]={mount=mount,passed=true,probe_removed=true,home_initialized=true}
end
assert(#results>=2,'expected at least two mounted test disks')
print(sys.json.stringify({passed=true,checks=results,system_configuration_unchanged=true}))
