#
# Copyright (C) 2023 remittor
#

include $(TOPDIR)/rules.mk

PKG_NAME:=facinstall
PKG_VERSION:=1.7
PKG_RELEASE:=20240303

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

define Package/$(PKG_NAME)/conffiles
/etc/config/$(PKG_NAME)
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/$(PKG_NAME).config $(1)/etc/config/$(PKG_NAME)

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/$(PKG_NAME).init $(1)/etc/init.d/$(PKG_NAME)

	$(INSTALL_DIR) $(1)/lib/upgrade/$(PKG_NAME)
	$(INSTALL_BIN) ./files/$(PKG_NAME).sh   $(1)/lib/upgrade/$(PKG_NAME)/$(PKG_NAME).sh

	$(INSTALL_DIR) $(1)/lib/upgrade/$(PKG_NAME)
	$(INSTALL_BIN) ./files/functions.sh     $(1)/lib/upgrade/$(PKG_NAME)/functions.sh

	$(INSTALL_DIR) $(1)/lib/upgrade/$(PKG_NAME)
	$(INSTALL_BIN) ./files/fi_boards.sh     $(1)/lib/upgrade/$(PKG_NAME)/fi_boards.sh

	$(INSTALL_DIR) $(1)/lib/upgrade/$(PKG_NAME)
	$(INSTALL_BIN) ./files/validate_fw_image.sh  $(1)/lib/upgrade/$(PKG_NAME)/validate_fw_image.sh

	$(INSTALL_DIR) $(1)/lib/upgrade/$(PKG_NAME)
	$(INSTALL_BIN) ./files/fi_do_stage2.sh       $(1)/lib/upgrade/$(PKG_NAME)/fi_do_stage2.sh

	$(INSTALL_DIR) $(1)/lib/upgrade/$(PKG_NAME)
	$(INSTALL_BIN) ./files/xiaomi.sh    $(1)/lib/upgrade/$(PKG_NAME)/xiaomi.sh

	$(INSTALL_DIR) $(1)/lib/upgrade/$(PKG_NAME)
	$(INSTALL_BIN) ./files/asus.sh      $(1)/lib/upgrade/$(PKG_NAME)/asus.sh
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
	/etc/init.d/$(PKG_NAME) enabled
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
