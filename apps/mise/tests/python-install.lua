local root,selection=unpack(arg)
local share='/usr/share/mise-runtime'
package.path=share..'/lib/?.lua;'..package.path
local s=require('system');local store=require('store');local ctx=store.open(root)
local work=root..'/work/python-install-test';s.mkdir(work,448)
local report={scope='public API on-device Python install and actual probes',checks={}}
local function cli(request)
  s.write(work..'/request.json',request)
  local rc=s.run({'/usr/sbin/mise-runtime','request'},{env={MISE_RUNTIME_ROOT=root},stdin=work..'/request.json',output=work..'/response.json',timeout=45})
  local r=s.decode(work..'/response.json');assert(rc==0 and r and r.ok,s.json.stringify(r));return r.value
end
for _,entry in ipairs(s.decode(share..'/catalog.json').entries)do
  if entry.tool=='python'and entry.arch==s.nixio.uname().machine and(selection=='all'or(entry.version=='3.12.16'and entry.abi=='glibc'))then
    local library=entry.abi=='glibc'and require('libraries').definition(entry.arch).id or nil
    local id=require('contract').instance_id(entry,nil,library)
    local existing=s.decode(root..'/environments/'..id..'/receipt.json')
    if not existing then
      local plan=cli({op='plan',entry=entry.id,source='origin'});local task=cli({op='submit',id=plan.id})
      print('START '..entry.id..' '..task.id);io.stdout:flush()
      for _=1,1200 do
        task=require('tasks').get(ctx,task.id)
        if task.status~='running'then break end
        s.nixio.nanosleep(0,500000000)
      end
      if task.status~='success'then
        s.write(work..'/install-report.json',{passed=false,entry=entry.id,task=task})
        io.stderr:write(s.json.stringify(task)..'\n'..(s.read(root..'/tasks/'..task.id..'/log')or''));os.exit(1)
      end
    end
    local receipt=cli({op='inspect',id=id})
    assert(receipt.verified and receipt.probes.venv=='passed'and receipt.probes.pip=='passed')
    report.checks[#report.checks+1]={entry=entry.id,instance=id,probes=receipt.probes,passed=true}
    print('PASS '..entry.id);io.stdout:flush()
  end
end
report.passed=#report.checks==(selection=='all'and 4 or 1)
s.write(work..'/install-report.json',report);print(s.json.stringify(report));assert(report.passed)
