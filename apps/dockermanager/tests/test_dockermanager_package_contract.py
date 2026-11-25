from pathlib import Path
import unittest
import json
import subprocess


ROOT = Path(__file__).resolve().parents[1]


class DockerManagerPackageContractTest(unittest.TestCase):
    def read(self, relative):
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_package_depends_on_shared_linkease_openwrt_auth_bridge(self):
        makefile = self.read("dockermanager/Makefile")
        meta = self.read("app-meta-dockermanager/Makefile")
        luci_makefile = self.read("luci-app-dockermanager/Makefile")
        controller = self.read("luci-app-dockermanager/luasrc/controller/dockermanager.lua")
        cbi = self.read("luci-app-dockermanager/luasrc/model/cbi/dockermanager.lua")
        status = self.read("luci-app-dockermanager/luasrc/view/dockermanager_status.htm")
        init = self.read("dockermanager/files/dockermanager.init")
        config = self.read("dockermanager/files/dockermanager.config")
        plugin = self.read("dockermanager/files/dockermanager-plugin.json")
        app_meta_config = self.read("app-meta-dockermanager/config.sh")
        app_meta_entry = self.read("app-meta-dockermanager/entry.sh")

        self.assertIn("PKG_VERSION:=0.1.2", makefile)
        self.assertIn(
            "PKG_SOURCE_URL:=https://github.com/istoreos/istoreos-app-hub/releases/download/dockermanager-runtime-v$(PKG_VERSION)/",
            makefile,
        )
        self.assertIn("PKG_HASH:=1ecaa4363b1a20a26c31a36f994e94a8064ed0de67cd612a233fc05f5026726a", makefile)
        self.assertIn("$(INSTALL_DATA) ./files/logo.svg $(1)/usr/share/dockermanager/www/logo.svg", makefile)
        self.assertNotIn("../app-meta-", makefile)
        self.assertIn("PKG_VERSION:=0.1.2", meta)
        self.assertIn("PKG_RELEASE:=6", meta)
        self.assertIn("DEPENDS:=+docker +dockerd +ca-bundle +linkease-app-entry", makefile)
        self.assertNotIn("+luci-lib-linkeaseauth", makefile)
        self.assertIn("LUCI_DEPENDS:=+dockermanager +luci-lib-linkeaseauth +linkease-app-entry", luci_makefile)
        self.assertIn("META_DEPENDS:=+dockermanager +luci-app-dockermanager", meta)
        self.assertNotIn("+luci-lib-linkeaseauth", meta)
        self.assertIn("META_LUCI_ENTRY:=/cgi-bin/luci/admin/services/dockermanager", meta)
        self.assertNotIn("+luci-app-linkeasefull", makefile)
        self.assertNotIn("+luci-app-linkeasefull", meta)
        self.assertIn('entry({"admin", "services", "dockermanager", "open"}', controller)
        self.assertIn("function dockermanager_open()", controller)
        self.assertIn('compat():open("dockermanager")', controller)
        self.assertIn('compat():legacy_status("dockermanager"', controller)
        self.assertNotIn("uhttpd_apps_proxy_available", controller)
        self.assertNotIn("app_entry_running", controller)
        self.assertNotIn("enable_port", controller)
        self.assertNotIn("uci:set", controller)
        self.assertNotIn("uci:commit", controller)
        self.assertNotIn("restart", controller)
        self.assertIn('Map("dockermanager"', cbi)
        self.assertIn('"data_dir"', cbi)
        self.assertNotIn('"listen_mode"', cbi)
        self.assertNotIn('"external_port_enabled"', cbi)
        self.assertIn('"socket_path"', cbi)
        self.assertIn("socket_path.readonly = true", cbi)
        self.assertNotIn('"port"', cbi)
        self.assertIn("base_path.readonly = true", cbi)
        self.assertIn('url("admin/services/linkease_apps/open")', status)
        self.assertNotIn("External port access is disabled", status)
        self.assertNotIn("option 'external_port_enabled' '0'", config)
        self.assertIn("option 'socket_path' '/var/run/dockermanager.sock'", config)
        self.assertNotIn('set dockermanager.@dockermanager[0].external_port_enabled="0"', app_meta_config)
        self.assertIn('DOCKER_MANAGER_LISTEN_MODE=unix', init)
        self.assertIn('DOCKER_MANAGER_SOCKET_PATH=$socket_path', init)
        self.assertIn('DOCKER_MANAGER_INTEGRATION_TOKEN_FILE=$integration_token_file', init)
        self.assertIn('"transport": "unix"', plugin)
        self.assertIn('"providerOrder": ["uci"]', plugin)
        self.assertIn('"providers"', plugin)
        self.assertIn('"type": "uci"', plugin)
        self.assertIn('"values"', plugin)
        self.assertIn('"socketPath"', plugin)
        self.assertNotIn('"listenMode"', plugin)
        self.assertNotIn('"externalPortEnabled"', plugin)
        self.assertNotIn('"port"', plugin)
        self.assertIn('"uci": "dockermanager.@dockermanager[0].socket_path"', plugin)
        self.assertNotIn('"uci": "dockermanager.@dockermanager[0].listen_mode"', plugin)
        self.assertNotIn('"uci": "dockermanager.@dockermanager[0].external_port_enabled"', plugin)
        self.assertNotIn('"uci": "dockermanager.@dockermanager[0].port"', plugin)
        self.assertNotIn('"socketFromUci"', plugin)
        self.assertNotIn('"transportModeFromUci"', plugin)
        self.assertNotIn('"tcpEnabledFromUci"', plugin)
        self.assertNotIn('"portFromUci"', plugin)
        self.assertNotIn('"fallback"', plugin)
        self.assertIn('/cgi-bin/luci/admin/services/dockermanager', app_meta_entry)
        # Unix listeners use the existing resolver for auth/proxy readiness;
        # href still opens the original LuCI settings page.
        self.assertIn('linkease_apps/open?id=dockermanager', app_meta_entry)
        self.assertIn('json_add_string "href" "/cgi-bin/luci/admin/services/dockermanager"', app_meta_entry)

    def test_old_tcp_configuration_cannot_change_the_running_transport(self):
        script = r'''
. "$1"
config_load() { :; }
config_foreach() { "$1" dockermanager; }
config_get_bool() { eval "$1=1"; }
config_get() {
    case "$1" in
        data_dir) data_dir=/mnt/test-docker ;;
        listen_mode) listen_mode=tcp ;;
        port) port=8192 ;;
        bind_addr) bind_addr=0.0.0.0 ;;
        *) eval "$1=\"$4\"" ;;
    esac
}
mkdir() { :; }
prepare_token() { :; }
procd_open_instance() { :; }
procd_close_instance() { :; }
procd_set_param() { printf '%s\n' "$@"; }
start_service
'''
        result = subprocess.run(["sh", "-c", script, "test", str(ROOT / "dockermanager/files/dockermanager.init")],
                                text=True, capture_output=True, check=True)
        self.assertIn("DOCKER_MANAGER_LISTEN_MODE=unix", result.stdout)
        self.assertIn("DOCKER_MANAGER_SOCKET_PATH=/var/run/dockermanager.sock", result.stdout)
        self.assertNotIn("DOCKER_MANAGER_ADDR", result.stdout)
        backend = json.loads(self.read("dockermanager/files/dockermanager-plugin.json"))["backend"]
        self.assertEqual(backend["transport"], "unix")
        self.assertEqual(set(backend["values"]), {"socketPath"})
        self.assertNotIn("fallback", backend)

    def test_luci_install_requires_the_shared_apps_modules_generation(self):
        makefile = self.read("luci-app-dockermanager/Makefile")
        # An unversioned dependency accepts 1.0.3, whose missing apps_compat
        # module makes the authenticated status and open routes return 500.
        self.assertIn(
            "LUCI_EXTRA_DEPENDS:=luci-lib-linkeaseauth (>=1.2.1-r4)", makefile
        )
        # Keep the revision in PKG_VERSION so LuCI builders that clear
        # PKG_RELEASE still produce an upgrade over the broken 0.1.2 package.
        self.assertIn("PKG_VERSION:=0.1.2-r3", makefile)
        self.assertRegex(makefile, r"(?m)^PKG_RELEASE:=$")
        shared = ROOT.parent / "linkeasefull/luci-lib-linkeaseauth"
        self.assertIn("PKG_VERSION:=1.2.1", (shared / "Makefile").read_text())
        for module in ("apps", "apps_compat", "apps_openwrt"):
            self.assertTrue(
                (shared / f"luasrc/model/linkease/{module}.lua").is_file(), module
            )

    def test_package_registers_desktop_plugin_without_owning_auth_bridge(self):
        makefile = self.read("dockermanager/Makefile")

        self.assertNotIn("$(1)/usr/share/linkeasefull/desktop-apps.d", makefile)
        self.assertIn("$(1)/usr/share/linkease/apps.d", makefile)
        self.assertNotIn(
            "ln -sf /usr/share/dockermanager/dockermanager-plugin.json $(1)/usr/share/linkeasefull/desktop-apps.d/20-dockermanager-plugin.json",
            makefile,
        )
        self.assertIn(
            "ln -sf /usr/share/dockermanager/dockermanager-plugin.json $(1)/usr/share/linkease/apps.d/20-dockermanager-plugin.json",
            makefile,
        )
        self.assertNotIn("/cgi-bin/luci/admin/services/linkeasefull/auth", makefile)
        self.assertNotIn("/cgi-bin/luci/admin/services/linkease_auth/auth", makefile)


if __name__ == "__main__":
    unittest.main()
