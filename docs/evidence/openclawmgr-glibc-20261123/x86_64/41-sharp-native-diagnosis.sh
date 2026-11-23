set -u
base="$(uci -q get openclawmgr.main.base_dir)"
for txn in "$base"/.install.*; do
 pkg="$txn/candidate/global/lib/node_modules/openclaw/node_modules"
 printf '%s\n' '== selected sharp platform packages'
 ls "$pkg/@img" 2>/dev/null || true
 "$txn/candidate/node/bin/node" -e 'const {createRequire}=require("node:module");const load=createRequire(process.argv[1]);for(const name of ["@img/sharp-linux-x64/sharp.node","@img/sharp-linuxmusl-x64/sharp.node"]){try{load(name);console.log(name+": OK");}catch(e){console.log(name+": "+e.message);}}' "$pkg/../package.json"
done
