import {pythonVenvHelper} from './python-venv.ts'
import {runtimeId,tools,rustHost,validVersion,type Runtime,type Language} from './runtime.ts'
export function wrapPath(store:string,r:Runtime){return `${store}/wrap/${r.id}`}
function quote(value:string){return "'"+value.replaceAll("'","'\\''")+"'"}
type Adapter={environment:(r:Runtime)=>string;userBin:string;directories:string;dispatch:string;help:string;examples:string[]}
// Explicit adapters keep language-specific toolchain behavior out of the UI.
const adapters:Record<Language,Adapter>={
 node:{environment:r=>`export MISE_NODE_VERSION=${quote(r.version)}
export npm_config_libc=${quote(r.libc)} npm_config_cache="$HOME/.cache/npm"
export npm_config_prefix="$HOME/.local/npm/${r.id}"`,userBin:'$npm_config_prefix/bin',directories:'',dispatch:` node) exec "$runtime/bin/node" "$@" ;;
 npm) exec "$runtime/bin/node" "$runtime/lib/node_modules/npm/bin/npm-cli.js" "$@" ;;`,help:'node / npm',examples:['node --version','npm --version']},
 python:{environment:r=>`export MISE_PYTHON_VERSION=${quote(r.version)}
unset PYTHONHOME PYTHONPATH PYTHONUSERBASE PYTHONEXECUTABLE __PYVENV_LAUNCHER__ PIP_USER PIP_PREFIX PIP_TARGET
export PYTHONNOUSERSITE=1 PIP_REQUIRE_VIRTUALENV=true
export PIP_CACHE_DIR="$HOME/.cache/pip" UV_CACHE_DIR="$HOME/.cache/uv"
export TMPDIR="$HOME/.cache/python/${r.id}/tmp"`,userBin:'$HOME/.local/bin',directories:'mkdir -p "$TMPDIR"',dispatch:` python|python3) exec "$runtime/bin/python3" "$@" ;;
 pip) case "\${1:---version}" in --version|-V|--help|-h) exec "$runtime/bin/python3" -m pip "$@" ;; *) echo '应用依赖请先创建虚拟环境，再使用 --venv <目录> pip install …' >&2; exit 2 ;; esac ;;`,help:'python / pip',examples:['python --version','pip --version']},
 go:{environment:r=>`export MISE_GO_VERSION=${quote(r.version)}
export GOROOT="$runtime" GOTOOLCHAIN=local GOENV=off
export GOPATH="$HOME/.local/go/${r.id}" GOBIN="$HOME/.local/go/${r.id}/bin"
export GOCACHE="$HOME/.cache/go/${r.id}/build" GOMODCACHE="$HOME/.cache/go/mod" GOTMPDIR="$HOME/.cache/go/${r.id}/tmp"
export CGO_ENABLED="\${CGO_ENABLED:-0}"`,userBin:'$GOBIN',directories:'mkdir -p "$GOPATH" "$GOBIN" "$GOCACHE" "$GOMODCACHE" "$GOTMPDIR"',dispatch:` go) exec "$runtime/bin/go" "$@" ;;
 gofmt) exec "$runtime/bin/gofmt" "$@" ;;`,help:'go / gofmt',examples:['go version','go env GOPATH GOCACHE']},
 rust:{environment:r=>`project_path="$(pwd -P)"
export MISE_RUST_VERSION=${quote(r.version)}
export RUSTUP_HOME="$store/rustup/${r.arch}-${r.libc}" RUSTUP_TOOLCHAIN=${quote(r.version+'-'+rustHost(r.arch,r.libc))} RUSTUP_AUTO_INSTALL=0
export CARGO_HOME="$HOME/.local/cargo/${r.id}"
export CARGO_TARGET_DIR="$HOME/.cache/cargo/${r.id}/target$project_path"
export RUSTC="$runtime/bin/rustc" RUSTDOC="$runtime/bin/rustdoc"
export TMPDIR="$HOME/.cache/cargo/${r.id}/tmp"`,userBin:'$CARGO_HOME/bin',directories:'mkdir -p "$CARGO_HOME" "$CARGO_TARGET_DIR" "$TMPDIR"',dispatch:` rustc) exec "$runtime/bin/rustc" "$@" ;;
 cargo) exec "$runtime/bin/cargo" "$@" ;;`,help:'rustc / cargo',examples:['rustc --version','cargo --version']},
 zig:{environment:r=>`project_path="$(pwd -P)"
export MISE_ZIG_VERSION=${quote(r.version)}
export ZIG_LIB_DIR="$runtime/lib"
export ZIG_GLOBAL_CACHE_DIR="$HOME/.cache/zig/${r.id}/global"
export ZIG_LOCAL_CACHE_DIR="$HOME/.cache/zig/${r.id}/local$project_path"
export TMPDIR="$HOME/.cache/zig/${r.id}/tmp"`,userBin:'$HOME/.local/bin',directories:'mkdir -p "$ZIG_GLOBAL_CACHE_DIR" "$ZIG_LOCAL_CACHE_DIR" "$TMPDIR"',dispatch:` zig) exec "$runtime/bin/zig" "$@" ;;`,help:'zig',examples:['zig version','zig env']},
 java:{environment:r=>`case "$HOME" in *'"'*) echo 'Java HOME 路径不能包含双引号' >&2; exit 1 ;; esac
export MISE_JAVA_VERSION=${quote(r.version)}
export JAVA_HOME="$runtime" JDK_HOME="$runtime"
export TMPDIR="$HOME/.cache/java/${r.id}/tmp"
# VM initialization options also reach javac/jar and shell child JVMs.
export JAVA_TOOL_OPTIONS="\${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-Duser.home=\\"$HOME\\" -Djava.io.tmpdir=\\"$TMPDIR\\""`,userBin:'$HOME/.local/bin',directories:'mkdir -p "$TMPDIR"',dispatch:` java) exec "$runtime/bin/java" "$@" ;;
 javac) exec "$runtime/bin/javac" "$@" ;;
 jar) exec "$runtime/bin/jar" "$@" ;;`,help:'java / javac / jar',examples:['java -version','javac -version','jar --version']},
}
export function wrapScript(store:string,r:Runtime){
 if(!/^\/mnt\/[A-Za-z0-9_./-]+$/.test(store)||store.split('/').some(x=>x==='..'||x==='.'))throw Error('需要持久存储目录')
 if(!Object.hasOwn(tools,r.language)||!tools[r.language].abis.includes(r.libc)||!validVersion(r.language,r.version)||!['x86_64','aarch64'].includes(r.arch)||r.id!==runtimeId(r.language,r.version,r.libc,r.arch))throw Error('无效的环境标识')
 const tool=tools[r.language].binary,adapter=adapters[r.language]
 return `#!/bin/sh
# Fixed runtime wrap contract. Generated preview; requires a manager-installed environment.
set -eu
store=${quote(store)}
runtime=${quote(store+'/environments/'+r.id)}
if [ ! -d "$store" ] || [ ! -x "$runtime/bin/${tool}" ]; then echo '运行环境未安装或磁盘未挂载，尚未创建 HOME。' >&2; exit 1; fi
uid="$(id -u)"
if [ "$uid" = 0 ]; then default_home="$store/home"; else default_home="$store/users/$uid/home"; fi
runtime_home="\${ISTORE_RUNTIME_HOME:-$default_home}"
case "$runtime_home" in /mnt/*) ;; *) echo 'HOME 必须位于持久磁盘 /mnt 下' >&2; exit 1 ;; esac
case "$runtime_home" in */../*|*/..|*/./*|*/.) echo 'HOME 路径无效' >&2; exit 1 ;; esac
export HOME="$runtime_home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_CACHE_HOME="$HOME/.cache" XDG_DATA_HOME="$HOME/.local/share"
export MISE_DATA_DIR="$store/mise/${r.arch}-${r.libc}"
export MISE_CONFIG_DIR="$store/users/$uid/mise/${r.arch}-${r.libc}/config" MISE_CACHE_DIR="$HOME/.cache/mise"
export ISTORE_RUNTIME_ID=${quote(r.id)}
${adapter.environment(r)}
export PATH="$runtime/bin:${adapter.userBin}:$PATH"
umask 077
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$MISE_CONFIG_DIR" "$MISE_CACHE_DIR"
${adapter.directories}
command="\${1:---shell}"
[ "$#" -eq 0 ] || shift
${r.language==='python'?`run_venv() {
 exec "$runtime/bin/python3" -c ${quote(pythonVenvHelper)} "$store" "$runtime" "$ISTORE_RUNTIME_ID" "$@"
}
case "$command" in
 --create-venv) run_venv create "$@"; exit $? ;;
 --venv) run_venv run "$@"; exit $? ;;
esac
if [ -n "\${VIRTUAL_ENV:-}" ]; then run_venv run "$VIRTUAL_ENV" "$command" "$@"; exit $?; fi`:''}
case "$command" in
 --shell) exec /bin/sh "$@" ;;
${adapter.dispatch}
 *) echo ${quote('支持：'+adapter.help+' / --shell')} >&2; exit 2 ;;
esac
`
}
export function usageCommands(store:string,r:Runtime){const p=quote(wrapPath(store,r));return [...adapters[r.language].examples.map(command=>`${p} ${command}`),`${p} --shell`]}

export function venvPathError(store:string,target:string){
 if(!target.startsWith('/mnt/')||target.split('/').some(x=>x==='.'||x==='..')||/[\x00-\x1f]/.test(target))return '请选择 /mnt 下的应用数据目录，不支持回退或控制字符。'
 const p=target.replace(/\/+/g,'/').replace(/\/$/,''),root=store.replace(/\/$/,'')
 if(p===root||root.startsWith(p+'/')||['environments','mise','rustup','wrap'].some(x=>p===root+'/'+x||p.startsWith(root+'/'+x+'/')))return '不能使用公共 SDK 或运行时管理目录。'
 return ''
}
export function pythonProjectCommands(store:string,r:Runtime,target:string){if(r.language!=='python'||venvPathError(store,target))return [];const p=quote(wrapPath(store,r)),v=quote(target);return [`${p} --create-venv ${v}`,`${p} --venv ${v} pip install -r requirements.txt`,`${p} --venv ${v} python app.py`,`${p} --venv ${v} --shell`]}
