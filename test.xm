#line 1 "Tweak.xm"
#include <substrate.h>
#include <CoreFoundation/CoreFoundation.h>

typedef void *IOMobileFramebufferRef;








































































































#include <substrate.h>
#if defined(__clang__)
#if __has_feature(objc_arc)
#define _LOGOS_SELF_TYPE_NORMAL __unsafe_unretained
#define _LOGOS_SELF_TYPE_INIT __attribute__((ns_consumed))
#define _LOGOS_SELF_CONST const
#define _LOGOS_RETURN_RETAINED __attribute__((ns_returns_retained))
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif




#line 108 "Tweak.xm"
__unused static kern_return_t (*_logos_orig$_ungrouped$IOMobileFramebufferSwapSetLayer)(IOMobileFramebufferRef fb, int layer, IOSurfaceRef buffer, CGRect bounds, CGRect frame, int flags); __unused static kern_return_t _logos_function$_ungrouped$IOMobileFramebufferSwapSetLayer(IOMobileFramebufferRef fb, int layer, IOSurfaceRef buffer, CGRect bounds, CGRect frame, int flags) {
    NSLog(@"sharat: IOMobileFramebufferSwapSetLayer");
    return _logos_orig$_ungrouped$IOMobileFramebufferSwapSetLayer(fb, layer, buffer, bounds, frame, flags);
}












UIColor *(*oldinitWithRed)(id self, SEL _cmd,
    CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha);

UIColor *newinitWithRed(id self, SEL _cmd,
    CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha
) {
    return oldinitWithRed(self, _cmd, 1, 0, blue, alpha);
}

MSInitialize {
    MSHookMessageEx([UIColor class], @selector(initWithRed:green:blue:alpha:),
        (IMP) &newinitWithRed, (IMP*) &oldinitWithRed);
}
static __attribute__((constructor)) void _logosLocalInit() {
{
    MSHookFunction(
        (void *)IOMobileFramebufferSwapSetLayer,
        (void *)&_logos_function$_ungrouped$IOMobileFramebufferSwapSetLayer,
        (void **)&_logos_orig$_ungrouped$IOMobileFramebufferSwapSetLayer
    );
        } }
#line 137 "Tweak.xm"
