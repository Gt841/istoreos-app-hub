-- Exercise application-owned cancellation of a real detached public SDK task.
-- A temporary application policy selects an additional supported npm instance;
-- existing release bindings and the global default are never changed.
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs,n=s.fs,s.nixio
local base,work=assert(arg[1]),assert(arg[2])
assert(base:find('/M5/OpenClawMgr',1,true));s.mkdir(work,448)
local policy_file='/usr/share/openclawmgr/runtime-policy.json'
local original=assert(s.read(policy_file));s.write(work..'/policy-before.private',original)
local ref=s.decode(base..'/current/runtime.json')
local old=assert(fs.readlink(base..'/current'))
local sdk_hash=s.sha(ref.storage_root..'/environments/'..ref.instance..'/receipt.json',work)
local p=s.json.parse(original);p.npm='11.12.1'
local entry
for _,e in ipairs(s.decode('/usr/share/mise-runtime/catalog.json').entries)do
  if e.tool==p.tool and e.version==p.version and e.abi==p.abi and e.arch==n.uname().machine and e.npm==p.npm then entry=e;break end
end
assert(entry)
p.build=entry.build
local id=require('contract').instance_id(entry,nil,ref.library)
assert(not fs.lstat(ref.storage_root..'/environments/'..id),'Additional test SDK already exists; preserve it')
s.write(policy_file,p,420)
local pid,task
local ok,err=pcall(function()
  pid=assert(n.fork())
  if pid==0 then
    local out=assert(n.open(work..'/upgrade-private.log','w','600'));n.dup(out,n.stdout);n.dup(out,n.stderr);out:close()
    assert(n.setsid());n.exec('/usr/libexec/istorec/openclawmgr.sh','upgrade');os.exit(127)
  end
  local began=os.time()
  while not task do
    local done=n.waitpid(pid,'nohang')
    if done==pid then pid=nil;error('Installer exited before creating the requested SDK task; inspect private log')end
    for _,name in ipairs(require('store').list(base))do if name:match('^%.install%.')then
      local journal=s.decode(base..'/'..name..'/runtime-task.json')
      if journal then
        for _,key in ipairs(require('store').list(journal.root..'/tasks'))do
          local t=s.decode(journal.root..'/tasks/'..key..'/task.json')
          if t and t.plan and t.plan.id==journal.plan and t.status=='running'and s.alive(t.owner)then task=t;break end
        end
      end
    end end
    assert(os.time()-began<120,'No running application-owned SDK task observed')
    n.nanosleep(0,20000000)
  end
  -- Hold the exact owned worker before commit so this exercises cancellation,
  -- rather than racing into a successful reusable SDK installation.
  assert(n.kill(task.owner.pid,19))
  local rc=s.run({'/usr/libexec/istorec/openclawmgr.sh','cancel_install'},{output=work..'/cancel-private.log',timeout=90})
  local _,kind,code=n.waitpid(pid);pid=nil
  local latest=s.decode(ref.storage_root..'/tasks/'..task.id..'/task.json')
  local checks={
    {name='public application cancel succeeds',passed=rc==0},
    {name='coordinator exits without app success',passed=kind=='exited'and code~=0},
    {name='owned detached SDK task canceled and cleaned',passed=latest.status=='canceled'and latest.cleaned},
    {name='owned worker session reaped',passed=#s.session_members(task.owner)==0},
    {name='owned incomplete SDK removed',passed=not fs.lstat(ref.storage_root..'/environments/'..id)},
    {name='public manager lock released',passed=not fs.lstat(ref.storage_root..'/.lock')},
    {name='existing release remains selected',passed=fs.readlink(base..'/current')==old},
    {name='existing shared SDK unchanged',passed=s.sha(ref.storage_root..'/environments/'..ref.instance..'/receipt.json',work)==sdk_hash}
  }
  local passed=true;for _,c in ipairs(checks)do passed=passed and c.passed end
  local report={passed=passed,arch=n.uname().machine,boot_id=s.boot_id(),task=task.id,task_status=latest.status,additional_instance=id,checks=checks}
  s.write(work..'/result.json',report);print(s.json.stringify(report));assert(passed,'Shared cancellation failed')
end)
if pid then
  s.run({'/usr/libexec/istorec/openclawmgr.sh','cancel_install'},{output=work..'/cleanup-private.log',timeout=90})
  local done=n.waitpid(pid,'nohang');if not done or done==0 then n.kill(pid,9);n.waitpid(pid)end
  s.run({'/usr/libexec/istorec/openclawmgr.sh','recover_install'},{output=work..'/cleanup-private.log',timeout=120})
end
s.write(policy_file,original,420)
if not ok then error(err)end
