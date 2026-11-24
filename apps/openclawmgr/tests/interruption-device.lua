-- Real npm child + SIGKILL of its installer; recovery must reap the child.
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs,n=s.fs,s.nixio
local base,work=assert(arg[1]),assert(arg[2])
local mode=arg[3]or'kill';assert(mode=='kill'or mode=='cancel')
assert(base:find('/M5/OpenClawMgr',1,true)and fs.realpath(base)==base)
s.mkdir(work,448)
local before=assert(fs.readlink(base..'/current'))
local config_hash=s.sha(base..'/data/.openclaw/openclaw.json',work)
local pid=assert(n.fork())
if pid==0 then
  local out=assert(n.open(work..'/upgrade-private.log','w','600'));n.dup(out,n.stdout);n.dup(out,n.stderr);out:close()
  assert(n.setsid());n.exec('/usr/libexec/istorec/openclawmgr.sh','upgrade');os.exit(127)
end
local owner
local ok,err=pcall(function()
  local began=os.time()
  while not owner do
    for name in fs.dir('/proc')do
      local p=s.process(tonumber(name));local cmd=p and s.read('/proc/'..name..'/cmdline')or''
      if p and cmd:find(base..'/.install.',1,true)and cmd:find('npm-cli.js',1,true)and cmd:find('--foreground-scripts',1,true)then
        owner=assert(s.process(p.session));break
      end
    end
    assert(os.time()-began<120,'actual npm install child not observed')
    local done=n.waitpid(pid,'nohang');assert(not done or done==0,'installer exited before fault')
    n.nanosleep(0,20000000)
  end
  local concurrent=s.run({'/usr/libexec/istorec/openclawmgr.sh','upgrade'},{output=work..'/concurrent-private.log',timeout=30})
  assert(concurrent~=0,'concurrent upgrade unexpectedly succeeded')
  if mode=='kill'then assert(n.kill(pid,9));n.waitpid(pid)end
  -- Freeze owned processes so an unfixed recovery cannot race with npm writes
  -- while deleting the candidate. The fixed reaper must still terminate them.
  for _,p in ipairs(s.session_members(owner))do assert(n.kill(p.pid,19))end
  local rc=s.run({'/usr/libexec/istorec/openclawmgr.sh',mode=='kill'and'recover_install'or'cancel_install'},{output=work..'/recover-private.log',timeout=90})
  if mode=='cancel'then n.waitpid(pid)end
  local journals=0;for name in fs.dir(base)do if name:match('^%.install%.')then journals=journals+1 end end
  local checks={
    {name='concurrent upgrade is rejected',passed=concurrent~=0},
    {name='public '..mode..' recovery succeeds',passed=rc==0},
    {name='control action reaps actual npm session',passed=#s.session_members(owner)==0},
    {name='transaction and lock cleaned',passed=journals==0 and not fs.lstat('/tmp/openclawmgr-installer.lock')},
    {name='old release remains selected',passed=fs.readlink(base..'/current')==before},
    {name='old authentication/config unchanged',passed=s.sha(base..'/data/.openclaw/openclaw.json',work)==config_hash}
  }
  local passed=true;for _,c in ipairs(checks)do passed=passed and c.passed end
  local report={passed=passed,mode=mode,arch=n.uname().machine,boot_id=s.boot_id(),checks=checks,recovery_exit=rc,owned_session=owner}
  s.write(work..'/result.json',report);print(s.json.stringify(report))
  assert(passed,'interruption recovery failed; see structured evidence')
end)
-- Only this test's recorded session is cleaned after a failing assertion.
if owner then s.stop_session(owner)end
if s.process(pid)then n.kill(pid,9);n.waitpid(pid)end
if not ok then error(err)end
