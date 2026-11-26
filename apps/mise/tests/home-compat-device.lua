-- Installed real entry points and SDKs; no download, package build, global
-- version changes, application restart, or system UCI mutation.
local root,work=arg[1],arg[2]
package.path='/usr/share/mise-runtime/lib/?.lua;'..package.path
local s=require('system');local store=require('store');require('contract').path(root)
assert(work:match('^/mnt/[^/]+/acceptance/[%w_./-]+$')and not s.fs.lstat(work))
s.mkdir(work,448)
local config,results,node=s.read('/etc/config/mise'),{},nil
-- Keep evidence limited to command names and selected path facts.
local function run(name,argv,input,uid,home)
  s.write(work..'/stdin',input or'')
  local env={HOME='/root',MISE_OFFLINE='1',MISE_NOT_FOUND_AUTO_INSTALL='0',ISTORE_RUNTIME_ACCELERATION='origin'}
  if home then env.ISTORE_RUNTIME_HOME=home end
  local rc=s.run(argv,{env=env,cwd=work,stdin=work..'/stdin',output=work..'/stdout',uid=uid,gid=uid,timeout=30})
  assert(rc==0,name..' failed with exit '..rc)
  local output=s.read(work..'/stdout')or''
  results[#results+1]={name=name,passed=true}
  return output
end
local function contains(output,value)assert(output:find(value,1,true),'expected persistent HOME not reported')end
local ok,err=pcall(function()
  local home=root..'/home'
  contains(run('AgentFlow environment helper explicitly replaces inherited HOME',{'/bin/sh','-c',
    '. /lib/functions/mise.sh; istore_runtime_env || exit 1; printf "%s\\n" "$HOME"'}),home)
  contains(run('mise-istore real mise exec inherits the persistent HOME',{'/usr/sbin/mise-istore','exec','--','/bin/sh','-c','printf "%s\\n" "$HOME"'}),home)
  contains(run('mise-exec interactive shell inherits the persistent HOME',{'/usr/sbin/mise-exec'},'printf "%s\\n" "$HOME"\n'),home)
  local ctx=store.open(root)
  for _,id in ipairs(store.list(root..'/environments'))do
    local r=s.decode(root..'/environments/'..id..'/receipt.json')
    if r and r.verified then
      assert(require('registration').scope(ctx,r.entry).home==home)
      local wrap=root..'/wrap/'..id
      if r.entry.tool=='node'then
        local js=[[const a=require('node:assert/strict');a.equal(process.env.HOME,process.argv[1]);a.ok(process.env.TMPDIR.startsWith(process.env.HOME+'/'));a.equal(require('node:child_process').execFileSync(process.execPath,['-p','process.env.HOME'],{encoding:'utf8'}).trim(),process.env.HOME);console.log(JSON.stringify({home:process.env.HOME,version:process.version,glibc:process.report.getReport().header.glibcVersionRuntime||null}));]]
        local v=s.json.parse(run('fixed '..id..' root HOME and child inheritance',{wrap,'node','-e',js,home}))
        assert(v and v.home==home and v.version=='v'..r.entry.version)
        if r.entry.abi=='glibc'then assert(v.glibc);node=r end
        contains(run('npm cache uses the same persistent HOME',{wrap,'npm','config','get','cache'}),home..'/')
      elseif r.entry.tool=='python'then
        contains(run('fixed '..id..' Python HOME',{wrap,'python','-c','import os; print(os.environ["HOME"])'}),home)
      elseif r.entry.tool=='go'then
        contains(run('fixed '..id..' Go caches',{wrap,'go','env','GOCACHE','GOMODCACHE'}),home..'/')
      elseif r.entry.tool=='zig'then
        contains(run('fixed '..id..' Zig caches',{wrap,'zig','env'}),home..'/')
      end
    end
  end
  assert(node,'verified GNU Node required')
  local wrap=root..'/wrap/'..node.instance
  local userhome=root..'/users/65001/home'
  assert(s.fs.stat(userhome).uid==65001,'existing test UID home required')
  contains(run('non-root default HOME remains isolated',{wrap,'node','-p','process.env.HOME'},nil,65001),userhome)
  local old=root..'/users/0/home'
  assert(s.fs.stat(old),'existing old root HOME required')
  contains(run('explicit old root HOME remains supported',{wrap,'node','-p','process.env.HOME'},nil,nil,old),old)
  -- Same explicit application HOME used by OpenClaw; execute its own fixed
  -- wrapper as its existing UID, without starting/stopping the Gateway.
  local base='/mnt/mise-runtime/acceptance/M5/OpenClawMgr'
  local binding=s.decode(base..'/current/runtime.json');assert(binding and binding.storage_root==root)
  local apphome=base..'/data';assert(s.fs.stat(apphome).uid==32771)
  contains(run('OpenClaw explicit HOME remains private to its service UID',
    {root..'/wrap/'..binding.instance,'node','-p','process.env.HOME'},nil,32771,apphome),apphome)
  for _,bad in ipairs({root,root..'/environments',root..'/cache'})do
    local rc=s.run({wrap,'node','-p','process.env.HOME'},
      {env={ISTORE_RUNTIME_HOME=bad,ISTORE_RUNTIME_ACCELERATION='origin'},output=work..'/rejected',timeout=30})
    assert(rc~=0,'shared manager directory accepted as HOME')
    results[#results+1]={name='reject shared manager HOME '..bad,passed=true}
  end
  assert(s.read('/etc/config/mise')==config,'system UCI changed')
end)
print(s.json.stringify({passed=ok,checks=results,error=not ok and(type(err)=='table'and err.message or tostring(err))or nil,
  system_configuration_unchanged=s.read('/etc/config/mise')==config}))
os.exit(ok and 0 or 1)
