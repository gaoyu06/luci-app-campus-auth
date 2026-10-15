include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-campus-auth
PKG_VERSION:=0.2.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-campus-auth
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Campus network authentication for LuCI
  DEPENDS:=+luci-base +rpcd +curl +flock
endef

define Package/luci-app-campus-auth/description
  LuCI frontend and background service for configurable campus portal authentication.
endef

define Package/luci-app-campus-auth/conffiles
/etc/config/campus_auth
endef

define Build/Compile
endef

define Package/luci-app-campus-auth/install
	$(CP) ./etc $(1)/
	$(CP) ./usr $(1)/
	$(CP) ./www $(1)/
	chmod 0755 $(1)/etc/init.d/campus_auth $(1)/usr/bin/campus-auth $(1)/www/campus-auth/cgi-bin/api
endef

$(eval $(call BuildPackage,luci-app-campus-auth))
