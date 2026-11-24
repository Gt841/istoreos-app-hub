local share,root=unpack(arg)
package.path=share..'/lib/?.lua;'..package.path
local sys=require('system');local store=require('store');local tasks=require('tasks')
local ctx=store.open(root);local n,fs=sys.nixio,sys.fs
local old=root..'/old-data';assert(sys.read(old)=='preserve')
local count=0
for _,phase in ipairs({'preparing','download','extract','probe','committed'})do
  for _,mode in ipairs({'cancel','kill'})do
    local candidate='fault-fixture-'..phase..'-'..mode
    local t=tasks.start(ctx,{},function(c,task,w,log)
      local p=root..'/environments/'..candidate;sys.mkdir(p,493);sys.write(p..'/marker','candidate')
      task.pending_environment={id=candidate,inode=fs.lstat(p).ino};tasks.phase(c,task,phase)
      assert(sys.run({'/bin/sleep','60'},{timeout=65,output=log})==0)
    end)
    for _=1,100 do
      local current=tasks.get(ctx,t.id)
      if current.phase==phase and #store.list(root..'/tasks/'..t.id..'/processes')>0 then break end
      n.nanosleep(0,50000000)
    end
    assert(tasks.get(ctx,t.id).phase==phase)
    local owners={}
    for _,name in ipairs(store.list(root..'/tasks/'..t.id..'/processes'))do owners[#owners+1]=sys.decode(root..'/tasks/'..t.id..'/processes/'..name)end
    if mode=='kill'then assert(n.kill(t.owner.pid,9));n.waitpid(t.owner.pid)end
    local done=tasks.recover(ctx,t.id,mode=='cancel')
    assert(done.status==(phase=='committed'and'success'or'canceled'))
    assert(not fs.lstat(root..'/.lock')and not fs.lstat(root..'/work/'..t.id)and sys.read(old)=='preserve')
    for _,owner in ipairs(owners)do assert(#sys.session_members(owner)==0)end
    local p=root..'/environments/'..candidate
    if phase=='committed'then assert(sys.read(p..'/marker')=='candidate');sys.remove(p)else assert(not fs.lstat(p))end
    count=count+1;print('PASS '..count..' '..phase..' '..mode..' preserves old data and stops owned commands');io.stdout:flush()
  end
end
print('passed='..count)
