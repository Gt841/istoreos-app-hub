#!/bin/sh
# Fixed runtime wrap contract. Generated preview; requires a manager-installed environment.
set -eu
store='/mnt/data/Configs/Runtime'
runtime='/mnt/data/Configs/Runtime/environments/python-3.13.3-x86_64-glibc'
if [ ! -d "$store" ] || [ ! -x "$runtime/bin/python3" ]; then echo '运行环境未安装或磁盘未挂载，尚未创建 HOME。' >&2; exit 1; fi
uid="$(id -u)"
runtime_home="${ISTORE_RUNTIME_HOME:-$store/users/$uid/home}"
case "$runtime_home" in /mnt/*) ;; *) echo 'HOME 必须位于持久磁盘 /mnt 下' >&2; exit 1 ;; esac
case "$runtime_home" in */../*|*/..|*/./*|*/.) echo 'HOME 路径无效' >&2; exit 1 ;; esac
export HOME="$runtime_home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_CACHE_HOME="$HOME/.cache" XDG_DATA_HOME="$HOME/.local/share"
export MISE_DATA_DIR="$store/mise/x86_64-glibc"
export MISE_CONFIG_DIR="$store/users/$uid/mise/x86_64-glibc/config" MISE_CACHE_DIR="$HOME/.cache/mise"
export ISTORE_RUNTIME_ID='python-3.13.3-x86_64-glibc'
export MISE_PYTHON_VERSION='3.13.3'
unset PYTHONHOME PYTHONPATH PYTHONUSERBASE PYTHONEXECUTABLE __PYVENV_LAUNCHER__ PIP_USER PIP_PREFIX PIP_TARGET
export PYTHONNOUSERSITE=1 PIP_REQUIRE_VIRTUALENV=true
export PIP_CACHE_DIR="$HOME/.cache/pip" UV_CACHE_DIR="$HOME/.cache/uv"
export TMPDIR="$HOME/.cache/python/python-3.13.3-x86_64-glibc/tmp"
export PATH="$runtime/bin:$HOME/.local/bin:$PATH"
umask 077
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$MISE_CONFIG_DIR" "$MISE_CACHE_DIR"
mkdir -p "$TMPDIR"
command="${1:---shell}"
[ "$#" -eq 0 ] || shift
run_venv() {
 exec "$runtime/bin/python3" -c '
import hashlib, json, os, pathlib, shlex, shutil, subprocess, sys

store, sdk, runtime_id, mode, *args = sys.argv[1:]
sdk = str(pathlib.Path(sdk).resolve())
entry = str(pathlib.Path(sdk) / '\''bin/python3'\'')
receipt_name = '\''.istore-python-runtime.json'\''

def fail(message):
    raise ValueError(message)

def target_path(value):
    p = pathlib.Path(value)
    if not value.startswith('\''/mnt/'\'') or any(x in ('\''.'\'', '\''..'\'') for x in value.split('\''/'\'')) or any(ord(c) < 32 for c in value):
        fail('\''虚拟环境必须在 /mnt 持久分区下，路径不能回退或包含控制字符'\'')
    p = p.resolve()
    if not str(p).startswith('\''/mnt/'\''):
        fail('\''虚拟环境不能通过符号链接指向持久分区之外'\'')
    managed = pathlib.Path(store).resolve()
    if p == managed or p in managed.parents:
        fail('\''不能把运行时根目录作为虚拟环境'\'')
    for name in ('\''environments'\'', '\''mise'\'', '\''rustup'\'', '\''wrap'\''):
        root = managed / name
        if p == root or root in p.parents:
            fail('\''不能在公共 SDK 或管理目录中创建虚拟环境'\'')
    return p

def environment(target):
    env = os.environ.copy()
    for name in ('\''PYTHONHOME'\'', '\''PYTHONPATH'\'', '\''PYTHONUSERBASE'\'', '\''PYTHONEXECUTABLE'\'', '\''__PYVENV_LAUNCHER__'\''):
        env.pop(name, None)
    env.update(VIRTUAL_ENV=str(target), PYTHONNOUSERSITE='\''1'\'', PIP_REQUIRE_VIRTUALENV='\''true'\'')
    env['\''PATH'\''] = str(target / '\''bin'\'') + os.pathsep + env.get('\''PATH'\'', '\'''\'')
    return env

def verify(target):
    probe = "import json,sys,site; print(json.dumps({'\''prefix'\'':sys.prefix,'\''base'\'':sys.base_prefix,'\''exe'\'':sys.executable,'\''user_site'\'':site.ENABLE_USER_SITE,'\''version'\'':'\''.'\''.join(map(str,sys.version_info[:3]))}))"
    value = json.loads(subprocess.check_output([str(target / '\''bin/python3'\''), '\''-c'\'', probe], env=environment(target), text=True))
    if pathlib.Path(value['\''prefix'\'']).resolve() != target or value['\''prefix'\''] == value['\''base'\''] or pathlib.Path(value['\''exe'\'']) != target / '\''bin/python3'\'' or value['\''user_site'\'']:
        fail('\''虚拟环境解释器验证失败；SDK 启动器未保留 venv/私有 loader 路径，未回退共享 Python'\'')
    if pathlib.Path(value['\''base'\'']).resolve() != pathlib.Path(sys.base_prefix).resolve():
        fail('\''虚拟环境的基础解释器与固定 SDK 不一致'\'')
    if value['\''version'\''] != '\''.'\''.join(map(str, sys.version_info[:3])):
        fail('\''虚拟环境与固定 Python 版本不一致'\'')

def launcher(target):
    # __PYVENV_LAUNCHER__ is consumed by CPython getpath. sys.executable then
    # points at this shim, so Python/pip entry points and child interpreters
    # re-enter the same managed SDK launcher rather than a host ELF loader.
    return ('\''#!/bin/sh\nset -eu\nunset PYTHONHOME PYTHONPATH PYTHONUSERBASE PYTHONEXECUTABLE\n'\''
            '\''export PYTHONNOUSERSITE=1\nexport __PYVENV_LAUNCHER__='\'' + shlex.quote(str(target / '\''bin/python3'\'')) + '\''\n'\''
            '\''exec '\'' + shlex.quote(entry) + '\'' "$@"\n'\'')

def create(target):
    if target.exists() or target.is_symlink():
        fail('\''目标目录已存在，请使用新的空目录；不会覆盖或清理既有文件'\'')
    target.parent.mkdir(parents=True, exist_ok=True)
    target.mkdir(mode=0o700)
    owned = target.stat()
    try:
        clean = environment(target)
        clean.pop('\''VIRTUAL_ENV'\'', None)
        subprocess.run([entry, '\''-m'\'', '\''venv'\'', '\''--copies'\'', '\''--without-pip'\'', str(target)], env=clean, check=True)
        source = launcher(target)
        for name in ('\''python'\'', '\''python3'\'', '\''python%d.%d'\'' % sys.version_info[:2]):
            dest = target / '\''bin'\'' / name
            if dest.exists() or dest.is_symlink():
                dest.unlink()
            dest.write_text(source)
            dest.chmod(0o700)
        verify(target)
        subprocess.run([str(target / '\''bin/python3'\''), '\''-m'\'', '\''ensurepip'\'', '\''--upgrade'\''], env=environment(target), check=True)
        subprocess.run([str(target / '\''bin/python3'\''), '\''-m'\'', '\''pip'\'', '\''--version'\''], env=environment(target), check=True)
        receipt = {'\''runtime'\'':runtime_id, '\''sdk'\'':sdk, '\''path'\'':str(target), '\''launcher_sha256'\'':hashlib.sha256(source.encode()).hexdigest()}
        (target / receipt_name).write_text(json.dumps(receipt, indent=2) + '\''\n'\'')
        print('\''虚拟环境已创建，pip 已初始化；应用依赖可安装到：'\'' + str(target))
    except BaseException:
        # Only our newly-created inode may be removed. Never clean an existing
        # or concurrently replaced directory, and never clear parent folders.
        if target.is_dir() and not target.is_symlink() and target.stat().st_ino == owned.st_ino and target.stat().st_dev == owned.st_dev:
            shutil.rmtree(target)
        raise

def run(target, command, rest):
    try:
        receipt = json.loads((target / receipt_name).read_text())
    except (OSError, ValueError):
        fail('\''此目录未通过固定运行时的虚拟环境验证，请先用 --create-venv 创建新环境'\'')
    if receipt.get('\''runtime'\'') != runtime_id or receipt.get('\''sdk'\'') != sdk or receipt.get('\''path'\'') != str(target):
        fail('\''虚拟环境属于另一个运行时或目录；拒绝回退共享 Python'\'')
    expected = hashlib.sha256(launcher(target).encode()).hexdigest()
    for name in ('\''python'\'', '\''python3'\'', '\''python%d.%d'\'' % sys.version_info[:2]):
        candidate = target / '\''bin'\'' / name
        if not candidate.is_file() or candidate.is_symlink() or hashlib.sha256(candidate.read_bytes()).hexdigest() != expected or receipt.get('\''launcher_sha256'\'') != expected:
            fail('\''虚拟环境入口已变化，不能保证固定运行时，请重新创建'\'')
    if not (target / '\''pyvenv.cfg'\'').is_file():
        fail('\''虚拟环境配置缺失'\'')
    verify(target)
    env = environment(target)
    if command in ('\''python'\'', '\''python3'\''):
        argv = [str(target / '\''bin/python3'\''), *rest]
    elif command == '\''pip'\'':
        argv = [str(target / '\''bin/python3'\''), '\''-m'\'', '\''pip'\'', *rest]
    elif command == '\''--shell'\'':
        argv = ['\''/bin/sh'\'', *rest]
    else:
        fail('\''虚拟环境支持 python / pip / --shell'\'')
    os.execve(argv[0], argv, env)

try:
    if runtime_id.split('\''-'\'')[1] != '\''.'\''.join(map(str, sys.version_info[:3])):
        fail('\''SDK 的实际 Python 版本与固定运行时不一致'\'')
    if not args:
        fail('\''请指定虚拟环境目录'\'')
    target = target_path(args[0])
    if mode == '\''create'\'' and len(args) == 1:
        create(target)
    elif mode == '\''run'\'':
        run(target, args[1] if len(args) > 1 else '\''--shell'\'', args[2:])
    else:
        fail('\''虚拟环境参数无效'\'')
except (ValueError, OSError, subprocess.SubprocessError) as error:
    print(str(error), file=sys.stderr)
    sys.exit(2)
' "$store" "$runtime" "$ISTORE_RUNTIME_ID" "$@"
}
case "$command" in
 --create-venv) run_venv create "$@"; exit $? ;;
 --venv) run_venv run "$@"; exit $? ;;
esac
if [ -n "${VIRTUAL_ENV:-}" ]; then run_venv run "$VIRTUAL_ENV" "$command" "$@"; exit $?; fi
case "$command" in
 --shell) exec /bin/sh "$@" ;;
 python|python3) exec "$runtime/bin/python3" "$@" ;;
 pip) case "${1:---version}" in --version|-V|--help|-h) exec "$runtime/bin/python3" -m pip "$@" ;; *) echo '应用依赖请先创建虚拟环境，再使用 --venv <目录> pip install …' >&2; exit 2 ;; esac ;;
 *) echo '支持：python / pip / --shell' >&2; exit 2 ;;
esac
