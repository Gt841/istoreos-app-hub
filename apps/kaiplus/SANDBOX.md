# KAIPlus execution and approval packages

KAIPlus 1.0.22 separates the session's ordinary tool approval preference from
its execution policy. The default OpenWrt host configuration explicitly uses
`[sandbox] bash="off"` for native device management. It does not require bwrap.
Changing automatic approval never changes this execution policy.

Existing explicit `bash="enforce"` configurations remain confined even when the
backend is unavailable. Startup must not rewrite them to `off` after a failed
capability probe. Shell calls fail closed until the backend is usable.

`kaiplus-sandbox` is an optional dependency package selecting `kaiplus` and
`bubblewrap`. Installing it does not change user configuration or existing
sessions. Configure `sandbox.bash="enforce"` for new confined sessions. KAIPlus
checks actual namespace startup, rather than only the presence of `/usr/bin/bwrap`.
Kernel namespace support is still required.

The source recipe under `bubblewrap/` uses the verified upstream 0.13.1 archive,
OpenWrt's Meson build helpers and the SDK's full static libcap. Static libcap is
deliberate: firmware image optimizers may have removed unused functions such as
`cap_from_name` from the target's shared library. No system library replacement,
setuid bit or runtime download is required by this recipe.

Build/publish the optional package and backend together using the target SDK
before advertising availability in a feed. Local source/recipe tests do not
prove the OpenWrt 21.02 / 24.10 / APK SDK matrix passed and do not publish a feed.

Validation:

```sh
python3 -m unittest discover -s apps/kaiplus/tests -v
BWRAP_SOURCE_DIR=/path/to/verified/bubblewrap-0.13.1 python3 -m unittest discover -s apps/kaiplus/tests -v
```

The install fixture executes the actual package install recipe and checks binary
ownership, ordinary 0755 permissions and licenses. Public/local release artifact
verification is opt-in via the existing `KAI_VERIFY_PUBLIC_RELEASE` /
`KAI_RUNTIME_RELEASE_DIR` tests; run it against the new runtime candidate too.
