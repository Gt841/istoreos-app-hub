// Read-only directory selection against real LuCI; never save or move data.
import fs from 'node:fs'
import path from 'node:path'
import assert from 'node:assert/strict'
import {createRequire} from 'node:module'
const {chromium}=createRequire(new URL('../../mise/web/package.json',import.meta.url))('playwright')
const session=JSON.parse(fs.readFileSync(process.env.OPENCLAWMGR_LUCI_SESSION,'utf8'))
const output=process.env.OPENCLAWMGR_LUCI_EVIDENCE
assert(output);fs.mkdirSync(output,{recursive:true})
const browser=await chromium.launch({headless:true,executablePath:'/config/.cache/ms-playwright/chromium_headless_shell-1200/chrome-headless-shell-linux64/chrome-headless-shell',args:['--no-sandbox']})
const context=await browser.newContext({viewport:{width:1280,height:1000}})
await context.addCookies([{name:'sysauth_http',value:session.admin.sid,url:session.base}])
const checks=[],secrets=[session.admin.sid,session.admin.token]
const redact=v=>secrets.filter(Boolean).reduce((s,k)=>s.replaceAll(k,'[redacted]'),String(v))
async function check(name,fn){await fn();checks.push({name,passed:true})}
let passed=false,error,paths,current
try{
 const response=await context.request.get(session.base+'/cgi-bin/luci/admin/services/openclawmgr/config_data')
 const data=await response.json();assert.equal(data.ok,true)
 secrets.push(data.config.token,data.config.provider_api_key)
 paths=data.options.base_dir_choices;current=data.config.base_dir
 await check('actual mounted disks provide standard Configs paths',async()=>{
  assert.ok(paths.includes('/mnt/vio4-0/Configs/OpenClawMgr'))
  assert.ok(paths.includes('/mnt/mise-runtime/Configs/OpenClawMgr'))
 })
 const page=await context.newPage()
 await page.goto(session.base+'/cgi-bin/luci/admin/services/openclawmgr/config')
 const selector=page.locator('#oclm-base-dir');await selector.waitFor()
 await check('data directory exposes an explicit disk dropdown',async()=>{
  assert.equal(await selector.evaluate(el=>el.tagName),'SELECT','Data directory must expose selectable disk choices')
  assert.equal(await selector.inputValue(),current)
  assert.ok((await selector.locator('option:checked').textContent()).startsWith('当前目录 · '))
  for(const dir of paths)assert.equal(await selector.locator('option').filter({hasText:dir}).count(),1)
 })
 await check('selecting another disk edits the form without migrating data',async()=>{
  await selector.selectOption('/mnt/vio4-0/Configs/OpenClawMgr')
  assert.equal(await selector.inputValue(),'/mnt/vio4-0/Configs/OpenClawMgr')
  assert.ok(!(await selector.locator('option:checked').textContent()).startsWith('当前目录 · '))
  const after=await(await context.request.get(session.base+'/cgi-bin/luci/admin/services/openclawmgr/config_data')).json()
  assert.equal(after.config.base_dir,current)
 })
 await check('custom directory entry remains available',async()=>{
  await selector.selectOption('__custom__')
  const custom=page.locator('#oclm-base-dir-custom');await custom.waitFor()
  await custom.fill('/mnt/vio4-0/Configs/My OpenClaw')
  assert.equal(await custom.inputValue(),'/mnt/vio4-0/Configs/My OpenClaw')
  // Stop this POST before the device: verify serialization without saving,
  // restarting the running Gateway or changing its data directory.
  const submitted=[]
  await page.route('**/openclawmgr/config_data',async route=>{
   if(route.request().method()==='POST'){
    submitted.push(JSON.parse(route.request().postData()))
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({ok:false,error:'Directory test: request intercepted before save'})})
   }else await route.continue()
  })
  await page.locator('#oclm-save-basic').click()
  await page.getByText('Directory test: request intercepted before save',{exact:true}).waitFor()
  assert.equal(submitted.length,1)
  assert.equal(submitted[0].base_dir,'/mnt/vio4-0/Configs/My OpenClaw')
  await page.unroute('**/openclawmgr/config_data')
  await page.reload();await page.locator('#oclm-base-dir').waitFor()
  assert.equal(await page.locator('#oclm-base-dir').inputValue(),current)
 })
 await check('directory dropdown stays inside the mobile workspace',async()=>{
  await page.setViewportSize({width:390,height:900});await page.reload()
  await page.locator('#oclm-base-dir').waitFor()
  const fits=await page.locator('#oclm-base-dir').evaluate(el=>el.getBoundingClientRect().right<=window.innerWidth+1)
  assert.equal(fits,true)
 })
 // Status/security responses can replace the form after initial load. Capture
 // the page rather than an element handle that may detach during font loading.
 await page.screenshot({path:path.join(output,'directory-selector.png'),fullPage:true})
 passed=true
}catch(e){error=redact(e.message)}finally{
 await browser.close()
 fs.writeFileSync(path.join(output,'directories-live.json'),JSON.stringify({passed,checks,error,paths,current},null,2)+'\n')
 console.log(JSON.stringify({passed,checks,error}));process.exitCode=passed?0:1
}
