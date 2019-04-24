#include <errno.h>
#include <substrate.h>
#include <rfb/rfb.h>

static bool CCSisEnabled = true;
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
static void VNCUpdateRunState(bool shouldStart);

static IOSurfaceAcceleratorRef accelerator;
static IOSurfaceRef static_buffer;

static void VNCSetup() {
    int argc(1);
    char *arg0(strdup("ScreenDumpVNC"));
    char *argv[] = {arg0, NULL};
    screen = rfbGetScreen(&argc, argv, width, height, bits_per_sample, 3, byte_per_pixel);
    screen->frameBuffer = (char *)malloc(width*height*byte_per_pixel);
    screen->serverFormat.redShift = bits_per_sample * 2;
    screen->serverFormat.greenShift = bits_per_sample * 1;
    screen->serverFormat.blueShift = bits_per_sample * 0;
    free(arg0);
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

static void VNCUpdateRunState(bool shouldStart) {
    if(screen == NULL) {
        return;
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

    NSLog(@"sharat %ld, %ld, %ld, %ld, %ld", width_, height_, width, height, byte_per_pixel);
    NSLog(@"sharat accerated %ld", accelerator == NULL);
    if(screen == NULL) {
        return;
    }
    if (accelerator != NULL) {
        IOSurfaceAcceleratorTransferSurface(accelerator, buffer, static_buffer, NULL, NULL, NULL, NULL);
        NSLog(@"sharat accerated transfer");
    } else {
        IOSurfaceLock(buffer, kIOSurfaceLockReadOnly, NULL);
        void *bytes = IOSurfaceGetBaseAddress(buffer);
        IOSurfaceFlushProcessorCaches(buffer);
        screen->frameBuffer = reinterpret_cast<char *> (bytes);
        IOSurfaceUnlock(buffer, kIOSurfaceLockReadOnly, NULL);
    }
    rfbMarkRectAsModified(screen, 0, 0, width, height);
}

static void loadPrefs()
{
    CFPreferencesAppSynchronize(CFSTR("com.cosmosgenius.screendump"));
    Boolean valid;
    bool enabled(CFPreferencesGetAppBooleanValue(CFSTR("CCSisEnabled"), CFSTR("com.cosmosgenius.screendump"), &valid));
    CCSisEnabled = enabled;
    @synchronized (lock) {
        VNCUpdateRunState(CCSisEnabled);
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
    lock = [[NSLock alloc] init];
    loadPrefs();
}
