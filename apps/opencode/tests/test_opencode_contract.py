import json
import pathlib
import stat
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
HUB = ROOT.parents[1]


class OpenCodeContractTest(unittest.TestCase):
    def read(self, relative):
        return (ROOT / relative).read_text()

    def test_fixed_native_musl_release_uses_safe_baseline(self):
        recipe = self.read("opencode/Makefile")
        runtime = self.read("opencode/files/opencode-runtime.lua")
        package = self.read("opencode/files/opencode-package.lua")
        self.assertIn("PKG_VERSION:=2.4.1", recipe)
        self.assertIn("@opencode/cli-linux-x64-baseline-musl", runtime)
        self.assertIn("@opencode/cli-linux-arm64-musl", runtime)
        self.assertIn("candidate.version=='24.22.1'", runtime)
        self.assertIn("'--ignore-scripts'", package)
        self.assertIn("'--omit=optional'", package)
        self.assertIn("'/usr/bin/su'", package)
        self.assertIn("'auth','list','--format','json'", package)
        self.assertNotIn("R.package..'@'..R.version", package)
        self.assertNotIn("@latest", package)

    def test_terminal_and_gateway_are_private_and_authenticated(self):
        init = self.read("opencode/files/opencode.init")
        manifest = json.loads(self.read("opencode/files/opencode-plugin.json"))
        self.assertIn("-i 127.0.0.1", init)
        self.assertIn("procd_set_param user opencode", init)
        self.assertIn("-b /apps/opencode", init)
        self.assertEqual(manifest["auth"]["mode"], "default")
        self.assertEqual(manifest["backend"]["host"], "127.0.0.1")
        for relative in ("opencode/files/opencode", "opencode/files/opencode-runtime", "opencode/files/opencode.init"):
            self.assertTrue((ROOT / relative).stat().st_mode & stat.S_IXUSR, relative)

    def test_luci_is_one_page_and_agentflow_is_optional(self):
        controller = self.read("luci-app-opencode/luasrc/controller/opencode.lua")
        status = self.read("luci-app-opencode/luasrc/view/opencode/status.htm")
        self.assertIn("require_post_csrf", controller)
        self.assertIn('ipairs({ "terminal", "agentflow" })', controller)
        self.assertIn("opencode auth login", status)
        self.assertIn("?id=opencode", status)
        self.assertIn("安装 AgentFlow 后使用", status)
        self.assertNotIn("auth.json", controller)

    def test_registration_and_sync_are_owned_by_plugin(self):
        recipe = self.read("opencode/Makefile")
        sync = (HUB / "syncapps.yaml").read_text()
        self.assertIn("/usr/share/linkease/apps.d/37-opencode.json", recipe)
        self.assertIn("    opencode:\n", sync)
        self.assertIn("apps/opencode/luci-app-opencode", sync)


if __name__ == "__main__":
    unittest.main()
