#
# Copyright (C) 2023 remittor
#

include $(TOPDIR)/rules.mk

PKG_NAME:=facinstall
PKG_VERSION:=2.5
PKG_RELEASE:=20250411

PKG_MAINTAINER:=remittor <remittor@gmail.com>
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Installer for factory and OEM images
  PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
Installer for factory and OEM images
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/$(PKG_NAME).init      $(1)/etc/init.d/$(PKG_NAME)
	$(INSTALL_DIR) $(1)/lib/upgrade/$(PKG_NAME)
	$(INSTALL_BIN) ./files/$(PKG_NAME).sh        $(1)/lib/upgrade/$(PKG_NAME)/$(PKG_NAME).sh
	$(INSTALL_BIN) ./files/functions.sh          $(1)/lib/upgrade/$(PKG_NAME)/functions.sh
	$(INSTALL_BIN) ./files/fi_boards.sh          $(1)/lib/upgrade/$(PKG_NAME)/fi_boards.sh
	$(INSTALL_BIN) ./files/validate_fw_image.sh  $(1)/lib/upgrade/$(PKG_NAME)/validate_fw_image.sh
	$(INSTALL_BIN) ./files/fi_do_stage2.sh       $(1)/lib/upgrade/$(PKG_NAME)/fi_do_stage2.sh
	$(INSTALL_BIN) ./files/xiaomi.sh             $(1)/lib/upgrade/$(PKG_NAME)/xiaomi.sh
	$(INSTALL_BIN) ./files/asus.sh               $(1)/lib/upgrade/$(PKG_NAME)/asus.sh
	$(SED) "s/^FI_VERSION=/FI_VERSION=$(PKG_VERSION)/" $(1)/lib/upgrade/$(PKG_NAME)/functions.sh
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
	/etc/init.d/$(PKG_NAME) enable
	/etc/init.d/$(PKG_NAME) start
fi
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
# check if we are on real system
if [ -n "$${IPKG_INSTROOT}" ]; then
	/etc/init.d/$(PKG_NAME) stop
	/etc/init.d/$(PKG_NAME) disable
fi
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
