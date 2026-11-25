// Actual LuCI storage discovery and guarded existing installation; new-install
// rendering uses intercepted read responses and never changes device settings.
import {chromium} from 'playwright'
import fs from 'node:fs'
import path from 'node:path'
import assert from 'node:assert/strict'
const session=JSON.parse(fs.readFileSync(process.env.MISE_LIVE_SESSION,'utf8'))
const out=process.env.MISE_LIVE_EVIDENCE;assert(out);fs.mkdirSync(out,{recursive:true})
const browser=await chromium.launch({executablePath:'/config/.cache/ms-playwright/chromium_headless_shell-1200/chrome-headless-shell-linux64/chrome-headless-shell',args:['--no-sandbox']})
const context=await browser.newContext({viewport:{width:1382,height:900}})
await context.addCookies([{name:'sysauth_http',value:session.admin.sid,url:session.base}])
const page=await context.newPage(),checks=[],errors=[]
const endpoint=session.base+'/cgi-bin/luci/admin/services/mise/request'
const redact=s=>[session.admin.sid,session.admin.token,session.readonly.sid,session.readonly.token].reduce((s,k)=>s.replaceAll(k,'[redacted]'),String(s))
page.on('pageerror',e=>errors.push(redact(e.message)))
async function request(value){const response=await context.request.post(endpoint,{form:{token:session.admin.token,request:JSON.stringify(value)}});return response.json()}
async function check(name,fn){await fn();checks.push({name,passed:true})}
async function storage(){await page.goto(session.base+'/cgi-bin/luci/admin/services/mise');await page.getByRole('button',{name:'存储与设置',exact:true}).click();await page.getByLabel('运行环境存放位置',{exact:true}).waitFor()}
let before,snapshot,captured,passed=false,error
try{
 await check('real API discovers both persistent disks and retains the configured custom root',async()=>{
  const response=await request({op:'read'});assert.equal(response.ok,true);before=response.value
  assert.ok(Array.isArray(before.storage_paths),'Storage read must expose disk choices')
  for(const p of ['/mnt/vio4-0/Configs/Runtime','/mnt/mise-runtime/Configs/Runtime',before.path])assert.ok(before.storage_paths.includes(p),p)
  assert.equal(before.storage_paths.length,3);assert.equal(new Set(before.storage_paths).size,3)
  assert.equal(before.storage_locked,true);assert.ok(before.runtimes.length>0)
 })
 await check('current real installation is selected and protected; other disks are visible',async()=>{
  await storage();const select=page.getByLabel('运行环境存放位置',{exact:true})
  assert.equal(await select.evaluate(e=>e.tagName),'SELECT');assert.equal(await select.inputValue(),before.path);assert.equal(await select.isDisabled(),true);assert.ok((await page.locator('.storage-home').textContent()).includes(before.path+'/home'))
  await page.getByText('查看其他硬盘目录',{exact:true}).click()
  await page.locator('.storage-options').getByText('/mnt/vio4-0/Configs/Runtime',{exact:true}).waitFor()
  await page.screenshot({path:path.join(out,'installed-storage.png'),fullPage:true})
 })
 await check('backend refuses moving existing SDKs without changing the active storage root',async()=>{
  const rejected=await request({op:'settings',path:'/mnt/vio4-0/Configs/Runtime',acceleration:before.acceleration})
  assert.equal(rejected.ok,false);assert.equal(rejected.error.code,'BUSY')
 })
 snapshot={...before,path:'',online:false,storage_locked:false,runtimes:[],libraries:[],tasks:[],warnings:[],storage_paths:before.storage_paths.filter(p=>p!==before.path)}
 // Never forward a settings save while displaying simulated first-use state.
 await page.route('**/mise/request',async route=>{
  const request=JSON.parse(new URLSearchParams(route.request().postData()).get('request'))
  if(request.op==='read')return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({schema_version:1,ok:true,value:snapshot})})
  if(request.op==='settings'){captured=request;return route.fulfill({status:400,contentType:'application/json',body:JSON.stringify({schema_version:1,ok:false,error:{code:'INVALID_INPUT',message:'Read-only UI regression: save intercepted'}})})}
  return route.continue()
 })
 await check('first-use form offers each real disk and submits the chosen path (save intercepted)',async()=>{
  await storage();const select=page.getByLabel('运行环境存放位置',{exact:true})
  assert.equal(await select.isDisabled(),false);assert.equal(await select.inputValue(),snapshot.storage_default)
  for(const p of snapshot.storage_paths){await select.selectOption(p);assert.equal(await select.inputValue(),p);assert.ok((await page.locator('.storage-home').textContent()).includes(p+'/home'))}
  const chosen='/mnt/vio4-0/Configs/Runtime';await select.selectOption(chosen)
  await page.getByRole('button',{name:'保存设置',exact:true}).click();await page.getByRole('alert').waitFor();assert.equal(captured.path,chosen)
 })
 await check('custom folder name is serialized as its actual path (save intercepted)',async()=>{
  await page.getByLabel('运行环境存放位置',{exact:true}).selectOption('__custom__')
  const chosen='/mnt/vio4-0/MyRuntime';await page.getByLabel('自定义存放目录',{exact:true}).fill(chosen)
  captured=undefined;await page.getByRole('button',{name:'保存设置',exact:true}).click();for(let i=0;i<50&&!captured;i++)await page.waitForTimeout(50);assert.equal(captured?.path,chosen)
 })
 await check('mobile custom-path form fits and no-disk state never defaults to /root',async()=>{
  await page.setViewportSize({width:390,height:900});await storage()
  assert.equal(await page.locator('.mise-surface').evaluate(e=>e.scrollWidth<=e.clientWidth+1),true)
  await page.screenshot({path:path.join(out,'first-use-storage-mobile.png'),fullPage:true})
  snapshot={...snapshot,storage_paths:[],storage_default:''};await storage()
  assert.equal(await page.getByLabel('运行环境存放位置',{exact:true}).inputValue(),'__custom__')
  assert.equal(await page.getByLabel('自定义存放目录',{exact:true}).inputValue(),'')
 })
 await check('read-only permission cannot edit storage; real SDKs and configuration remain unchanged',async()=>{
  const ro=await browser.newContext();await ro.addCookies([{name:'sysauth_http',value:session.readonly.sid,url:session.base}]);const rp=await ro.newPage()
  await rp.goto(session.base+'/cgi-bin/luci/admin/services/mise');await rp.getByRole('button',{name:'存储与设置',exact:true}).click()
  assert.equal(await rp.getByLabel('运行环境存放位置',{exact:true}).isDisabled(),true);assert.equal(await rp.getByRole('button',{name:'保存设置',exact:true}).isDisabled(),true);await ro.close()
  const after=(await request({op:'read'})).value
  assert.equal(after.path,before.path);assert.equal(after.revision,before.revision);assert.equal(after.acceleration,before.acceleration);assert.deepEqual(after.runtimes,before.runtimes);assert.deepEqual(after.tasks,before.tasks)
 })
 assert.deepEqual(errors,[]);passed=true
}catch(e){error=redact(e.message)}finally{
 await browser.close();fs.writeFileSync(path.join(out,'storage-paths-live.json'),JSON.stringify({passed,checks,error,pageErrors:errors,storage_paths:before?.storage_paths,storage_default:before?.storage_default},null,2)+'\n')
 console.log(JSON.stringify({passed,checks,error}));process.exitCode=passed?0:1
}
