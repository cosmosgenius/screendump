ARCHS := arm64

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ScreenDumpprefs
ScreenDumpprefs_FILES = CCSRootListController.m
ScreenDumpprefs_INSTALL_PATH = /Library/PreferenceBundles
ScreenDumpprefs_FRAMEWORKS = UIKit
ScreenDumpprefs_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/ScreenDumpprefs.plist$(ECHO_END)
