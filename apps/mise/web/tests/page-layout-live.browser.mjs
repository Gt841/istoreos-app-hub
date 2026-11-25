import {chromium} from 'playwright'
import fs from 'node:fs'
import assert from 'node:assert/strict'
const session=JSON.parse(fs.readFileSync(process.env.MISE_LIVE_SESSION,'utf8'))
const out=process.env.MISE_LIVE_EVIDENCE;assert(out);fs.mkdirSync(out,{recursive:true})
const browser=await chromium.launch({executablePath:'/config/.cache/ms-playwright/chromium_headless_shell-1200/chrome-headless-shell-linux64/chrome-headless-shell',args:['--no-sandbox']})
const context=await browser.newContext();await context.addCookies([{name:'sysauth_http',value:session.admin.sid,url:session.base}])
const page=await context.newPage(),checks=[],measurements=[],errors=[]
page.on('pageerror',e=>errors.push(e.message))
let passed=false,error
try{
 for(const width of [2048,1440,1024,390]){
  await page.setViewportSize({width,height:1000});await page.goto(session.base+'/cgi-bin/luci/admin/services/mise')
  await page.getByRole('button',{name:'存储与设置',exact:true}).click()
  await page.locator('.settings-form').waitFor()
  const result=await page.evaluate(()=>{
   const box=e=>{const r=e.getBoundingClientRect();return{x:r.x,y:r.y,width:r.width,height:r.height}}
   const root=document.querySelector('#mise-app'),content=document.querySelector('.runtime-product'),panel=document.querySelector('.workspace-panel')
   const ancestors=[];for(let e=root;e&&ancestors.length<6;e=e.parentElement)ancestors.push({tag:e.tagName,class:e.className,box:box(e)})
   return{surface:box(root),content:box(content),panel:box(panel),ancestors,
    headings:[...root.querySelectorAll('h1,h2,h3')].map(e=>({tag:e.tagName,text:e.textContent,shadow:getComputedStyle(e).boxShadow,after:{content:getComputedStyle(e,'::after').content,display:getComputedStyle(e,'::after').display}})),
    libraryRows:[...root.querySelectorAll('.library-row')].map(e=>({description:box(e.querySelector('p')),code:box(e.querySelector('.mono'))})),
    overflow:document.documentElement.scrollWidth>innerWidth+1}
  })
  measurements.push({width,...result});await page.screenshot({path:`${out}/storage-${width}.png`,fullPage:true})
  assert(result.content.width>=result.surface.width*.94,`At ${width}px content uses only ${(result.content.width/result.surface.width*100).toFixed(1)}% of available width`)
  assert(!result.overflow,`Horizontal overflow at ${width}px`)
  for(const r of result.libraryRows)assert(r.description.y+r.description.height<=r.code.y-4,'Runtime library description overlaps its code block')
  for(const h of result.headings){assert(h.after.content==='none'||h.after.content==='normal'||h.after.display==='none',`Theme decoration leaks into ${h.text}`);assert.equal(h.shadow,'none',`Theme heading shadow leaks into ${h.text}`)}
  if(width>=1600)assert(result.panel.width>=Math.min(1640,result.surface.width-48)-2,'Workspace did not expand like QuickStart')
  checks.push({name:`full-width storage and clean headings at ${width}px`,passed:true})
 }
 await page.setViewportSize({width:1440,height:1000})
 for(const name of ['运行环境','任务记录']){
  await page.getByRole('button',{name,exact:true}).click()
  assert(await page.locator('.runtime-product').evaluate(e=>e.scrollWidth<=e.clientWidth+1),name+' overflows')
  checks.push({name:`${name} tab fits the expanded workspace`,passed:true})
 }
 await page.getByRole('button',{name:'存储与设置',exact:true}).click()
 await page.evaluate(()=>document.body.dataset.quickstartTheme='dark')
 await page.waitForFunction(()=>document.querySelector('#mise-app').dataset.theme==='dark')
 assert(await page.locator('.section-heading h2').first().evaluate(e=>getComputedStyle(e).color===getComputedStyle(document.querySelector('#mise-app')).color),'Dark heading color must use QuickStart text token')
 await page.screenshot({path:out+'/storage-dark.png',fullPage:true})
 checks.push({name:'dark headings use QuickStart semantic text color',passed:true})
 assert.deepEqual(errors,[]);passed=true
}catch(e){error=String(e.message)}finally{
 await browser.close();fs.writeFileSync(out+'/layout.json',JSON.stringify({passed,checks,measurements,error,pageErrors:errors},null,2)+'\n')
 console.log(JSON.stringify({passed,checks,error}));process.exitCode=passed?0:1
}
