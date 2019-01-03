#include <substrate.h>
#include <CoreFoundation/CoreFoundation.h>
// #include <errno.h>
// typedef void *IOMobileFramebufferRef;
typedef struct __IOSurface *IOSurfaceRef;
typedef struct __IOMobileFramebuffer *IOMobileFramebufferRef;
// typedef void *CoreSurfaceBufferRef;
// typedef mach_port_t io_object_t;
// typedef io_object_t io_connect_t;
// typedef io_connect_t IOMobileFramebufferConnection;
// typedef	kern_return_t IOReturn;
typedef unsigned int u_int32_t;
typedef unsigned long long u_int64_t;
typedef u_int64_t uint64_t;
typedef u_int32_t uint32_t;

// extern "C" void IOMobileFramebufferGetDisplaySize(IOMobileFramebufferRef connect, CGSize *size);

extern "C" kern_return_t IOMobileFramebufferSwapSetLayer(
    IOMobileFramebufferRef fb,
    uint32_t layer,
    IOSurfaceRef buffer,
    CGRect bounds,
    CGRect frame,
    uint32_t flags
);

// extern "C" kern_return_t IOMobileFramebufferSwapSetLayer(IOMobileFramebufferRef fb, uint64_t layer, IOSurfaceRef buffer, uint64_t bounds);

// extern "C" kern_return_t IMobileFramebufferSwapSetLayer(
//     IOMobileFramebufferConnection connection,
//     int layerid,
//     CoreSurfaceBufferRef surface
// );O

// extern "C" IOReturn kern_SwapSetLayer(
//     IOMobileFramebufferRef fb,
//     uint32_t layer,
//     IOSurfaceRef buffer,
//     CGRect bounds,
//     CGRect frame,
//     uint32_t flags
// );

// int bmp_write(const void *image, size_t xsize, size_t ysize, const char *filename) {
//     unsigned char header[54] = {
//         0x42, 0x4d, 0, 0, 0, 0, 0, 0, 0, 0,
//         54, 0, 0, 0, 40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 32, 0,
//         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
//         0, 0, 0, 0
//     };

//     long file_size = (long)xsize * (long)ysize * 4 + 54;
//     header[2] = (unsigned char)(file_size &0x000000ff);
//     header[3] = (file_size >> 8) & 0x000000ff;
//     header[4] = (file_size >> 16) & 0x000000ff;
//     header[5] = (file_size >> 24) & 0x000000ff;

//     long width = xsize;
//     header[18] = width & 0x000000ff;
//     header[19] = (width >> 8) &0x000000ff;
//     header[20] = (width >> 16) &0x000000ff;
//     header[21] = (width >> 24) &0x000000ff;

//     long height = ysize;
//     header[22] = height &0x000000ff;
//     header[23] = (height >> 8) &0x000000ff;
//     header[24] = (height >> 16) &0x000000ff;
//     header[25] = (height >> 24) &0x000000ff;

//     char fname_bmp[128];
//     sprintf(fname_bmp, "%s", filename);

//     FILE *fp;
//     if (!(fp = fopen(fname_bmp, "wb"))) {
//         NSLog(@"Error no is : %s, %d", fname_bmp, errno);
//         return -1;
//     }

//     fwrite(header, sizeof(unsigned char), 54, fp);
//     fwrite(image, sizeof(unsigned char), (size_t)(long)xsize * ysize * 4, fp);

//     fclose(fp);
//     return 0;
// }

// %hookf(kern_return_t, IOMobileFramebufferSwapSetLayer, IOMobileFramebufferRef fb, int layer, IOSurfaceRef buffer, CGRect bounds, CGRect frame, int flags) {
//     CGSize size;
//     size_t width_;
//     size_t height_;
//     IOMobileFramebufferGetDisplaySize(fb, &size);
//     width_ = size.width;
//     height_ = size.height;
//     size_t width = IOSurfaceGetWidth(buffer);
//     size_t height = IOSurfaceGetHeight(buffer);
//     NSLog(@"sharat %ld, %ld, %ld, %ld", width_, height_, width, height);
//     NSString *path = @"/tmp/test.bmp";
//     void *bytes = IOSurfaceGetBaseAddress(buffer);
//     if(width) {
//         int ret;
//         ret = bmp_write(bytes, width, height, [path UTF8String]);
//         NSLog(@"sharat %d", ret);
//     }
//     NSLog(@"sharat");
//     return %orig;
// }

// %hookf(kern_return_t, IOMobileFramebufferSwapSetLayer, IOMobileFramebufferRef fb, int layer, IOSurfaceRef buffer, CGRect bounds, CGRect frame, int flags) {
//     NSLog(@"sharat: IOMobileFramebufferSwapSetLayer");
//     return %orig;
// }

// %hookf(kern_return_t, IOMobileFramebufferSwapSetLayer, IOMobileFramebufferRef fb, uint64_t layer, IOSurfaceRef buffer, uint64_t bounds) {
//     NSLog(@"sharat: IOMobileFramebufferSwapSetLayer");
//     return %orig;
// }

// %hookf(IOReturn, kern_SwapSetLayer, IOMobileFramebufferRef fb, uint32_t layer, IOSurfaceRef buffer, CGRect bounds, CGRect frame, uint32_t flags) {
//     NSLog(@"sharat: kern_SwapSetLayer");
//     return %orig;
// }


UIColor *(*oldinitWithRed)(id self, SEL _cmd,
    CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha);

UIColor *newinitWithRed(id self, SEL _cmd,
    CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha
) {
    return oldinitWithRed(self, _cmd, 1, 0, blue, alpha);
}

kern_return_t (*oldIOMobileFramebufferSwapSetLayer)(IOMobileFramebufferRef fb, uint32_t layer, IOSurfaceRef buffer, CGRect bounds, CGRect frame, uint32_t flags);

kern_return_t newIOMobileFramebufferSwapSetLayer(IOMobileFramebufferRef fb, uint32_t layer, IOSurfaceRef buffer, CGRect bounds, CGRect frame, uint32_t flags) {
    NSLog(@"sharat: IOMobileFramebufferSwapSetLayer");
    return oldIOMobileFramebufferSwapSetLayer(fb, layer, buffer, bounds, frame, flags);
}

MSInitialize {
    MSHookMessageEx([UIColor class], @selector(initWithRed:green:blue:alpha:),
        (IMP) &newinitWithRed, (IMP*) &oldinitWithRed);

    MSHookFunction(
        (void *)IOMobileFramebufferSwapSetLayer,
        (void *)&newIOMobileFramebufferSwapSetLayer,
        (void **)&oldIOMobileFramebufferSwapSetLayer
    );
}
