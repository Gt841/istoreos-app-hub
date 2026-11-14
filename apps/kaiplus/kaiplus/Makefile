#
# Copyright (C) 2026 KaiPlus Contributors
#
# This is free software, licensed under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

KAIPLUS_ARCH_x86_64:=amd64
KAIPLUS_ARCH_aarch64:=arm64
KAIPLUS_ARCH:=$(KAIPLUS_ARCH_$(ARCH))
KAIPLUS_HASH_x86_64:=e191afc3473e2374daa9ae8a4f07d9315ac8e40c25ac1904aa19a0300aa667f9
KAIPLUS_HASH_aarch64:=12755eb624fd56d3c7aa2923b550bb129f8e900a602d2fbbdd07dff86ff3973d

PKG_NAME:=kaiplus
PKG_VERSION:=1.0.14-cg1
PKG_RELEASE:=13

KAIPLUS_URL_FILE:=kaiplus-linux-$(KAIPLUS_ARCH)
KAIPLUS_DOWNLOAD:=$(KAIPLUS_URL_FILE)-$(KAIPLUS_HASH_$(ARCH))
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0
STRIP:=true
RSTRIP:=:

include $(INCLUDE_DIR)/package.mk

define Download/kaiplus
	URL:=https://fw.koolcenter.com/binary/kai/releases/build/
	URL_FILE:=$(KAIPLUS_URL_FILE)
	FILE:=$(KAIPLUS_DOWNLOAD)
	HASH:=$(KAIPLUS_HASH_$(ARCH))
endef

define Package/$(PKG_NAME)
	SECTION:=net
	CATEGORY:=System
	SUBMENU:=
	TITLE:=KaiPlus
	URL:=https://github.com/linkease/istore-packages
	DEPENDS:=@(x86_64||aarch64) +linkease-app-entry +changeguard
endef

define Package/$(PKG_NAME)/description
  KaiPlus is a single-process AI workspace and session service.
endef

define Package/$(PKG_NAME)/conffiles
/etc/init.d/kaiplus
/etc/config/kaiplus
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
# Compatibility entry for desktops which only scan the old directory.
root="$${IPKG_INSTROOT:-}"
legacy="$${root}/usr/share/linkeasefull/desktop-apps.d/00-kaiplus-plugin.json"
if [ ! -e "$${legacy}" ] && [ ! -L "$${legacy}" ]; then
	mkdir -p "$${legacy%/*}"
	ln -s /usr/share/kaiplus/kaiplus-plugin.json "$${legacy}" || exit $$?
fi
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
root="$${IPKG_INSTROOT:-}"
for directory in /usr/share/linkease/apps.d /usr/share/linkeasefull/desktop-apps.d; do
	registration="$${root}$${directory}/00-kaiplus-plugin.json"
	if [ "$$(readlink "$${registration}" 2>/dev/null)" = "/usr/share/kaiplus/kaiplus-plugin.json" ]; then
		rm -f "$${registration}"
	fi
done
rmdir "$${root}/usr/share/linkeasefull/desktop-apps.d" 2>/dev/null || true
exit 0
endef

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	$(CP) $(DL_DIR)/$(KAIPLUS_DOWNLOAD) $(PKG_BUILD_DIR)/kaiplus
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/usr/share/kaiplus $(1)/usr/share/linkease/apps.d $(1)/etc/init.d $(1)/etc/config
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/kaiplus $(1)/usr/sbin/kaiplus_bin
	ln -sf kaiplus_bin $(1)/usr/sbin/kaiplus
	$(INSTALL_DATA) ./files/logo.png $(1)/usr/share/kaiplus/logo.png
	$(INSTALL_DATA) ./files/kaiplus-plugin.json $(1)/usr/share/kaiplus/kaiplus-plugin.json
	ln -sf /usr/share/kaiplus/kaiplus-plugin.json $(1)/usr/share/linkease/apps.d/00-kaiplus-plugin.json
	$(INSTALL_BIN) ./files/kaiplus.init $(1)/etc/init.d/kaiplus
	$(INSTALL_CONF) ./files/kaiplus.config $(1)/etc/config/kaiplus
endef

$(eval $(call Download,kaiplus))
$(eval $(call BuildPackage,$(PKG_NAME)))
