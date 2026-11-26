set -eu
cd /mnt/mise-runtime/packages
printf '%s\n' '3832f39c325e343f81fe3d92b2447c5d1a5eea1bc85092bb7b6c25806222647e  mise-v2026.8.14-linux-x64-musl.tar.gz' '1ec1474d59767d2d5feb48c39217b8409fa16831bd87c7c777d5359c2ceb05d6  ks-cli-binary-0.9.1.tar.gz' | sha256sum -c -
mkdir -p /mnt/mise-runtime/bootstrap
[ ! -e /mnt/mise-runtime/bootstrap/mise ]
tar -xzf mise-v2026.8.14-linux-x64-musl.tar.gz -C /mnt/mise-runtime/bootstrap
tar -xzf ks-cli-binary-0.9.1.tar.gz -C /mnt/mise-runtime/bootstrap
chmod -R go-w /mnt/mise-runtime/bootstrap
/mnt/mise-runtime/bootstrap/mise/bin/mise --version
/mnt/mise-runtime/bootstrap/ks-cli-binary-0.9.1/ks-cli.x86_64 --version
mkdir -p /mnt/mise-runtime/acceptance/network
/mnt/mise-runtime/bootstrap/ks-cli-binary-0.9.1/ks-cli.x86_64 download --admin-url http://192.168.30.93:5003 --mode auto --timeout 30s --progress none --json -O /mnt/mise-runtime/acceptance/network/node-shasums.txt https://nodejs.org/dist/v24.22.1/SHASUMS256.txt
sha256sum /mnt/mise-runtime/acceptance/network/node-shasums.txt
