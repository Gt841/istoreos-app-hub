include $(TOPDIR)/rules.mk

PKG_NAME:=bubblewrap
PKG_VERSION:=0.13.1
PKG_RELEASE:=1
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.xz
PKG_SOURCE_URL:=https://github.com/containers/bubblewrap/releases/download/v$(PKG_VERSION)/
PKG_HASH:=0e85c8702248b8dd64144f594147553650cdd0e4c951690345faace79c217c4d
PKG_LICENSE:=LGPL-2.0-or-later AND BSD-3-Clause
PKG_LICENSE_FILES:=COPYING COPYING.LIB LICENSE
PKG_INSTALL:=1
PKG_BUILD_PARALLEL:=1
PKG_BUILD_DEPENDS:=libcap

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/meson.mk

define Package/bubblewrap
 SECTION:=utils
 CATEGORY:=Utilities
 TITLE:=Unprivileged Linux namespace sandbox
 URL:=https://github.com/containers/bubblewrap
 DEPENDS:=@(x86_64||aarch64)
endef

define Package/bubblewrap/description
 Linux namespace sandbox backend for explicitly confined KAIPlus execution.
 Installing this package does not change KAIPlus approval or execution policy.
 The kernel must support the namespace operations; KAIPlus probes actual startup.
endef

MESON_ARGS += \
	-Dman=disabled \
	-Dtests=false \
	-Dselinux=disabled \
	-Dbash_completion=disabled \
	-Dzsh_completion=disabled

define Package/bubblewrap/install
	$(INSTALL_DIR) $(1)/usr/bin $(1)/usr/share/licenses/bubblewrap
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/bwrap $(1)/usr/bin/bwrap
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/COPYING $(PKG_BUILD_DIR)/COPYING.LIB $(PKG_BUILD_DIR)/LICENSE $(1)/usr/share/licenses/bubblewrap/
	$(INSTALL_DATA) ./files/libcap-license.txt $(1)/usr/share/licenses/bubblewrap/libcap-license.txt
endef

$(eval $(call BuildPackage,bubblewrap))
