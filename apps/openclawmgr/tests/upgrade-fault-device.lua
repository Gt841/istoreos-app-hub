-- Watch a real upgrade and fault only its newly activated vector extension.
-- This tests the shipped rollback, with the previous Gateway left intact.
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs,n=s.fs,s.nixio
local base,work=assert(arg[1]),assert(arg[2])
assert(base:find('/M5/OpenClawMgr',1,true)and fs.realpath(base)==base)
s.mkdir(work,448)
local old=assert(fs.readlink(base..'/current'))
local previous=fs.readlink(base..'/previous')
local ref=s.decode(base..'/current/runtime.json')
local config=base..'/data/.openclaw/openclaw.json'
local config_hash=s.sha(config,work)
local receipt_hash=s.sha(base..'/current/receipt.json',work)
s.write(base..'/data/M5-rollback-sentinel','before upgrade\n')
local relative='global/lib/node_modules/openclaw/node_modules/sqlite-vec-linux-'..(n.uname().machine=='x86_64'and'x64'or'arm64')..'/vec0.so'
assert(fs.stat(base..'/current/'..relative))
local pid=assert(n.fork())
if pid==0 then
  local out=assert(n.open(work..'/upgrade-private.log','w','600'));n.dup(out,n.stdout);n.dup(out,n.stderr);out:close()
  assert(n.setsid());n.exec('/usr/libexec/istorec/openclawmgr.sh','upgrade');os.exit(127)
end
local fault,code,kind
local began=os.time()
while true do
  local now=fs.readlink(base..'/current')
  if not fault and now and now~=old then
    local file=base..'/'..now..'/'..relative
    assert(fs.rename(file,file..'.M5-disabled'))
    s.write(base..'/data/M5-rollback-sentinel','after cutover fault\n')
    fault=now
  end
  local waited,k,c=n.waitpid(pid,'nohang')
  if waited==pid then kind,code=k,c;break end
  if os.time()-began>1200 then n.kill(pid,15);n.waitpid(pid);error('upgrade timed out; inspect private log and recover_install')end
  n.nanosleep(0,20000000)
end
local checks={}
local function check(name,ok)checks[#checks+1]={name=name,passed=not not ok};s.write(work..'/result.json',{checks=checks});assert(ok,name)end
check('fault reached actual new release after cutover',fault~=nil)
check('unhealthy upgraded Gateway fails transaction',kind=='exited'and code~=0)
check('old current pointer restored',fs.readlink(base..'/current')==old)
check('old previous pointer restored',fs.readlink(base..'/previous')==previous)
check('original authentication/config restored',s.sha(config,work)==config_hash)
check('original release receipt unchanged',s.sha(base..'/current/receipt.json',work)==receipt_hash)
check('application data snapshot restored',s.read(base..'/data/M5-rollback-sentinel')=='before upgrade\n')
check('failed new release removed',not fs.lstat(base..'/'..fault))
check('shared SDK preserved',s.decode(ref.storage_root..'/environments/'..ref.instance..'/receipt.json').verified)
local rc=s.run({'/usr/bin/lua','/usr/share/openclawmgr/shared-runtime.lua','as-app',base,'native'},{output=work..'/native-private',timeout=90})
check('old application vector capability restored',rc==0)
local cfg=s.decode(config)
rc=s.run({'/usr/bin/lua','/usr/share/openclawmgr/shared-runtime.lua','as-app',base,'cli','gateway','health','--url','ws://127.0.0.1:'..cfg.gateway.port,'--token',cfg.gateway.auth.token},{output=work..'/health-private',timeout=90})
check('original authenticated Gateway restored',rc==0)
local report={passed=true,arch=n.uname().machine,boot_id=s.boot_id(),exit=code,previous_release=old,failed_release=fault,checks=checks}
s.write(work..'/result.json',report)
print(s.json.stringify(report))
