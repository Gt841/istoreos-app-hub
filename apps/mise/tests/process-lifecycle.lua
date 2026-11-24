-- Real process supervision regressions, using the public task/process seam.
local share,root=unpack(arg)
package.path=share..'/lib/?.lua;'..package.path
local sys=require('system');local store=require('store');local tasks=require('tasks')
local n,fs=sys.nixio,sys.fs;local ctx=store.open(root)
local count=0
local function test(name,fn)
  local ok,err=pcall(fn)
  if not ok then io.stderr:write('FAIL '..name..' '..(type(err)=='table'and sys.json.stringify(err)or tostring(err))..'\n');os.exit(1)end
  count=count+1;print('PASS '..count..' '..name);io.stdout:flush()
end
local function read_child(t)
  for _=1,100 do
    local raw=sys.read(root..'/work/'..t.id..'/child.pid')
    if raw then local p=sys.process(tonumber(raw));if p then return p end end
    n.nanosleep(0,50000000)
  end
  error('child did not start')
end
local function absent(p)
  local now=sys.process(p.pid)
  assert(not now or now.start~=p.start or now.state=='Z','owned child survives')
end
local function wait(t)
  for _=1,240 do
    local current=tasks.get(ctx,t.id)
    if current.status~='running'then n.waitpid(t.owner.pid,'nohang');return current end
    n.nanosleep(0,50000000)
  end
  error('task completion timed out')
end
local function long(c,t,w,log)
  tasks.phase(c,t,'native-command')
  local code='trap "" TERM; sleep 45 & echo $! > "$1"; wait'
  local rc=sys.run({'/bin/sh','-c',code,'probe',w..'/child.pid'},{timeout=2,output=log,append=true})
  sys.need(rc==0,'PROBE_FAILED','Command exited '..rc)
end
test('cancel reaps timed command and TERM-ignoring grandchild',function()
  local t=tasks.start(ctx,{},long);local p=read_child(t)
  assert(#store.list(root..'/tasks/'..t.id..'/processes')==1,'command ran before durable ownership journal')
  assert(tasks.recover(ctx,t.id,true).status=='canceled');absent(p)
  assert(not fs.lstat(root..'/.lock')and not fs.lstat(root..'/work/'..t.id))
end)
test('natural deadline reaps grandchild before failed terminal state',function()
  local t=tasks.start(ctx,{},long);local p=read_child(t)
  local done=wait(t);assert(done.status=='failed'and done.error.message=='Command exited 124');absent(p)
  assert(not fs.lstat(root..'/.lock'))
end)
test('SIGKILL worker recovery uses persisted command ownership',function()
  local t=tasks.start(ctx,{},long);local p=read_child(t)
  assert(n.kill(t.owner.pid,9));n.waitpid(t.owner.pid)
  assert(tasks.recover(ctx,t.id,false).status=='canceled');absent(p)
  assert(not fs.lstat(root..'/.lock'))
end)
test('successful command cannot leak background process',function()
  local marker=root..'/background.pid'
  local t=tasks.start(ctx,{},function(c,task,w,log)
    assert(sys.run({'/bin/sh','-c','sleep 45 & echo $! > "$1"','probe',marker},{timeout=5,output=log})==0)
  end)
  assert(wait(t).status=='success')
  local pid=tonumber(sys.read(marker));local p=sys.process(pid);assert(not p or p.state=='Z')
end)
test('PID identity mismatch refuses signaling',function()
  local owner=sys.process(n.getpid());owner.start='wrong-start'
  local ok,err=pcall(sys.stop_session,owner);assert(not ok and err.code=='BUSY')
end)
test('commit publication recovery preserves a subsequent lock',function()
  local id=sys.identifier('task');local dir=root..'/tasks/'..id;sys.mkdir(dir,448)
  local t={id=id,status='running',phase='committed',cleaned=true,final_status='success'}
  tasks.save(ctx,t);store.lock(ctx,{id='subsequent-task'})
  assert(tasks.recover(ctx,id,false).status=='success')
  assert(sys.decode(root..'/.lock/owner.json').id=='subsequent-task');store.unlock(ctx,'subsequent-task')
end)
print('passed='..count)
