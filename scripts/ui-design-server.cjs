// Preview only: serves built assets and an in-memory design service. No device API proxy.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto');
const {pathToFileURL}=require('node:url');
const root=path.resolve(__dirname,'..'),port=Number(process.env.ISTORE_UI_DESIGN_PORT||5180);
(async()=>{
 const {fixture,command,tick,scenes}=await import(pathToFileURL(path.join(root,'apps/mise/web/src/design/model.ts')));
 const deps=path.join(process.env.BUILD_CACHE_WORK_DIR,'mise-web-deps/node_modules');
 const {build}=await import(pathToFileURL(path.join(deps,'vite/dist/node/index.js')));
 await build({root:path.join(root,'apps/mise/web'),configFile:path.join(root,'apps/mise/web/vite.config.ts')});
 const dist=path.join(process.env.BUILD_CACHE_WORK_DIR,'mise-design-dist');
 const sessions=new Map(),limit=100;const step=Number(process.env.MISE_DESIGN_STEP_MS||1200);
 const send=(res,code,data)=>{res.writeHead(code,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(JSON.stringify(data))};
 const server=http.createServer(async(req,res)=>{
  try{
   const url=new URL(req.url,'http://preview.invalid');
   if(url.pathname==='/health')return send(res,200,{owner:root,app:'mise',pid:process.pid,mode:'design-fixtures'});
   if(url.pathname.startsWith('/cgi-bin/')||url.pathname.startsWith('/apps/'))return send(res,403,{error:'Design server never forwards device requests'});
   if(url.pathname.startsWith('/__design/api/')){
    let id=(req.headers.cookie||'').match(/(?:^|; )mise_preview=([a-f0-9]{32})(?:;|$)/)?.[1];
    if(!id||!sessions.has(id)){id=crypto.randomBytes(16).toString('hex');if(sessions.size>=limit)sessions.delete(sessions.keys().next().value);sessions.set(id,fixture());res.setHeader('Set-Cookie',`mise_preview=${id}; HttpOnly; SameSite=Strict; Path=/`)}
    const state=sessions.get(id);tick(state,Date.now(),step);
    if(req.method==='GET'&&url.pathname==='/__design/api/state')return send(res,200,state);
    if(req.method!=='POST')return send(res,405,{error:'POST required'});
    if(req.headers.origin&&req.headers.origin!==`http://${req.headers.host}`)return send(res,403,{error:'Same-origin requests only'});
    if(!String(req.headers['content-type']).startsWith('application/json'))return send(res,415,{error:'JSON required'});
    let raw='';for await(const chunk of req){raw+=chunk;if(raw.length>16384)return send(res,413,{error:'Request too large'})}
    const body=JSON.parse(raw||'{}');
    if(url.pathname==='/__design/api/scene'){
     if(!scenes.includes(body.scene)||!['x86_64','aarch64'].includes(body.arch))return send(res,400,{error:'Unknown design scene'});
     sessions.set(id,fixture(body.scene,body.arch));return send(res,200,{state:sessions.get(id),value:null});
    }
    if(url.pathname!=='/__design/api/action')return send(res,404,{error:'Unknown preview endpoint'});
    const value=command(state,body.action,body.input||{});return send(res,200,{state,value});
   }
   if(req.method!=='GET'&&req.method!=='HEAD')return send(res,405,{error:'Read only assets'});
   const filename=path.resolve(dist,'.'+decodeURIComponent(url.pathname));
   if(filename!==dist&&!filename.startsWith(dist+path.sep))return send(res,403,{error:'Invalid asset path'});
   let file=filename;if(!fs.existsSync(file)||fs.statSync(file).isDirectory())file=path.join(dist,'index.html');
   const ext=path.extname(file),types={'.html':'text/html; charset=utf-8','.js':'application/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml'};
   res.writeHead(200,{'Content-Type':types[ext]||'application/octet-stream','Cache-Control':'no-cache','Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'self'",'X-Content-Type-Options':'nosniff'});
   if(req.method==='HEAD')return res.end();fs.createReadStream(file).pipe(res);
  }catch(error){send(res,400,{error:error.message||'Preview request failed'})}
 });
 const timer=setInterval(()=>{for(const state of sessions.values())tick(state,Date.now(),step)},300);
 server.listen(port,process.env.ISTORE_UI_DESIGN_HOST||'0.0.0.0',()=>console.log(`mise design: http://127.0.0.1:${port}/mise`));
 server.on('error',error=>{console.error(error);clearInterval(timer);process.exit(1)});
 for(const signal of ['SIGINT','SIGTERM'])process.on(signal,()=>{clearInterval(timer);server.close(()=>process.exit(0));server.closeIdleConnections()});
})().catch(error=>{console.error(error);process.exit(1)});
