ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
	TARGET := iphone:clang:latest:15.0
else
	TARGET := iphone:clang:latest:12.2
endif


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FelocordTweak

FelocordTweak_FILES = $(shell find Sources/FelocordTweak -name '*.swift') $(shell find Sources/FelocordTweakC -name '*.m' -o -name '*.c' -o -name '*.mm' -o -name '*.cpp')
FelocordTweak_SWIFTFLAGS = -ISources/FelocordTweakC/include
FelocordTweak_CFLAGS = -fobjc-arc -ISources/FelocordTweakC/include

FelocordTweak_BUNDLE_NAME = FelocordPatches
FelocordTweak_BUNDLE_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/tweak.mk
