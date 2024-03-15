ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
	TARGET := iphone:clang:latest:15.0
else
	TARGET := iphone:clang:latest:12.2
endif


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PyoncordTweak

PyoncordTweak_FILES = $(shell find Sources/PyoncordTweak -name '*.swift') $(shell find Sources/PyoncordTweakC -name '*.m' -o -name '*.c' -o -name '*.mm' -o -name '*.cpp')
PyoncordTweak_SWIFTFLAGS = -ISources/PyoncordTweakC/include
PyoncordTweak_CFLAGS = -fobjc-arc -ISources/PyoncordTweakC/include

PyoncordTweak_BUNDLE_NAME = PyoncordPatches
PyoncordTweak_BUNDLE_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/tweak.mk
