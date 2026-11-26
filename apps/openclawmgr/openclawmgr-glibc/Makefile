include $(TOPDIR)/rules.mk

PKG_NAME:=openclawmgr-glibc
PKG_VERSION:=2.39
PKG_RELEASE:=1
PKG_BUILD_DEPENDS:=zstd/host
# Reuse hash-pinned GCC libraries from the published baidudrive runtime.
# GNU libc itself comes from the pinned Ubuntu packages below; no SDK/program.
PKG_SOURCE:=baidudrive-binary-1.0.6.tar.gz
PKG_SOURCE_URL:=https://github.com/istoreos/istoreos-app-hub/releases/download/baidudrive-runtime-v1.0.6/
PKG_HASH:=2cc12327dbe08f0b9906c6213e7f14c0cdc09cae5a5c64e353639e7bd3d34a01
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_LICENSE:=LGPL-2.1-or-later GPL-3.0-with-GCC-exception
STRIP:=true
RSTRIP:=:

include $(INCLUDE_DIR)/package.mk

define Package/openclawmgr-glibc
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=Private glibc runtime for OpenClawMgr
  DEPENDS:=@(x86_64||aarch64)
endef

ifeq ($(ARCH),x86_64)
  GLIBC_DEB_ARCH:=amd64
  GLIBC_DEB_URL:=https://archive.ubuntu.com/ubuntu/pool/main/g/glibc
  GLIBC_DEB_HASH:=af36c7ac770770fe3d3c10e85d6bc538e76e57570ba7db7d397fb9f654783ef3
else
  GLIBC_DEB_ARCH:=arm64
  GLIBC_DEB_URL:=https://ports.ubuntu.com/ubuntu-ports/pool/main/g/glibc
  GLIBC_DEB_HASH:=04d7cb73e608b41713b63ef915577f7f5d75e95b1b33174e82e05687fdb6cfaf
endif
GLIBC_DEB:=libc6_2.39-0ubuntu8_$(GLIBC_DEB_ARCH).deb

define Download/glibc
  FILE:=$(GLIBC_DEB)
  URL:=$(GLIBC_DEB_URL)
  HASH:=$(GLIBC_DEB_HASH)
endef
$(eval $(call Download,glibc))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/base $(PKG_BUILD_DIR)/libc
	$(TAR) -C $(PKG_BUILD_DIR)/base --strip-components=1 -xzf $(DL_DIR)/$(PKG_SOURCE)
	$(TARGET_CROSS)ar p $(DL_DIR)/$(GLIBC_DEB) data.tar.zst | zstd -dc | $(TAR) -xf - -C $(PKG_BUILD_DIR)/libc
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/openclawmgr-glibc/install
	$(INSTALL_DIR) $(1)/usr/share/openclawmgr-glibc
	./files/stage-runtime.sh $(PKG_BUILD_DIR)/base/glibc/$(ARCH) $(1)/usr/share/openclawmgr-glibc $(ARCH) $(PKG_BUILD_DIR)/libc
endef

$(eval $(call BuildPackage,openclawmgr-glibc))
