TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = Discord

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Felocord
BUNDLE_NAME = FelocordResources

Felocord_FILES = $(wildcard Sources/*.x Sources/*.m Sources/**/*.x Sources/**/*.m)
Felocord_CFLAGS = -fobjc-arc -DPACKAGE_VERSION='@"$(THEOS_PACKAGE_BASE_VERSION)"' -I$(THEOS_PROJECT_DIR)/Headers
Felocord_FRAMEWORKS = Foundation UIKit CoreGraphics CoreText CoreFoundation

FelocordResources_INSTALL_PATH = "/Library/Application\ Support/"
FelocordResources_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

before-all::
	$(ECHO_NOTHING)mkdir -p Resources$(ECHO_END)
	$(ECHO_NOTHING)sed -e 's/@PACKAGE_VERSION@/$(THEOS_PACKAGE_BASE_VERSION)/g' \
		-e 's/@TWEAK_NAME@/$(TWEAK_NAME)/g' \
		Sources/payload-base.template.js > Resources/payload-base.js$(ECHO_END)

after-stage::
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) -name ".DS_Store" -delete$(ECHO_END)

after-package::
	$(ECHO_NOTHING)rm -rf Resources$(ECHO_END)
