#!/bin/sh
set -eu
source_dir="$1"; destination="$2"; arch="$3"
case "$arch" in
	x86_64) tuple=x86_64-linux-gnu; loader=lib64/ld-linux-x86-64.so.2 ;;
	aarch64) tuple=aarch64-linux-gnu; loader=lib/ld-linux-aarch64.so.1 ;;
	*) echo "Unsupported glibc architecture: $arch" >&2; exit 1 ;;
esac
glibc_root="$4"
copy_lib() {
	local name="$1" candidate
	for candidate in "$glibc_root/lib/$tuple/$name" "$glibc_root/usr/lib/$tuple/$name"; do
		if [ -f "$candidate" ]; then cp -L "$candidate" "$destination/$name"; return 0; fi
	done
	echo "Missing glibc library: $name" >&2; return 1
}
mkdir -p "$destination"
copy_lib "$(basename "$loader")"
mv "$destination/$(basename "$loader")" "$destination/ld.so"
for lib in libc.so.6 libdl.so.2 libpthread.so.0 libm.so.6 librt.so.1 libutil.so.1 libresolv.so.2; do copy_lib "$lib"; done
cp -L "$source_dir/lib/$tuple/libgcc_s.so.1" "$destination/libgcc_s.so.1"
cp -L "$source_dir/usr/lib/$tuple/libstdc++.so.6" "$destination/libstdc++.so.6"
chmod 755 "$destination/ld.so"
printf '%s\n' 'Ubuntu libc6 2.39-0ubuntu8 + GCC runtime from baidudrive-runtime-v1.0.6; private OpenClawMgr copy' > "$destination/SOURCE"
(
	cd "$destination"
	sha256sum ld.so *.so.* SOURCE > SHA256SUMS
)
