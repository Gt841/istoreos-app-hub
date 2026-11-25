"""Exercise the real manifests/resolver and init bodies without a router."""
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


HUB = Path(__file__).resolve().parents[3]
MANAGED = ("dockermanager", "kaiplus", "agentflow", "baidudrive", "codex", "opencode", "kimi", "claude-code")


def manifest(app):
    prefix = "claude" if app == "claude-code" else app
    return json.loads((HUB / f"apps/{app}/{app}/files/{prefix}-plugin.json").read_text())


def lua(value):
    if isinstance(value, dict):
        return "{" + ",".join("[" + json.dumps(key) + "]=" + lua(item) for key, item in value.items()) + "}"
    if isinstance(value, list):
        return "{" + ",".join(lua(item) for item in value) + "}"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if value is None:
        return "nil"
    return json.dumps(value)


class ManagedAppsContract(unittest.TestCase):
    def test_actual_manifests_choose_shared_routes_and_never_private_ports(self):
        executable = shutil.which("lua5.1") or shutil.which("lua")
        self.assertIsNotNone(executable, "Lua is required for the shared resolver contract")
        manifests = {app: manifest(app) for app in MANAGED}
        for app in ("fastnet", "istoreenhance"):
            filename = "fastnet-plugin.json" if app == "fastnet" else "kspeeder-plugin.json"
            data = json.loads((HUB / f"apps/{app}/{app}/files/{filename}").read_text())
            manifests[data["id"]] = data
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "luci").mkdir()
            (root / "luci/model").symlink_to(HUB / "apps/linkeasefull/luci-lib-linkeaseauth/luasrc/model")
            source = "package.path=" + json.dumps(str(root / "?.lua") + ";") + "..package.path\nlocal manifests=" + lua(manifests) + r'''
local adapter = require "luci.model.linkease.apps_openwrt"
local cases = {
 {worker="gateway", proxy=true, listen="0.0.0.0:19290", transport="proxy"},
 {worker="linkeasefull", proxy=true, listen="0.0.0.0:19290", transport="proxy"},
 {worker="gateway", proxy=false, listen="0.0.0.0:19290", transport="lan"},
 {worker="linkeasefull", proxy=false, listen="0.0.0.0:19290", transport="lan"},
 {worker="stopped", proxy=false, listen="0.0.0.0:19290"},
 {worker="starting", proxy=true, listen="0.0.0.0:19290"},
 {worker="gateway", proxy=false, listen="127.0.0.1:19290"}
}
for id, manifest in pairs(manifests) do
 for _, case in ipairs(cases) do
  local emitted = false
  local deps = {
   registration_dirs={"/registry"},
   fs={dir=function() return function() if not emitted then emitted=true; return "app.json" end end end,
       readfile=function(path) if path=="/registry/app.json" then return "manifest" end
           if path=="/state.json" then return "state" end return "" end},
   json={parse=function(raw) if raw=="manifest" then return manifest end
          if raw=="state" then return {active=case.worker,listen=case.listen} end end},
   http={getenv=function(key) if key=="HTTP_HOST" then return "192.168.30.7:10000" end end},
   sys={call=function() return case.proxy and 0 or 1 end},
   uci={get_list=function() return case.proxy and {"/apps=http://127.0.0.1:19290"} or {} end,
        get=function(_,config,section,option)
          if option=="state_file" then return "/state.json" end
          if option=="listen" then return "0.0.0.0:19290" end -- unapplied configuration cannot win
        end,
        get_first=function(_,config,section,option)
          if option=="external_port_enabled" then return "1" end -- obsolete switch cannot re-enable public access
        end}
  }
  local result = adapter.new(deps):resolve(id)
  if id~="fastnet" and id~="kspeeder" then
   assert(result.available==(case.transport~=nil), id..": unexpected availability")
   if case.transport then
    local expected=(case.transport=="lan" and "http://192.168.30.7:19290" or "").."/apps/"..id.."/"
    assert(result.url==expected, id..": wrong public target "..tostring(result.url))
    assert(result.transport==case.transport and result.mode=="apps", id..": wrong route")
   else
    assert(result.url==nil and result.mode=="unavailable", id..": private backend leaked to browser")
   end
  elseif case.worker=="stopped" then
   local port = id=="fastnet" and 3200 or 5003
   assert(result.available and result.mode=="external", id..": browser-direct exception changed")
   assert(result.url=="http://192.168.30.7:"..port.."/", id..": exception target changed")
  end
 end
end
print("managed Apps matrix passed")
'''
            result = subprocess.run([executable, "-"], input=source, text=True, capture_output=True, check=True)
            self.assertEqual(result.stdout.strip(), "managed Apps matrix passed")

    def test_native_init_ignores_old_public_bind_and_tcp_settings(self):
        harness = r'''
. "$TEST_INIT"
config_load() { :; }
config_foreach() { "$1" main; }
config_get_bool() { eval "$1=1"; }
config_get() {
 case "$1" in
  data_dir) data_dir=/mnt/managed-test ;;
  backup_dir) backup_dir=/mnt/TimeMachine ;;
  host|bind_addr) eval "$1=0.0.0.0" ;;
  listen_mode) listen_mode=tcp ;;
  external_port_enabled) external_port_enabled=1 ;;
  port) port=9380 ;;
  socket_path) socket_path=/var/run/kaiplus-test.sock ;;
  *) eval "$1=\"$4\"" ;;
 esac
}
mkdir() { :; }
chmod() { :; }
rm() { :; }
logger() { :; }
pidof() { return 0; }
ensure_macid() { macid=test-device; }
storage_root_from_data_dir() { printf '%s' /mnt; }
require_executable() { :; }
require_file() { :; }
procd_open_instance() { :; }
procd_close_instance() { :; }
procd_set_param() { printf '%s\n' "$@"; }
procd_append_param() { printf '%s\n' "$@"; }
start_service
'''
        for app in ("kaiplus", "agentflow", "baidudrive"):
            with self.subTest(app=app), tempfile.TemporaryDirectory() as directory:
                stage = Path(directory)
                source = (HUB / f"apps/{app}/{app}/files/{app}.init").read_text()
                if app == "agentflow":
                    backend = stage / "agentflow"
                    backend.write_text("#!/bin/sh\nexit 0\n")
                    backend.chmod(0o755)
                    runtime = stage / "agentflow-runtime"
                    runtime.write_text('#!/bin/sh\n[ "$1" != home ] || printf "%s" /mnt/test-home\nexit 0\n')
                    runtime.chmod(0o755)
                    source = source.replace("/usr/sbin/agentflow", str(backend)).replace("/usr/libexec/agentflow-runtime", str(runtime))
                init = stage / "init"
                init.write_text(source)
                result = subprocess.run(["sh", "-c", harness], env=dict(os.environ, TEST_INIT=str(init)), text=True, capture_output=True, check=True)
                output = result.stdout
                self.assertNotIn("0.0.0.0", output)
                if app == "kaiplus":
                    self.assertIn("KAIPLUS_LISTEN_MODE=unix", output)
                    self.assertIn("--socket-path\n/var/run/kaiplus-test.sock", output)
                    self.assertNotIn("--addr", output)
                elif app == "agentflow":
                    self.assertIn("AGENT_FLOW_HOST=127.0.0.1", output)
                    self.assertIn("AGENT_FLOW_PORT=9380", output)
                else:
                    self.assertIn("--host\n127.0.0.1\n--port\n9380", output)
                    self.assertIn("-ip\n127.0.0.1\n-port\n8001", output)

    def test_upgrade_restarts_only_active_apps_and_reports_restart_failure(self):
        for app in ("kaiplus", "agentflow", "baidudrive"):
            recipe = (HUB / f"apps/{app}/{app}/Makefile").read_text()
            body = recipe.split("define Package/$(PKG_NAME)/postinst\n", 1)[1].split("\nendef", 1)[0].replace("$$", "$")
            for running, status in ((False, 0), (True, 0), (True, 7)):
                with self.subTest(app=app, running=running, status=status), tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    service = root / f"etc/init.d/{app}"
                    service.parent.mkdir(parents=True)
                    service.write_text('#!/bin/sh\nprintf "%s" "$*" > "$TEST_RESTART_LOG"\nexit "$TEST_RESTART_STATUS"\n')
                    service.chmod(0o755)
                    script = re.sub(r"/(?:usr/share|etc/init\.d)/", lambda match: str(root) + match.group(0), body)
                    stubs = r'''
uci() { printf '%s\n' "$*" >> "$TEST_UCI_LOG"; }
pidof() { [ "$TEST_RUNNING" = 1 ]; }
'''
                    env = dict(os.environ, IPKG_INSTROOT="", TEST_RUNNING=str(int(running)), TEST_RESTART_STATUS=str(status),
                               TEST_RESTART_LOG=str(root / "restart"), TEST_UCI_LOG=str(root / "uci"))
                    result = subprocess.run(["sh", "-c", stubs + script], env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, status if running else 0, result.stderr)
                    self.assertEqual((root / "restart").exists(), running)
                    if running:
                        self.assertEqual((root / "restart").read_text(), "restart")
                    operations = (root / "uci").read_text()
                    if app == "kaiplus":
                        self.assertIn("delete kaiplus.@kaiplus[0].port", operations)
                    else:
                        self.assertIn(f"set {app}.@{app}[0].host=127.0.0.1", operations)

    def test_private_tcp_policy_and_packaging_require_the_shared_resolver(self):
        for app in MANAGED:
            with self.subTest(app=app):
                data = manifest(app)
                if app in ("dockermanager", "kaiplus"):
                    self.assertEqual(data["backend"]["transport"], "unix")
                    self.assertNotIn("fallback", data["backend"])
                else:
                    self.assertEqual(data["backend"]["values"]["externalPortEnabled"], {"default": False})
                    self.assertEqual(data["backend"]["host"], "127.0.0.1")
                if app != "dockermanager":
                    runtime = (HUB / f"apps/{app}/{app}/Makefile").read_text()
                    luci_recipe = (HUB / f"apps/{app}/luci-app-{app}/Makefile").read_text()
                    self.assertIn("luci-lib-linkeaseauth (>=1.2.1-r5)", runtime)
                    self.assertIn("luci-lib-linkeaseauth (>=1.2.1-r5)", luci_recipe)


if __name__ == "__main__":
    unittest.main()
