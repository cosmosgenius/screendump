TARGET = iphone:11.2:10.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = screendumpbb
$(TWEAK_NAME)_FILES = /mnt/d/codes/screendump/hooks/Tweak.xm
$(TWEAK_NAME)_FRAMEWORKS := IOSurface IOKit
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS := IOMobileFramebuffer IOSurface

ADDITIONAL_OBJCFLAGS += -I/mnt/d/codes/screendump/vncbuild/include -Iinclude
ADDITIONAL_LDFLAGS += -Wl,-segalign,4000
ADDITIONAL_CFLAGS = -w

export ARCHS = arm64 arm64e
$(TWEAK_NAME)_ARCHS = arm64 arm64e

include $(THEOS_MAKE_PATH)/tweak.mk
