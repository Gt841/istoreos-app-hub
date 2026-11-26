import {chromium}from'playwright'
import fs from'node:fs'
import path from'node:path'
import assert from'node:assert/strict'
const s=JSON.parse(fs.readFileSync(process.env.MISE_LIVE_SESSION,'utf8')),out=process.env.MISE_LIVE_EVIDENCE
if(!out)throw Error('Evidence path required');fs.mkdirSync(out,{recursive:true})
const browser=await chromium.launch({headless:true,executablePath:'/config/.cache/ms-playwright/chromium_headless_shell-1200/chrome-headless-shell-linux64/chrome-headless-shell',args:['--no-sandbox']})
const context=await browser.newContext({viewport:{width:1440,height:1000}});await context.addCookies([{name:'sysauth_http',value:s.admin.sid,url:s.base}]);const page=await context.newPage(),errors=[],results=[]
page.on('pageerror',e=>errors.push(e.message))
async function api(request){const r=await context.request.post(s.base+'/cgi-bin/luci/admin/services/mise/request',{form:{token:s.admin.token,request:JSON.stringify(request)}});const v=await r.json();assert.equal(v.ok,true,v.error?.code);return v.value}
async function check(name,fn){try{await fn();results.push({name,passed:true});console.log('PASS '+name)}catch(e){results.push({name,passed:false,error:e.message});console.log('FAIL '+name+': '+e.message);throw e}}
try{
 const before=await api({op:'read'});assert.equal(before.runtimes.length,1);assert.ok(!before.tasks.some(t=>['running','interrupted'].includes(t.status)))
 await check('real stale-plan error uses QuickStart semantic colors in the native host',async()=>{
  await page.goto(s.base+'/cgi-bin/luci/admin/services/mise');await page.locator('.runtime-row').waitFor();await page.getByRole('button',{name:'＋ 安装环境',exact:true}).click();await page.getByLabel('版本',{exact:true}).selectOption('24.22.1');await page.getByLabel('运行环境',{exact:true}).selectOption('glibc');await page.getByRole('button',{name:'检查安装内容',exact:true}).click();await page.getByRole('button',{name:'开始安装',exact:true}).waitFor();await api({op:'cache-clear'});await page.getByRole('button',{name:'开始安装',exact:true}).click();const alert=page.locator('dialog.mise-dialog [role=alert]');await alert.getByText(/安装计划已过期/).waitFor()
  for(const[theme,color]of[['light','rgb(240, 245, 255)'],['dark','rgb(44, 62, 89)']]){await page.evaluate(t=>document.body.setAttribute('theme',t),theme);await page.waitForFunction(t=>document.querySelector('.mise-surface').dataset.theme===t,theme);assert.equal(await alert.evaluate(e=>getComputedStyle(e).backgroundColor),color);await page.screenshot({path:path.join(out,'real-stale-plan-'+theme+'.png'),fullPage:false})}
  await page.keyboard.press('Escape');const after=await api({op:'read'});assert.deepEqual(after.runtimes,before.runtimes);assert.equal(after.tasks.length,before.tasks.length)
 })
 await check('fresh desktop and mobile host initialization; theme, full content width and focus',async()=>{
  for(const width of[1440,390,320])for(const theme of['light','dark']){
   await page.setViewportSize({width,height:900});await page.reload();await page.locator('.runtime-row').waitFor();if(width<650&&await page.locator('.mise-surface').evaluate(e=>e.getBoundingClientRect().width)<width-64){await page.locator('header .showSide').click();await page.waitForFunction(w=>document.querySelector('.mise-surface').getBoundingClientRect().width>=w-64,width)}
   await page.evaluate(t=>document.body.setAttribute('theme',t),theme);await page.waitForFunction(t=>document.querySelector('.mise-surface').dataset.theme===t,theme);assert.equal(await page.locator('.mise-surface').evaluate(e=>e.scrollWidth<=e.clientWidth+1),true);await page.screenshot({path:path.join(out,`real-host-${width}-${theme}.png`),fullPage:true})
  }
  const opener=page.locator('.runtime-row').getByRole('button',{name:'使用此版本',exact:true});await opener.click();const dialog=page.locator('dialog.mise-dialog');assert.equal(await dialog.evaluate(e=>e.contains(document.activeElement)),true);await page.keyboard.press('Escape');assert.equal(await opener.evaluate(e=>document.activeElement===e),true);assert.deepEqual(errors,[])
 })
}catch{}finally{await browser.close();const report={passed:results.length===2&&results.every(r=>r.passed),results,pageErrors:errors};fs.writeFileSync(path.join(out,'production-host.json'),JSON.stringify(report,null,2)+'\n');process.exitCode=report.passed?0:1}
