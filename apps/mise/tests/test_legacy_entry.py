#!/usr/bin/env python3
"""Exercise the real legacy helper with OpenWrt config/mount boundaries stubbed.

No network is permitted during environment setup, even when the accelerator is
installed but unresponsive. Device tests separately exercise real mounts/entries.
"""
import os
import signal
from pathlib import Path
import subprocess
import tempfile
import unittest

SOURCE = Path(os.environ.get("MISE_LEGACY_HELPER", Path(__file__).resolve().parents[1] / "mise/files/mise.sh"))

class LegacyEntry(unittest.TestCase):
    def run_helper(self, body, *, acceleration="1", ks_cli=True, extra_env=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bindir = root / "bin"
            bindir.mkdir()
            for name in ["iStoreEnhance", "wget", "curl"] + (["ks-cli"] if ks_cli else []):
                target = bindir / name
                target.write_text("#!/bin/sh\nprintf '%s\n' network-called >> \"$TRACE\"\nsleep 10\n")
                target.chmod(0o755)
            helper = SOURCE.read_text().replace(". /lib/functions.sh", "# OpenWrt functions supplied by fixture", 1)
            setup = r"""
config_load() { return 0; }
config_get() {
 case "$3" in
  runtime_dir) eval "$1=/mnt/legacy-fixture" ;;
  acceleration) eval "$1=$ACCELERATION" ;;
 esac
}
# Persistence checks belong to storage tests; preserve their call boundary here.
readlink() { printf '%s\n' "$2"; }
awk() { return 0; }
mkdir() { return 0; }
exec() { printf 'EXEC'; printf '<%s>' "$@"; printf '\n'; cat; exit 37; }
"""
            env = dict(os.environ, PATH=str(bindir)+":/usr/bin:/bin", TRACE=str(root/"trace"), ACCELERATION=acceleration)
            for name in ("MISE_NODE_MIRROR_URL", "MISE_GO_DOWNLOAD_MIRROR", "MISE_URL_REPLACEMENTS"):
                env.pop(name, None)
            env.update(extra_env or {})
            process = subprocess.Popen(["/bin/bash", "-c", helper+setup+body], env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
            try:
                stdout, stderr = process.communicate("stdin preserved\n", timeout=1)
                result = subprocess.CompletedProcess(process.args, process.returncode, stdout, stderr)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate()
                raise AssertionError("legacy environment blocked on an optional network probe") from None
            self.assertFalse((root/"trace").exists(), "environment setup contacted a network tool")
            return result

    def test_offline_environment_setup_never_probes(self):
        r = self.run_helper('istore_runtime_env; printf "HOME=%s\n" "$HOME"')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("HOME=/mnt/legacy-fixture", r.stdout)

    def test_enabled_entry_delegates_to_ks_cli_preserving_arguments_stdin_exit(self):
        r = self.run_helper('istore_runtime_env && istore_runtime_mise_exec install "node@two words"')
        self.assertEqual(r.returncode, 37, r.stderr)
        self.assertIn("EXEC<ks-cli><mise><install><node@two words>", r.stdout)
        self.assertIn("stdin preserved", r.stdout)

    def test_local_exec_never_requires_accelerator(self):
        r = self.run_helper('istore_runtime_env && istore_runtime_mise_exec exec -- node --version')
        self.assertEqual(r.returncode, 37, r.stderr)
        self.assertIn("EXEC</usr/bin/mise><exec><--><node><--version>", r.stdout)

    def test_explicit_mirror_is_preserved_without_ks_cli_override(self):
        for variable in ("MISE_NODE_MIRROR_URL", "MISE_GO_DOWNLOAD_MIRROR", "MISE_URL_REPLACEMENTS"):
            r = self.run_helper('istore_runtime_env && istore_runtime_mise_exec install node@24', extra_env={variable:"custom"})
            self.assertEqual(r.returncode, 37, r.stderr)
            self.assertIn("EXEC</usr/bin/mise><install><node@24>", r.stdout)

    def test_disabled_acceleration_executes_native_mise(self):
        r = self.run_helper('istore_runtime_env && istore_runtime_mise_exec install node@24', acceleration="0")
        self.assertEqual(r.returncode, 37, r.stderr)
        self.assertIn("EXEC</usr/bin/mise><install><node@24>", r.stdout)

    def test_absent_optional_ks_cli_keeps_native_mise_usable(self):
        r = self.run_helper('istore_runtime_env && istore_runtime_mise_exec install node@24', ks_cli=False)
        self.assertEqual(r.returncode, 37, r.stderr)
        self.assertIn("EXEC</usr/bin/mise><install><node@24>", r.stdout)

if __name__ == "__main__":
    unittest.main()
