// Real LuCI/Argon assets and permissions. Mutations are intercepted in browser.
import {chromium} from 'playwright'
import fs from 'node:fs'
import assert from 'node:assert/strict'
const session=JSON.parse(fs.readFileSync(process.env.MISE_LIVE_SESSION,'utf8'))
const out=process.env.MISE_LIVE_EVIDENCE;assert(out);fs.mkdirSync(out,{recursive:true})
const browser=await chromium.launch({executablePath:'/config/.cache/ms-playwright/chromium_headless_shell-1200/chrome-headless-shell-linux64/chrome-headless-shell',args:['--no-sandbox']})
const context=await browser.newContext({viewport:{width:1382,height:1000}})
await context.addCookies([{name:'sysauth_http',value:session.admin.sid,url:session.base}])
const page=await context.newPage(),checks=[],errors=[]
const endpoint=session.base+'/cgi-bin/luci/admin/services/mise/request'
const redact=text=>[session.admin.sid,session.admin.token,session.readonly.sid,session.readonly.token].reduce((v,key)=>v.replaceAll(key,'[redacted]'),String(text))
page.on('pageerror',e=>errors.push(redact(e.message)))
async function request(r,auth=session.admin){const response=await context.request.post(endpoint,{form:{token:auth.token,request:JSON.stringify(r)},headers:{Cookie:'sysauth_http='+auth.sid}});return response.json()}
async function check(name,fn){await fn();checks.push({name,passed:true})}
async function storage(){await page.goto(session.base+'/cgi-bin/luci/admin/services/mise');await page.getByRole('button',{name:'存储与设置',exact:true}).click();await page.getByLabel('运行环境存放位置',{exact:true}).waitFor()}
let passed=false,error,before,snapshot,changes=[],repairs=[]
try{
 before=(await request({op:'read'})).value;assert(before.runtimes.length>0)
 snapshot=structuredClone(before)
 await page.route('**/mise/request',async route=>{
  const r=JSON.parse(new URLSearchParams(route.request().postData()).get('request'))
  const send=value=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({schema_version:1,ok:true,value})})
  if(r.op==='read')return send(snapshot)
  if(r.op==='settings'){
   changes.push(r);snapshot={...snapshot,path:r.path,managed_home:r.path+'/home',storage_locked:false,runtimes:[],libraries:[],tasks:[],cache_bytes:0,revision:snapshot.revision+1}
   return send(snapshot)
  }
  if(r.op==='library-repair'){
   repairs.push(r);snapshot={...snapshot,tasks:[{id:'browser-library-repair',status:'running',phase:'library',started:Date.now()/1000,logs:[],plan:{kind:'library-repair',library:r.id,source:r.source}}]}
   return send({owned:true,task:snapshot.tasks[0]})
  }
  return route.continue()
 })
 await check('existing environments allow changing the selected repository',async()=>{
  await storage();const select=page.getByLabel('运行环境存放位置',{exact:true})
  assert.equal(await select.isDisabled(),false)
  assert.equal(await select.inputValue(),before.path)
  assert.equal(await page.getByRole('button',{name:'检查 / 修复',exact:true}).count(),before.libraries.length)
  assert.equal(await page.locator('.library-row').first().getByRole('button',{name:'清理',exact:true}).isDisabled(),true)
 })
 await check('switch confirmation preserves the old selection on cancel and explains HOME/restart',async()=>{
  await page.getByLabel('运行环境存放位置',{exact:true}).selectOption('/mnt/vio4-0/Configs/Runtime')
  await page.getByRole('button',{name:'保存设置',exact:true}).click()
  const dialog=page.getByRole('dialog',{name:'切换运行时仓库'});await dialog.waitFor()
  assert.equal(changes.length,0);const text=await dialog.innerText()
  for(const phrase of ['旧目录','重启','重新登录','绝对路径'])assert(text.includes(phrase))
  const box=await dialog.boundingBox();assert(box.x>=0&&box.y>=0&&box.x+box.width<=1383)
  await page.screenshot({path:out+'/switch-confirmation.png'})
  await dialog.getByRole('button',{name:'取消',exact:true}).click();assert.equal(changes.length,0)
 })
 await check('confirmed switch submits one settings request and displays an empty new repository',async()=>{
  await page.getByRole('button',{name:'保存设置',exact:true}).click()
  await page.getByRole('dialog',{name:'切换运行时仓库'}).getByRole('button',{name:'确认切换',exact:true}).click()
  await page.getByRole('status').filter({hasText:'仓库已切换'}).waitFor()
  assert.equal(changes.length,1);assert.equal(changes[0].path,'/mnt/vio4-0/Configs/Runtime')
  assert((await page.locator('.storage-home').innerText()).includes('/mnt/vio4-0/Configs/Runtime/home'))
  await page.getByRole('button',{name:'运行环境',exact:true}).click()
  await page.getByText('还没有 Node.js 环境',{exact:true}).waitFor()
 })
 snapshot=structuredClone(before)
 await check('repair submits a version-pinned library task and renders progress',async()=>{
  await storage();await page.getByRole('button',{name:'检查 / 修复',exact:true}).first().click()
  await page.getByRole('dialog',{name:'检查 / 修复 glibc 运行库'}).waitFor()
  assert.equal(repairs.length,1);assert.equal(repairs[0].id,before.libraries[0].id)
  await page.getByRole('dialog').getByRole('button',{name:'后台继续',exact:true}).click()
  await page.getByRole('button',{name:'存储与设置',exact:true}).click()
  assert.equal(await page.getByLabel('运行环境存放位置',{exact:true}).isDisabled(),true)
 })
 snapshot={...structuredClone(before),storage_locked:true,tasks:[]}
 await check('maintenance lock blocks switching even without a visible install task',async()=>{
  await storage();assert.equal(await page.getByLabel('运行环境存放位置',{exact:true}).isDisabled(),true)
  assert.equal(await page.getByRole('button',{name:'检查 / 修复',exact:true}).first().isDisabled(),true)
 })
 snapshot={...structuredClone(before),online:false,storage_locked:false,runtimes:[],libraries:[],tasks:[]}
 await check('offline old storage permits a new selection; mobile dialog remains inside viewport',async()=>{
  await page.setViewportSize({width:390,height:900});await storage()
  assert.equal(await page.getByLabel('运行环境存放位置',{exact:true}).isDisabled(),false)
  await page.getByLabel('运行环境存放位置',{exact:true}).selectOption('__custom__')
  await page.getByLabel('自定义存放目录',{exact:true}).fill('/mnt/vio4-0/Configs/Runtime-custom')
  await page.getByRole('button',{name:'保存设置',exact:true}).click()
  const dialog=page.getByRole('dialog',{name:'切换运行时仓库'});await dialog.waitFor()
  const box=await dialog.boundingBox();assert(box.x>=0&&box.y>=0&&box.x+box.width<=391&&box.y+box.height<=901)
  await page.screenshot({path:out+'/switch-mobile.png'})
 })
 await check('read-only sessions cannot switch storage or repair libraries',async()=>{
  const ro=await browser.newContext();await ro.addCookies([{name:'sysauth_http',value:session.readonly.sid,url:session.base}]);const rp=await ro.newPage()
  await rp.goto(session.base+'/cgi-bin/luci/admin/services/mise');await rp.getByRole('button',{name:'存储与设置',exact:true}).click()
  assert.equal(await rp.getByLabel('运行环境存放位置',{exact:true}).isDisabled(),true)
  assert.equal(await rp.getByRole('button',{name:'检查 / 修复',exact:true}).first().isDisabled(),true)
  const denied=await ro.request.post(endpoint,{form:{token:session.readonly.token,request:JSON.stringify({op:'library-repair',id:before.libraries[0].id,source:'origin'})}})
  assert.equal(denied.status(),403);await ro.close()
 })
 const after=(await request({op:'read'})).value
 assert.equal(after.path,before.path);assert.deepEqual(after.runtimes,before.runtimes);assert.deepEqual(after.tasks,before.tasks)
 assert.deepEqual(errors,[]);passed=true
}catch(e){error=redact(e.message)}finally{
 await browser.close();fs.writeFileSync(out+'/browser.json',JSON.stringify({passed,checks,error,pageErrors:errors,mutations:'browser-intercepted; real read-only denial checked'},null,2)+'\n')
 console.log(JSON.stringify({passed,checks,error}));process.exitCode=passed?0:1
}
