local share,root,ks=unpack(arg)
package.path=share..'/lib/?.lua;'..package.path
local sys=require('system');local store=require('store')
local ctx=store.open(root);local r
for _,id in ipairs(store.list(root..'/environments'))do
  local value=sys.decode(root..'/environments/'..id..'/receipt.json')
  if value and value.verified and value.entry.tool=='node'and value.entry.abi=='glibc'and value.npm~='11.12.1'then r=value;break end
end
assert(r)
local work=root..'/work/command-status';sys.mkdir(work,448)
local function run(command,args,policy)
  local argv={root..'/wrap/'..r.instance,command};for _,v in ipairs(args)do argv[#argv+1]=v end
  local rc=sys.run(argv,{output=work..'/out',timeout=60,env={ISTORE_RUNTIME_ACCELERATION=policy,ISTORE_RUNTIME_KS_CLI=ks}})
  return rc,sys.read(work..'/out')or''
end
local project=root..'/users/0/home/git project';sys.mkdir(project,448)
for _,policy in ipairs({'origin','ks-cli'})do
  local rc,out=run('git',{'init','-q',project},policy);assert(rc==0,out)
  rc,out=run('git',{'-C',project,'rev-parse','--show-toplevel'},policy);assert(rc==0 and out:gsub('%s+$','')==project,out)
  rc,out=run('git',{'-C',work..'/not-present','status'},policy);assert(rc==128,'git native exit status lost: '..rc..' '..out)
  sys.write(work..'/package.json',{name='exit-status-fixture',version='1.0.0',scripts={fail='node -e "process.exit(17)"'}})
  rc,out=run('npm',{'--prefix',work,'run','fail'},policy);assert(rc==17,'npm native exit status lost: '..rc..' '..out)
  print('PASS '..policy..' Git literal path and Git/npm native exit codes')
end
