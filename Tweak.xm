#include <errno.h>
#include <substrate.h>
#include <rfb/rfb.h>

// #include "IOHIDHandle.xm"

#define kSettingsPath [NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Preferences/com.cosmosgenius.screendump.plist"]

static bool CCSisEnabled = true;
static NSString *CCSPassword = nil;
static rfbScreenInfoPtr screen;
static bool isVNCRunning;
// static NSCondition *condition_;
static NSLock *lock;
static size_t width;
static size_t height;
static size_t byte_per_pixel;
static const size_t bits_per_sample = 8;

static CFTypeRef (*$GSSystemCopyCapability)(CFStringRef);
static CFTypeRef (*$GSSystemGetCapability)(CFStringRef);
static BOOL (*$MGGetBoolAnswer)(CFStringRef);

typedef void *IOMobileFramebufferRef;
typedef void *IOSurfaceAcceleratorRef;

extern CFStringRef kIOSurfaceMemoryRegion;
extern const CFStringRef kIOSurfaceIsGlobal;

extern "C" void IOMobileFramebufferGetDisplaySize(IOMobileFramebufferRef connect, CGSize *size);
extern "C" int IOSurfaceAcceleratorCreate(CFAllocatorRef allocator, void *type, IOSurfaceAcceleratorRef *accel);
extern "C" unsigned int IOSurfaceAcceleratorTransferSurface(IOSurfaceAcceleratorRef accelerator, IOSurfaceRef dest, IOSurfaceRef src, void *, void *, void *, void *);

extern "C" kern_return_t IOMobileFramebufferSwapSetLayer(
    IOMobileFramebufferRef fb,
    int layer,
    IOSurfaceRef buffer,
    CGRect bounds,
    CGRect frame,
    int flags
);

extern "C" void IOSurfaceFlushProcessorCaches(IOSurfaceRef buffer);
extern "C" int IOSurfaceLock(IOSurfaceRef surface, uint32_t options, uint32_t *seed);
extern "C" int IOSurfaceUnlock(IOSurfaceRef surface, uint32_t options, uint32_t *seed);

static IOSurfaceAcceleratorRef accelerator;
static IOSurfaceRef static_buffer;

static void VNCSettings(bool shouldStart, NSString *password);
static void VNCUpdateRunState(bool shouldStart);
static void handleVNCKeyboard(rfbBool down, rfbKeySym key, rfbClientPtr client);
static void handleVNCPointer(int buttons, int x, int y, rfbClientPtr client);

static rfbBool VNCCheck(rfbClientPtr client, const char *data, int size) {
    NSString *password = reinterpret_cast<NSString *>(screen->authPasswdData);
    if(!password) {
        return TRUE;
    }
    if ([password length] == 0) {
        return TRUE;
    }
    NSAutoreleasePool *pool([[NSAutoreleasePool alloc] init]);
    rfbEncryptBytes(client->authChallenge, const_cast<char *>([password UTF8String]));
    bool good(memcmp(client->authChallenge, data, size) == 0);
    [pool release];
    return good;
}

static void VNCSetup() {
    int argc(1);
    char *arg0(strdup("ScreenDumpVNC"));
    char *argv[] = {arg0, NULL};
    screen = rfbGetScreen(&argc, argv, width, height, bits_per_sample, 3, byte_per_pixel);
    screen->frameBuffer = (char *)malloc(width*height*byte_per_pixel);
    screen->serverFormat.redShift = bits_per_sample * 2;
    screen->serverFormat.greenShift = bits_per_sample * 1;
    screen->serverFormat.blueShift = bits_per_sample * 0;
    screen->kbdAddEvent = &handleVNCKeyboard;
    screen->ptrAddEvent = &handleVNCPointer;
    screen->passwordCheck = &VNCCheck;
    free(arg0);
    VNCUpdateRunState(CCSisEnabled);
}

static void VNCBlack() {
    screen->frameBuffer = (char *)malloc(width*height*byte_per_pixel);
}

static void initialBuffer() {
    $GSSystemCopyCapability = reinterpret_cast<CFTypeRef (*)(CFStringRef)>(dlsym(RTLD_DEFAULT, "GSSystemCopyCapability"));
    $GSSystemGetCapability = reinterpret_cast<CFTypeRef (*)(CFStringRef)>(dlsym(RTLD_DEFAULT, "GSSystemGetCapability"));
    $MGGetBoolAnswer = reinterpret_cast<BOOL (*)(CFStringRef)>(dlsym(RTLD_DEFAULT, "MGGetBoolAnswer"));

    CFTypeRef opengles2;

    if ($GSSystemCopyCapability != NULL) {
        opengles2 = (*$GSSystemCopyCapability)(CFSTR("opengles-2"));
    } else if ($GSSystemGetCapability != NULL) {
        opengles2 = (*$GSSystemGetCapability)(CFSTR("opengles-2"));
        if (opengles2 != NULL) {
            CFRetain(opengles2);
        }
    } else if ($MGGetBoolAnswer != NULL) {
        opengles2 = $MGGetBoolAnswer(CFSTR("opengles-2")) ? kCFBooleanTrue : kCFBooleanFalse;
        CFRetain(opengles2);
    } else {
        opengles2 = NULL;
    }

    bool isAccelerated(opengles2 != NULL && [(NSNumber *)opengles2 boolValue]);

    if (isAccelerated) {
        IOSurfaceAcceleratorCreate(NULL, NULL, &accelerator);
    }
    if (opengles2 != NULL) {
        CFRelease(opengles2);
    }

    if (accelerator == NULL) {
        VNCBlack();
    } else {
        static_buffer = IOSurfaceCreate((CFDictionaryRef) [NSDictionary dictionaryWithObjectsAndKeys:
            @"PurpleEDRAM", kIOSurfaceMemoryRegion,
            [NSNumber numberWithBool:YES], kIOSurfaceIsGlobal,
            [NSNumber numberWithInt:(width * byte_per_pixel)], kIOSurfaceBytesPerRow,
            [NSNumber numberWithInt:width], kIOSurfaceWidth,
            [NSNumber numberWithInt:height], kIOSurfaceHeight,
            [NSNumber numberWithInt:'BGRA'], kIOSurfacePixelFormat,
            [NSNumber numberWithInt:(width * height * byte_per_pixel)], kIOSurfaceAllocSize,
        nil]);

        screen->frameBuffer = reinterpret_cast<char *>(IOSurfaceGetBaseAddress(static_buffer));
    }
}

static void VNCSettings(bool shouldStart, NSString* password) {
    CCSisEnabled = shouldStart;
    if(password) {
        CCSPassword = password;
    }
    NSString *sEnabled = CCSisEnabled ? @"YES": @"NO";
    // NSLog(@"screendump: Settings(Enabled:%@, Password:%@)", sEnabled, CCSPassword);
    VNCUpdateRunState(CCSisEnabled);
}

static void VNCUpdateRunState(bool shouldStart) {
    if(screen == NULL) {
        return;
    }
    if(CCSPassword && CCSPassword.length) {
        screen->authPasswdData = (void *) CCSPassword;
    } else {
        screen->authPasswdData = NULL;
    }
    if(shouldStart == isVNCRunning) {
        return;
    }
    if(shouldStart) {
        rfbInitServer(screen);
        rfbRunEventLoop(screen, -1, true);
    } else {
        rfbShutdownServer(screen, true);
    }
    isVNCRunning = shouldStart;
}

static void OnFrameUpdate(IOMobileFramebufferRef fb, IOSurfaceRef buffer) {
    size_t width_;
    size_t height_;
    if(!CCSisEnabled) {
        return;
    }
    CGSize size;
    IOMobileFramebufferGetDisplaySize(fb, &size);
    width_ = size.width;
    height_ = size.height;
    if(width == 0 || height == 0) {
        width = IOSurfaceGetWidth(buffer);
        height = IOSurfaceGetHeight(buffer);
        byte_per_pixel = IOSurfaceGetBytesPerElement(buffer);
        if(width == 0 || height == 0) {
            return;
        }
        VNCSetup();
        initialBuffer();
    }
    if(screen == NULL) {
        return;
    }
    if (accelerator != NULL) {
        IOSurfaceAcceleratorTransferSurface(accelerator, buffer, static_buffer, NULL, NULL, NULL, NULL);
    } else {
        IOSurfaceLock(buffer, kIOSurfaceLockReadOnly, NULL);
        void *bytes = IOSurfaceGetBaseAddress(buffer);
        IOSurfaceFlushProcessorCaches(buffer);
        screen->frameBuffer = reinterpret_cast<char *> (bytes);
        IOSurfaceUnlock(buffer, kIOSurfaceLockReadOnly, NULL);
    }
    rfbMarkRectAsModified(screen, 0, 0, width, height);
}

static void loadPrefs(void)
{
    NSDictionary* prefs = nil;
    CFStringRef appID = CFSTR("com.cosmosgenius.screendump");
    CFArrayRef keyList = CFPreferencesCopyKeyList(appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if(keyList) {
        prefs = (NSDictionary *)CFPreferencesCopyMultiple(keyList, appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        if(!prefs) {
            prefs = [NSDictionary new];
        }
        CFRelease(keyList);
    }

    if(!prefs) {
        prefs = [NSDictionary dictionaryWithContentsOfFile:kSettingsPath];
    }

    if(prefs) {
        bool isEnabled = [prefs objectForKey:@"CCSisEnabled"] ? [[prefs objectForKey:@"CCSisEnabled"] boolValue] : CCSisEnabled;
        NSString *password = [prefs objectForKey:@"CCSPassword"];
        [prefs release];
        VNCSettings(isEnabled, password);
    }
}

%hookf(kern_return_t, IOMobileFramebufferSwapSetLayer, IOMobileFramebufferRef fb, int layer, IOSurfaceRef buffer, CGRect bounds, CGRect frame, int flags) {
    OnFrameUpdate(fb, buffer);
    return %orig;
}

%ctor
{
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, (CFNotificationCallback)loadPrefs,
        CFSTR("com.cosmosgenius.screendump/preferences.changed"),
        NULL, CFNotificationSuspensionBehaviorCoalesce);
    loadPrefs();
}


#include <mach/mach.h>
#include <mach/mach_time.h>
#include <rfb/rfb.h>
#include <rfb/keysym.h>
#include <IOKit/hid/IOHIDEventTypes.h>
#include <IOKit/hidsystem/IOHIDUsageTables.h>

typedef uint32_t IOHIDDigitizerTransducerType;

#ifdef __LP64__
typedef double IOHIDFloat;
#else
typedef float IOHIDFloat;
#endif

typedef UInt32	IOOptionBits;
typedef uint32_t IOHIDEventField;

extern "C" {
    typedef uint32_t IOHIDEventOptionBits;
    typedef struct __IOHIDEvent *IOHIDEventRef;
    typedef struct CF_BRIDGED_TYPE(id) __IOHIDEventSystemClient * IOHIDEventSystemClientRef;
    IOHIDEventRef IOHIDEventCreateKeyboardEvent(
        CFAllocatorRef allocator,
        uint64_t time, uint16_t page, uint16_t usage,
        Boolean down, IOHIDEventOptionBits flags
    );

    IOHIDEventRef IOHIDEventCreateDigitizerEvent(CFAllocatorRef allocator, uint64_t timeStamp, IOHIDDigitizerTransducerType type, uint32_t index, uint32_t identity, uint32_t eventMask, uint32_t buttonMask, IOHIDFloat x, IOHIDFloat y, IOHIDFloat z, IOHIDFloat tipPressure, IOHIDFloat barrelPressure, Boolean range, Boolean touch, IOOptionBits options);
    IOHIDEventRef IOHIDEventCreateDigitizerFingerEvent(CFAllocatorRef allocator, uint64_t timeStamp, uint32_t index, uint32_t identity, uint32_t eventMask, IOHIDFloat x, IOHIDFloat y, IOHIDFloat z, IOHIDFloat tipPressure, IOHIDFloat twist, Boolean range, Boolean touch, IOOptionBits options);

    IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);

    void IOHIDEventAppendEvent(IOHIDEventRef parent, IOHIDEventRef child);
    void IOHIDEventSetIntegerValue(IOHIDEventRef event, IOHIDEventField field, int value);
    void IOHIDEventSetSenderID(IOHIDEventRef event, uint64_t sender);

    void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);
    // void IOHIDEventSystemConnectionDispatchEvent(IOHIDEventSystemConnectionRef connection, IOHIDEventRef event);
}

static void VNCPointerNew(int buttons, int x, int y, CGPoint location, int diff, bool twas, bool tis);

static void SendHIDEvent(IOHIDEventRef event) {
    static IOHIDEventSystemClientRef client_(NULL);
    if (client_ == NULL)
        client_ = IOHIDEventSystemClientCreate(kCFAllocatorDefault);

    // IOHIDEventSetSenderID(event, 0xDEFACEDBEEFFECE5);
    // IOHIDEventSetSenderID(event, 0x000000010000027F);
    IOHIDEventSetSenderID(event, 0x8000000817319372);
    IOHIDEventSystemClientDispatchEvent(client_, event);
    CFRelease(event);
}

static void VNCKeyboard(rfbBool down, rfbKeySym key, rfbClientPtr client) {
    uint16_t usage;

    switch (key) {
        case XK_exclam: case XK_1: usage = kHIDUsage_Keyboard1; break;
        case XK_at: case XK_2: usage = kHIDUsage_Keyboard2; break;
        case XK_numbersign: case XK_3: usage = kHIDUsage_Keyboard3; break;
        case XK_dollar: case XK_4: usage = kHIDUsage_Keyboard4; break;
        case XK_percent: case XK_5: usage = kHIDUsage_Keyboard5; break;
        case XK_asciicircum: case XK_6: usage = kHIDUsage_Keyboard6; break;
        case XK_ampersand: case XK_7: usage = kHIDUsage_Keyboard7; break;
        case XK_asterisk: case XK_8: usage = kHIDUsage_Keyboard8; break;
        case XK_parenleft: case XK_9: usage = kHIDUsage_Keyboard9; break;
        case XK_parenright: case XK_0: usage = kHIDUsage_Keyboard0; break;

        case XK_A: case XK_a: usage = kHIDUsage_KeyboardA; break;
        case XK_B: case XK_b: usage = kHIDUsage_KeyboardB; break;
        case XK_C: case XK_c: usage = kHIDUsage_KeyboardC; break;
        case XK_D: case XK_d: usage = kHIDUsage_KeyboardD; break;
        case XK_E: case XK_e: usage = kHIDUsage_KeyboardE; break;
        case XK_F: case XK_f: usage = kHIDUsage_KeyboardF; break;
        case XK_G: case XK_g: usage = kHIDUsage_KeyboardG; break;
        case XK_H: case XK_h: usage = kHIDUsage_KeyboardH; break;
        case XK_I: case XK_i: usage = kHIDUsage_KeyboardI; break;
        case XK_J: case XK_j: usage = kHIDUsage_KeyboardJ; break;
        case XK_K: case XK_k: usage = kHIDUsage_KeyboardK; break;
        case XK_L: case XK_l: usage = kHIDUsage_KeyboardL; break;
        case XK_M: case XK_m: usage = kHIDUsage_KeyboardM; break;
        case XK_N: case XK_n: usage = kHIDUsage_KeyboardN; break;
        case XK_O: case XK_o: usage = kHIDUsage_KeyboardO; break;
        case XK_P: case XK_p: usage = kHIDUsage_KeyboardP; break;
        case XK_Q: case XK_q: usage = kHIDUsage_KeyboardQ; break;
        case XK_R: case XK_r: usage = kHIDUsage_KeyboardR; break;
        case XK_S: case XK_s: usage = kHIDUsage_KeyboardS; break;
        case XK_T: case XK_t: usage = kHIDUsage_KeyboardT; break;
        case XK_U: case XK_u: usage = kHIDUsage_KeyboardU; break;
        case XK_V: case XK_v: usage = kHIDUsage_KeyboardV; break;
        case XK_W: case XK_w: usage = kHIDUsage_KeyboardW; break;
        case XK_X: case XK_x: usage = kHIDUsage_KeyboardX; break;
        case XK_Y: case XK_y: usage = kHIDUsage_KeyboardY; break;
        case XK_Z: case XK_z: usage = kHIDUsage_KeyboardZ; break;

        case XK_underscore: case XK_minus: usage = kHIDUsage_KeyboardHyphen; break;
        case XK_plus: case XK_equal: usage = kHIDUsage_KeyboardEqualSign; break;
        case XK_braceleft: case XK_bracketleft: usage = kHIDUsage_KeyboardOpenBracket; break;
        case XK_braceright: case XK_bracketright: usage = kHIDUsage_KeyboardCloseBracket; break;
        case XK_bar: case XK_backslash: usage = kHIDUsage_KeyboardBackslash; break;
        case XK_colon: case XK_semicolon: usage = kHIDUsage_KeyboardSemicolon; break;
        case XK_quotedbl: case XK_apostrophe: usage = kHIDUsage_KeyboardQuote; break;
        case XK_asciitilde: case XK_grave: usage = kHIDUsage_KeyboardGraveAccentAndTilde; break;
        case XK_less: case XK_comma: usage = kHIDUsage_KeyboardComma; break;
        case XK_greater: case XK_period: usage = kHIDUsage_KeyboardPeriod; break;
        case XK_question: case XK_slash: usage = kHIDUsage_KeyboardSlash; break;

        case XK_Return: usage = kHIDUsage_KeyboardReturnOrEnter; break;
        case XK_BackSpace: usage = kHIDUsage_KeyboardDeleteOrBackspace; break;
        case XK_Tab: usage = kHIDUsage_KeyboardTab; break;
        case XK_space: usage = kHIDUsage_KeyboardSpacebar; break;

        case XK_Shift_L: usage = kHIDUsage_KeyboardLeftShift; break;
        case XK_Shift_R: usage = kHIDUsage_KeyboardRightShift; break;
        case XK_Control_L: usage = kHIDUsage_KeyboardLeftControl; break;
        case XK_Control_R: usage = kHIDUsage_KeyboardRightControl; break;
        case XK_Meta_L: usage = kHIDUsage_KeyboardLeftAlt; break;
        case XK_Meta_R: usage = kHIDUsage_KeyboardRightAlt; break;
        case XK_Alt_L: usage = kHIDUsage_KeyboardLeftGUI; break;
        case XK_Alt_R: usage = kHIDUsage_KeyboardRightGUI; break;

        case XK_Up: usage = kHIDUsage_KeyboardUpArrow; break;
        case XK_Down: usage = kHIDUsage_KeyboardDownArrow; break;
        case XK_Left: usage = kHIDUsage_KeyboardLeftArrow; break;
        case XK_Right: usage = kHIDUsage_KeyboardRightArrow; break;

        case XK_Home: case XK_Begin: usage = kHIDUsage_KeyboardHome; break;
        case XK_End: usage = kHIDUsage_KeyboardEnd; break;
        case XK_Page_Up: usage = kHIDUsage_KeyboardPageUp; break;
        case XK_Page_Down: usage = kHIDUsage_KeyboardPageDown; break;

        default: return;
    }

    SendHIDEvent(IOHIDEventCreateKeyboardEvent(kCFAllocatorDefault, mach_absolute_time(), kHIDPage_KeyboardOrKeypad, usage, down, 0));
}

static int buttons_;
static int x_, y_;

static void VNCPointer(int buttons, int x, int y, rfbClientPtr client) {
    // if (ratio_ == 0)
    //     return;

    CGPoint location = {x, y};

    // if (width_ > height_) {
    //     int t(x);
    //     x = height_ - 1 - y;
    //     y = t;

    //     if (!iPad1_) {
    //         x = height_ - 1 - x;
    //         y = width_ - 1 - y;
    //     }
    // }

    // x /= ratio_;
    // y /= ratio_;

    // x_ = x; y_ = y;
    int diff = buttons_ ^ buttons;
    bool twas((buttons_ & 0x1) != 0);
    bool tis((buttons & 0x1) != 0);
    buttons_ = buttons;

    rfbDefaultPtrAddEvent(buttons, x, y, client);

    // if (Ashikase(false)) {
    //     AshikaseSendEvent(x, y, buttons);
    //     return;
    // }

    return VNCPointerNew(buttons, x, y, location, diff, twas, tis);
}

static void VNCPointerNew(int buttons, int x, int y, CGPoint location, int diff, bool twas, bool tis) {
    if ((diff & 0x10) != 0)
        SendHIDEvent(IOHIDEventCreateKeyboardEvent(kCFAllocatorDefault, mach_absolute_time(), kHIDPage_Telephony, kHIDUsage_Tfon_Flash, (buttons & 0x10) != 0, 0));
    if ((diff & 0x04) != 0)
        SendHIDEvent(IOHIDEventCreateKeyboardEvent(kCFAllocatorDefault, mach_absolute_time(), kHIDPage_Consumer, kHIDUsage_Csmr_Menu, (buttons & 0x04) != 0, 0));
    if ((diff & 0x02) != 0)
        SendHIDEvent(IOHIDEventCreateKeyboardEvent(kCFAllocatorDefault, mach_absolute_time(), kHIDPage_Consumer, kHIDUsage_Csmr_Power, (buttons & 0x02) != 0, 0));

    uint32_t handm;
    uint32_t fingerm;

    if (twas == 0 && tis == 1) {
        handm = kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch | kIOHIDDigitizerEventIdentity;
        fingerm = kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch;
    } else if (twas == 1 && tis == 1) {
        handm = kIOHIDDigitizerEventPosition;
        fingerm = kIOHIDDigitizerEventPosition;
    } else if (twas == 1 && tis == 0) {
        handm = kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch | kIOHIDDigitizerEventIdentity | kIOHIDDigitizerEventPosition;
        fingerm = kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch;
    } else return;

    // XXX: avoid division in VNCPointer()
    // x *= ratio_;
    // y *= ratio_;

    IOHIDFloat xf(x);
    IOHIDFloat yf(y);

    xf /= width;
    yf /= height;

    IOHIDEventRef hand(IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault, mach_absolute_time(), kIOHIDDigitizerTransducerTypeHand, 1<<22, 1, handm, 0, xf, yf, 0, 0, 0, 0, 0, 0));
    IOHIDEventSetIntegerValue(hand, kIOHIDEventFieldIsBuiltIn, true);
    IOHIDEventSetIntegerValue(hand, kIOHIDEventFieldDigitizerIsDisplayIntegrated, true);

    IOHIDEventRef finger(IOHIDEventCreateDigitizerFingerEvent(kCFAllocatorDefault, mach_absolute_time(), 3, 2, fingerm, xf, yf, 0, 0, 0, tis, tis, 0));
    IOHIDEventAppendEvent(hand, finger);
    CFRelease(finger);

    SendHIDEvent(hand);
}

static void handleVNCKeyboard(rfbBool down, rfbKeySym key, rfbClientPtr client) {
    VNCKeyboard(down, key, client);
}

static void handleVNCPointer(int buttons, int x, int y, rfbClientPtr client) {
    VNCPointer(buttons, x, y, client);
}
