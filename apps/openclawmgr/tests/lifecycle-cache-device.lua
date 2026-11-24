-- Exercise the real Lua lifecycle adapter and verified actual upstream bytes.
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local fs=s.fs
local main,work=assert(arg[1]),assert(arg[2])
assert(main:find('/M5/OpenClawMgr',1,true))
s.mkdir(work,448)
local policy=s.decode('/usr/share/openclawmgr/native-downloads.json')
local asset=assert(policy.assets[s.nixio.uname().machine])
local pkg=main..'/global/lib/node_modules/openclaw/node_modules/'..policy.package
local source=pkg..'/'..asset.filename
assert(fs.stat(source).size==asset.bytes and s.sha(source,work)==asset.sha256,'Actual native download does not match upstream asset digest')
-- Reuse only this verified raw asset, not an SDK or application installation.
s.mkdir(main..'/npm-cache/native',448)
local actual_cache=main..'/npm-cache/native/'..asset.sha256
assert(s.run({'cp','--',source,actual_cache})==0)
assert(s.sha(actual_cache,work)==asset.sha256)
local base=main..'-lifecycle';assert(not fs.lstat(base))
local txn=base..'/.install.fixture'
local cwd=txn..'/candidate/global/lib/node_modules/openclaw/node_modules/'..policy.package
s.mkdir(cwd,448);s.mkdir(base..'/npm-cache/native',448)
s.write(cwd..'/package.json',{name=policy.package,version=policy.version})
s.write(cwd..'/download-lib.js',s.read(pkg..'/download-lib.js'))
local cached=base..'/npm-cache/native/'..asset.sha256
assert(s.run({'cp','--',source,cached})==0)
local env={npm_package_name=policy.package,npm_package_version=policy.version,npm_lifecycle_event=policy.event,
  npm_config_libc='glibc',OPENCLAWMGR_BASE_DIR=base,OPENCLAWMGR_TXN=txn,OPENCLAWMGR_ACCELERATED='1'}
local checks={}
local function call(command,seconds)
  return s.run({'/usr/bin/lua','/usr/share/openclawmgr/npm-lifecycle.lua','-c',command},{cwd=cwd,env=env,output=work..'/output-private',timeout=seconds or 10})
end
local function check(name,value)checks[#checks+1]={name=name,passed=not not value};s.write(work..'/result.json',{checks=checks});assert(value,name)end
check('ordinary shell command exit code retained',call('exit 27')==27)
check('ordinary command preserves quoting',call('printf "%s" "two words"')==0 and s.read(work..'/output-private')=='two words')
check('known postinstall reuses verified cache',call(policy.command)==0 and (s.read(work..'/output-private')or''):find('Using verified native artifact cache',1,true))
check('installed native artifact matches official size and SHA256',fs.stat(cwd..'/'..asset.filename).size==asset.bytes and s.sha(cwd..'/'..asset.filename,work)==asset.sha256)
assert(fs.unlink(cwd..'/'..asset.filename))
s.write(cwd..'/download-lib.js','modified script')
check('changed upstream script is rejected before replacement',call(policy.command)~=0 and not fs.lstat(cwd..'/'..asset.filename))
s.write(cwd..'/download-lib.js',s.read(pkg..'/download-lib.js'))
local f=assert(io.open(cached,'r+b'));f:write('broken');f:close()
local rc=call(policy.command,3)
check('corrupt cached bytes are rejected, never copied',not fs.lstat(cached)and not fs.lstat(cwd..'/'..asset.filename))
check('actual reusable app cache remains verified',s.sha(actual_cache,work)==asset.sha256)
local report={passed=true,arch=s.nixio.uname().machine,checks=checks,asset=asset,upstream=policy.source,corrupt_cache_call_exit=rc}
s.write(work..'/result.json',report)
s.remove(base)
print(s.json.stringify(report))
