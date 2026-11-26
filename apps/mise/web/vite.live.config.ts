import {defineConfig} from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'node:path'
export default defineConfig({
 plugins:[vue(),{name:'production-boundary',generateBundle(){
  const modules=[...this.getModuleIds()].filter(id=>!id.startsWith('\0')).sort()
  for(const id of modules)if(/\/src\/(design|quickstart\/design|domain\/(catalog|runtime|wrap|python-venv))\b/.test(id))this.error('Design module in production graph: '+id)
  this.emitFile({type:'asset',fileName:'modules.audit.json',source:JSON.stringify(modules,null,2)})
 }}],base:'./',
 cacheDir:path.join(process.env.BUILD_CACHE_WORK_DIR||'/tmp/mise-live','mise-live-vite'),
 build:{outDir:path.join(process.env.BUILD_CACHE_WORK_DIR||'/tmp/mise-live','mise-live-dist'),emptyOutDir:true,cssCodeSplit:false,
  rollupOptions:{input:path.resolve(__dirname,'src/live/main.ts'),output:{entryFileNames:'app.js',chunkFileNames:'chunk-[hash].js',assetFileNames:asset=>asset.names?.some(n=>n.endsWith('.css'))?'style.css':'[name][extname]'}}}
})
