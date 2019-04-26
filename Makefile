TARGET = iphone:11.2:10.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = screendump
screendump_FILES = Tweak.xm
screendump_FRAMEWORKS := IOSurface IOKit
screendump_PRIVATE_FRAMEWORKS := IOMobileFramebuffer IOSurface

ADDITIONAL_OBJCFLAGS += -Ivncbuild/include -Iinclude
ADDITIONAL_LDFLAGS += -Lvncbuild/lib  -lvncserver -lpng -llzo2 -ljpeg -lssl -lcrypto -lz
ADDITIONAL_CFLAGS = -w

include $(THEOS_MAKE_PATH)/tweak.mk

# SUBPROJECTS += screendumpprefs
# include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 backboardd"

internal-stage::
	#PreferenceLoader plist
	$(ECHO_NOTHING)if [ -f Preferences.plist ]; then mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/screendump; cp Preferences.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/screendump/; fi$(ECHO_END)
