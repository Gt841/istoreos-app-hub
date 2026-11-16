#
# Copyright (C) 2026 iStoreOS
#
# This is free software, licensed under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=linkeasefull-web
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

LINKEASE_WEB_VARIANT:=nas-full
LINKEASE_WEB_SOURCE_PATH:=web/v1/core/$(PKG_NAME)/$(PKG_VERSION)/$(LINKEASE_WEB_VARIANT)
LINKEASE_WEB_SOURCE_URLS:= \
	https://fw.linkease.com/binary/LinkEase/$(LINKEASE_WEB_SOURCE_PATH) \
	https://dl.istoreos.com/binary/LinkEase/$(LINKEASE_WEB_SOURCE_PATH) \
	https://fw.d4ctech.com/binary/LinkEase/$(LINKEASE_WEB_SOURCE_PATH) \
	https://fw20.koolcenter.com/binary/LinkEase/$(LINKEASE_WEB_SOURCE_PATH) \
	https://fw.koolcenter.com/binary/LinkEase/$(LINKEASE_WEB_SOURCE_PATH)

LINKEASE_WEB_ARCHIVE_DOWNLOAD:=$(PKG_NAME)-$(PKG_VERSION)-$(LINKEASE_WEB_VARIANT)-desktop-shell.web.zip
LINKEASE_WEB_RELEASE_SET_DOWNLOAD:=$(PKG_NAME)-$(PKG_VERSION)-$(LINKEASE_WEB_VARIANT)-release-set.json
LINKEASE_WEB_PACKAGE_DOWNLOAD:=$(PKG_NAME)-$(PKG_VERSION)-$(LINKEASE_WEB_VARIANT)-package.json
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)-$(LINKEASE_WEB_VARIANT)

PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0
RSTRIP:=:

include $(INCLUDE_DIR)/package.mk

define Download/linkeasefull-web-archive
	URL:=$(LINKEASE_WEB_SOURCE_URLS)
	URL_FILE:=desktop-shell.web.zip
	FILE:=$(LINKEASE_WEB_ARCHIVE_DOWNLOAD)
	HASH:=ab13b11bba8cca0188143d0925028ee411db64011284e20f1a171617bd8c051e
endef

define Download/linkeasefull-web-release-set
	URL:=$(LINKEASE_WEB_SOURCE_URLS)
	URL_FILE:=release-set.json
	FILE:=$(LINKEASE_WEB_RELEASE_SET_DOWNLOAD)
	HASH:=724ef554ce5d68e4f1890c67301c2dae41ca54519ff2c11563e8084ffb3e381b
endef

define Download/linkeasefull-web-package
	URL:=$(LINKEASE_WEB_SOURCE_URLS)
	URL_FILE:=package.json
	FILE:=$(LINKEASE_WEB_PACKAGE_DOWNLOAD)
	HASH:=a67d1ab0d7dc06b15933f2e5106c592ebb1c91da2bc4fa9823bf85514ad424b3
endef

define Package/$(PKG_NAME)
	SECTION:=net
	CATEGORY:=Network
	SUBMENU:=Web Servers/Proxies
	TITLE:=LinkEase Full core Web desktop
	DEPENDS:=@(x86_64||aarch64)
	PKGARCH:=all
	URL:=https://www.linkease.com/
endef

define Package/$(PKG_NAME)/description
  Architecture-independent, offline core Web desktop for LinkEase Full.
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
set -eu
root="$${IPKG_INSTROOT:-}"
base="$${root}/usr/share/linkeasefull/web-core"
target="$(PKG_VERSION)/$(LINKEASE_WEB_VARIANT)"
current="$${base}/current"
temporary="$${base}/.current.$$$$"
test -s "$${base}/$${target}/release-set.json"
rm -f "$${temporary}"
ln -s "$${target}" "$${temporary}"
mv -fT "$${temporary}" "$${current}"
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
root="$${IPKG_INSTROOT:-}"
current="$${root}/usr/share/linkeasefull/web-core/current"
if [ "$$(readlink "$${current}" 2>/dev/null)" = "$(PKG_VERSION)/$(LINKEASE_WEB_VARIANT)" ]; then
	rm -f "$${current}"
fi
exit 0
endef

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	$(CP) $(DL_DIR)/$(LINKEASE_WEB_ARCHIVE_DOWNLOAD) $(PKG_BUILD_DIR)/desktop-shell.web.zip
	$(CP) $(DL_DIR)/$(LINKEASE_WEB_RELEASE_SET_DOWNLOAD) $(PKG_BUILD_DIR)/release-set.json
	$(CP) $(DL_DIR)/$(LINKEASE_WEB_PACKAGE_DOWNLOAD) $(PKG_BUILD_DIR)/package.json
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/share/linkeasefull/web-core/$(PKG_VERSION)/$(LINKEASE_WEB_VARIANT)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/desktop-shell.web.zip $(1)/usr/share/linkeasefull/web-core/$(PKG_VERSION)/$(LINKEASE_WEB_VARIANT)/desktop-shell.web.zip
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/release-set.json $(1)/usr/share/linkeasefull/web-core/$(PKG_VERSION)/$(LINKEASE_WEB_VARIANT)/release-set.json
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/package.json $(1)/usr/share/linkeasefull/web-core/$(PKG_VERSION)/$(LINKEASE_WEB_VARIANT)/package.json
endef

$(eval $(call Download,linkeasefull-web-archive))
$(eval $(call Download,linkeasefull-web-release-set))
$(eval $(call Download,linkeasefull-web-package))
$(eval $(call BuildPackage,$(PKG_NAME)))
