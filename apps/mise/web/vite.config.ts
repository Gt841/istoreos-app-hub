import {defineConfig} from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'node:path'
export default defineConfig({
  plugins:[vue()],base:'/',
  resolve:{alias:{'/@':path.resolve(__dirname,'src/quickstart')}},
  cacheDir:path.join(process.env.BUILD_CACHE_WORK_DIR || '/tmp/mise-design','mise-vite'),
  build:{outDir:path.join(process.env.BUILD_CACHE_WORK_DIR || '/tmp/mise-design','mise-design-dist'),emptyOutDir:true},
})
