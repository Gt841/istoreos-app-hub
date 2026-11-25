// Real runtime binding and visible ABI; never alter application configuration.
import fs from 'node:fs'
import path from 'node:path'
import assert from 'node:assert/strict'
import {createRequire} from 'node:module'
const {chromium}=createRequire(new URL('../../mise/web/package.json',import.meta.url))('playwright')
const session=JSON.parse(fs.readFileSync(process.env.OPENCLAWMGR_LUCI_SESSION,'utf8'))
const output=process.env.OPENCLAWMGR_LUCI_EVIDENCE;assert(output);fs.mkdirSync(output,{recursive:true})
const browser=await chromium.launch({headless:true,executablePath:'/config/.cache/ms-playwright/chromium_headless_shell-1200/chrome-headless-shell-linux64/chrome-headless-shell',args:['--no-sandbox']})
const context=await browser.newContext({viewport:{width:1280,height:1000}})
await context.addCookies([{name:'sysauth_http',value:session.admin.sid,url:session.base}])
const secrets=[session.admin.sid,session.admin.token],checks=[]
const redact=v=>secrets.filter(Boolean).reduce((s,k)=>s.replaceAll(k,'[redacted]'),String(v))
async function check(name,fn){await fn();checks.push({name,passed:true})}
let passed=false,error,info
try{
 const response=await context.request.get(session.base+'/cgi-bin/luci/admin/services/openclawmgr/status')
 const data=await response.json();secrets.push(data.token)
 await check('status describes the verified fixed GNU Node binding',async()=>{
  info=data.runtime_info
  assert.ok(info,'Runtime status must expose the verified runtime binding and ABI')
  assert.equal(info.provider,'mise-runtime');assert.equal(info.abi,'glibc')
  assert.equal(info.node,'24.22.1');assert.equal(info.npm,'11.19.1')
  assert.equal(info.libc.version,'2.39');assert.ok(info.instance.includes('-glibc-'))
 })
 const page=await context.newPage()
 await page.goto(session.base+'/cgi-bin/luci/admin/services/openclawmgr/config')
 await check('service card visibly distinguishes glibc from the Node version',async()=>{
  await page.locator('#oclm-runtime-abi').waitFor()
  assert.equal(await page.locator('#oclm-runtime-abi').textContent(),'glibc 2.39')
  assert.equal(await page.locator('#oclm-runtime-source').textContent(),'mise 固定运行时')
  assert.equal(await page.locator('#oclm-runtime-source').getAttribute('href'),'/cgi-bin/luci/admin/services/mise')
  assert.equal(await page.locator('#oclm-runtime-source').getAttribute('title'),info.instance)
 })
 await check('missing runtime metadata never claims glibc',async()=>{
  await page.route('**/openclawmgr/status',route=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({...data,runtime_info:null})}))
  await page.reload();await page.locator('#oclm-runtime-unknown').waitFor()
  assert.equal(await page.locator('#oclm-runtime-abi').isVisible(),false)
  await page.unroute('**/openclawmgr/status')
 })
 await check('real runtime badges fit the mobile service card',async()=>{
  await page.setViewportSize({width:390,height:900});await page.reload()
  await page.locator('#oclm-runtime-abi').waitFor()
  assert.equal(await page.locator('#oclm-runtime-abi').textContent(),'glibc 2.39')
  assert.equal(await page.locator('#oclm-runtime-source').evaluate(el=>el.getBoundingClientRect().right<=innerWidth+1),true)
 })
 await page.screenshot({path:path.join(output,'runtime-info.png'),fullPage:true})
 passed=true
}catch(e){error=redact(e.message)}finally{
 await browser.close()
 fs.writeFileSync(path.join(output,'runtime-info-live.json'),JSON.stringify({passed,checks,error,runtime_info:info},null,2)+'\n')
 console.log(JSON.stringify({passed,checks,error}));process.exitCode=passed?0:1
}
