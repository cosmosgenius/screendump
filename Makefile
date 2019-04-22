TARGET = iphone:11.2:10.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = screendump
screendump_FILES = Tweak.xm
screendump_FRAMEWORKS := IOSurface
screendump_PRIVATE_FRAMEWORKS := IOMobileFramebuffer

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 backboardd"
