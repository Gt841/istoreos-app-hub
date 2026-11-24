import {chromium} from 'playwright'
import fs from 'node:fs'
import path from 'node:path'
import assert from 'node:assert/strict'
const base=process.env.MISE_DESIGN_URL||'http://127.0.0.1:5180',out=process.env.MISE_DESIGN_EVIDENCE
if(!out)throw Error('MISE_DESIGN_EVIDENCE required')
fs.mkdirSync(out,{recursive:true})
const browser=await chromium.launch({headless:true,executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE||'/config/.cache/ms-playwright/chromium_headless_shell-1200/chrome-headless-shell-linux64/chrome-headless-shell',args:['--no-sandbox']})
const context=await browser.newContext({viewport:{width:1440,height:1000}}),page=await context.newPage(),results=[],errors=[]
page.on('pageerror',e=>errors.push(e.message))
const dialog=()=>page.getByRole('dialog'),state=async()=>(await page.request.get(base+'/__design/api/state')).json()
async function capture(file){await page.evaluate(()=>scrollTo(0,0));await page.locator('.host-system-menu').evaluate(async el=>{await Promise.all(el.getAnimations().map(a=>a.finished.catch(()=>{})));await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))});await page.screenshot({path:path.join(out,file),fullPage:true})}
async function check(name,fn){try{await fn();results.push({name,passed:true});console.log('PASS '+name)}catch(e){results.push({name,passed:false,error:e.stack});console.log('FAIL '+name+': '+e.message);await capture('java-failure-'+results.length+'.png').catch(()=>{})}}
async function scene(name='ready',arch='x86_64'){
 await page.goto(base+'/mise');await page.waitForFunction(()=>document.querySelector('.design-host')?.dataset.previewReady==='true')
 const controls=page.locator('.design-controls');await controls.evaluate(el=>el.open=true);const generation=Number(await page.locator('.design-host').getAttribute('data-preview-generation'))
 await page.getByLabel('预览场景',{exact:true}).selectOption(name);await page.getByLabel('示例架构').selectOption(arch);await page.getByRole('button',{name:'载入场景',exact:true}).click()
 await page.waitForFunction(g=>{const el=document.querySelector('.design-host');return el.dataset.previewReady==='true'&&Number(el.dataset.previewGeneration)>g},generation);await controls.evaluate(el=>el.open=false)
}
async function open(version='temurin-25.0.1+8'){
 await page.getByRole('button',{name:'Java',exact:true}).click();await page.getByRole('button',{name:'＋ 安装环境',exact:true}).click();await dialog().getByLabel('版本',{exact:true}).selectOption(version)
 assert.equal(await dialog().getByLabel('运行环境',{exact:true}).count(),0);assert.equal(await dialog().getByLabel('npm 版本',{exact:true}).count(),0)
 assert.equal(await dialog().getByLabel('版本',{exact:true}).locator('option').count(),2);assert.ok((await dialog().getByLabel('版本',{exact:true}).innerText()).includes('LTS'))
 await dialog().getByText(/首版使用私有 glibc/).waitFor()
}
async function review(){await dialog().getByRole('button',{name:'检查安装内容',exact:true}).click();await dialog().getByText('发行版：Eclipse Temurin · 完整 JDK，固定构建号；本轮只提供 glibc',{exact:true}).waitFor()}
async function submit(){await dialog().getByRole('button',{name:'开始安装',exact:true}).click();await dialog().getByRole('button',{name:'后台继续',exact:true}).waitFor()}
async function done(status='success'){let complete=false;for(let i=0;i<100;i++){const s=await state();if(s.tasks[0]?.status===status){complete=true;break}await page.waitForTimeout(150)}assert.ok(complete,`expected ${status}`);await dialog().getByText((await state()).tasks[0].result,{exact:true}).waitFor()}
for(const arch of ['x86_64','aarch64'])await check(`Java ${arch} 版本/发行版、复核、刷新续看、四个 wrap 命令、清理与默认保护`,async()=>{
 await scene('ready',arch);const before=await state();await open();await review();await submit();await dialog().getByRole('button',{name:'后台继续',exact:true}).click();await page.reload();await page.getByRole('navigation',{name:'运行时管理'}).getByRole('button',{name:'任务记录',exact:true}).click();await page.getByRole('button',{name:'查看任务',exact:true}).first().click();await done()
 await dialog().getByRole('button',{name:'查看使用方法'}).click();assert.match(await dialog().getByLabel('使用命令 1').inputValue(),new RegExp(`java-temurin-25.0.1\\+8-${arch}-glibc.*java -version`));assert.match(await dialog().getByLabel('使用命令 2').inputValue(),/javac -version/);assert.match(await dialog().getByLabel('使用命令 3').inputValue(),/jar --version/);assert.match(await dialog().getByLabel('使用命令 4').inputValue(),/--shell/)
 await dialog().getByRole('button',{name:'复制',exact:true}).nth(2).click();await dialog().getByRole('status').waitFor()
 const download=page.waitForEvent('download');await dialog().getByRole('button',{name:'下载 wrap 样例'}).click();await(await download).saveAs(path.join(out,`java-${arch}-wrap.sh`));const source=fs.readFileSync(path.join(out,`java-${arch}-wrap.sh`),'utf8');for(const key of ['JAVA_HOME=','JAVA_TOOL_OPTIONS=','-Duser.home=','-Djava.io.tmpdir='])assert.ok(source.includes(key),key);assert.ok(!source.includes('export LD_LIBRARY_PATH'));assert.deepEqual((await state()).defaults,before.defaults)
 await dialog().getByRole('button',{name:'完成',exact:true}).click();const id=`java-temurin-25.0.1+8-${arch}-glibc`;await page.locator(`[data-runtime="${id}"]`).getByRole('button',{name:'详情',exact:true}).click();await dialog().getByText('Eclipse Temurin · 完整 JDK · LTS',{exact:true}).waitFor();await dialog().getByRole('button',{name:'清理环境'}).click();await dialog().getByText(/固定 wrap 入口将失效/).waitFor();await dialog().getByRole('button',{name:'确认清理'}).click();assert.equal((await state()).runtimes.some(r=>r.id===id),false)
 await page.locator(`[data-runtime="${before.defaults.java}"]`).getByRole('button',{name:'详情',exact:true}).click();assert.equal(await dialog().getByRole('button',{name:'清理环境'}).isDisabled(),true);await page.keyboard.press('Escape')
})
await check('首次安装 Java 同时准备 glibc，完成后可用且不更改全局默认',async()=>{
 await scene('first');await page.getByRole('button',{name:'设置存储位置'}).first().click();await page.getByLabel('运行环境存放位置').fill('/mnt/data/Runtime');await page.getByRole('button',{name:'保存设置'}).click();await page.getByRole('navigation',{name:'运行时管理'}).getByRole('button',{name:'运行环境',exact:true}).click();await open('temurin-21.0.9+10');await review();await dialog().getByText('同时准备 glibc 2.39 与 C++ 运行库',{exact:true}).waitFor();await submit();await done();const s=await state();assert.equal(s.glibc,true);assert.equal(s.runtimes.length,1);assert.equal(s.defaults.java,null)
})
await check('Java 校验失败不提交、明确重试后成功',async()=>{
 await scene('integrity');const before=await state();await open();await review();await submit();await done('failed');assert.deepEqual((await state()).runtimes,before.runtimes);await dialog().getByRole('button',{name:'重新检查'}).click();assert.equal(await dialog().getByLabel('语言',{exact:true}).inputValue(),'java');assert.equal(await dialog().getByLabel('版本',{exact:true}).inputValue(),'temurin-25.0.1+8');await review();await submit();await done()
})
await check('Java 拒绝不支持的 musl/发行版/浮动版本；六种语言切换正确重置字段',async()=>{
 await scene();for(const [version,libc] of [['temurin-25.0.1+8','musl'],['25','glibc'],['zulu-25.0.1+8','glibc']]){const r=await page.request.post(base+'/__design/api/action',{data:{action:'plan',input:{kind:'install',language:'java',version,libc,source:'origin'}}});assert.equal(r.status(),400)}
 await page.getByRole('button',{name:'＋ 安装环境',exact:true}).click();await dialog().getByLabel('运行环境',{exact:true}).selectOption('musl');await dialog().getByLabel('语言',{exact:true}).selectOption('java');assert.equal(await dialog().getByLabel('运行环境',{exact:true}).count(),0);assert.equal(await dialog().getByLabel('npm 版本',{exact:true}).count(),0);await review();await dialog().getByText('x86_64 · 私有 glibc 2.39',{exact:true}).waitFor();await page.keyboard.press('Escape');assert.equal((await state()).tasks.length,0)
})
await check('Java 与六种语言在桌面、320/390 手机深浅主题下无溢出',async()=>{
 await scene();for(const width of [1440,390,320])for(const theme of ['light','dark']){
  await page.setViewportSize({width,height:width===1440?1000:844});await page.locator('[data-theme-selector]>summary').click();await page.getByRole('radio',{name:theme==='light'?/^浅色/:/^深色/}).click();await page.waitForFunction(t=>document.querySelector('.mise-surface').dataset.theme===t,theme)
  for(const name of ['Node.js / npm','Python','Go','Rust','Zig','Java']){await page.getByRole('button',{name,exact:true}).click();assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true,`${width}/${theme}/${name}`)}
  await capture(`java-${width}-${theme}.png`);await page.getByRole('button',{name:'＋ 安装环境',exact:true}).click();assert.equal(await dialog().evaluate(el=>el.getBoundingClientRect().left>=0&&el.getBoundingClientRect().right<=innerWidth),true);await capture(`java-${width}-${theme}-install.png`);await page.keyboard.press('Escape');await page.locator('[data-runtime="java-temurin-21.0.9+10-x86_64-glibc"]').getByRole('button',{name:'使用此版本'}).click();await dialog().getByLabel('使用命令 4').waitFor();await capture(`java-${width}-${theme}-usage.png`);await page.keyboard.press('Escape')
 }
 assert.deepEqual(errors,[])
})
await browser.close();const report={passed:results.every(r=>r.passed),results,pageErrors:errors};fs.writeFileSync(path.join(out,'java-browser.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({checks:results.length,passed:results.filter(r=>r.passed).length}));process.exitCode=report.passed?0:1
