/* How to Hook with Logos
Hooks are written with syntax similar to that of an Objective-C @implementation.
You don't need to #include <substrate.h>, it will be done automatically, as will
the generation of a class list and an automatic constructor.

%hook ClassName

// Hooking a class method
+ (id)sharedInstance {
	return %orig;
}

// Hooking an instance method with an argument.
- (void)messageName:(int)argument {
	%log; // Write a message about this call, including its class, name and arguments, to the system log.

	%orig; // Call through to the original function with its original arguments.
	%orig(nil); // Call through to the original function with a custom argument.

	// If you use %orig(), you MUST supply all arguments (except for self and _cmd, the automatically generated ones.)
}

// Hooking an instance method with no arguments.
- (id)noArguments {
	%log;
	id awesome = %orig;
	[awesome doSomethingElse];

	return awesome;
}

// Always make sure you clean up after yourself; Not doing so could have grave consequences!
%end
*/

#include <errno.h>

typedef void *IOMobileFramebufferRef;
extern "C" void IOMobileFramebufferGetDisplaySize(IOMobileFramebufferRef connect, CGSize *size);

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

int bmp_write(const void *image, size_t xsize, size_t ysize, const char *filename) {
    // unsigned char header[54] = {
    //     0x42, 0x4d, 0, 0, 0, 0, 0, 0, 0, 0,
    //     54, 0, 0, 0, 40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 32, 0,
    //     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    //     0, 0, 0, 0
    // };

    // long file_size = (long)xsize * (long)ysize * 4 + 54;
    // header[2] = (unsigned char)(file_size &0x000000ff);
    // header[3] = (file_size >> 8) & 0x000000ff;
    // header[4] = (file_size >> 16) & 0x000000ff;
    // header[5] = (file_size >> 24) & 0x000000ff;

    // long width = xsize;
    // header[18] = width & 0x000000ff;
    // header[19] = (width >> 8) &0x000000ff;
    // header[20] = (width >> 16) &0x000000ff;
    // header[21] = (width >> 24) &0x000000ff;

    // long height = ysize;
    // header[22] = height &0x000000ff;
    // header[23] = (height >> 8) &0x000000ff;
    // header[24] = (height >> 16) &0x000000ff;
    // header[25] = (height >> 24) &0x000000ff;

    char fname_bmp[128];
    sprintf(fname_bmp, "%s", filename);

    FILE *fp;
    if (!(fp = fopen(fname_bmp, "wb"))) {
        NSLog(@"Error no is : %s, %d", fname_bmp, errno);
        return -1;
    }

    // fwrite(header, sizeof(unsigned char), 54, fp);
    fwrite(image, sizeof(unsigned char), (size_t)(long)xsize * ysize * 4, fp);

    fclose(fp);
    return 0;
}

int write_to_file(const void *image, size_t xsize, size_t ysize, size_t pixel_size, const char *filename) {
    char fname_bmp[128];
    sprintf(fname_bmp, "%s", filename);
    if( access( fname_bmp, F_OK ) != -1 ) {
        return 0;
    } else {
        FILE *fp;
        if (!(fp = fopen(fname_bmp, "wb"))) {
            NSLog(@"Error no is : %s, %d", fname_bmp, errno);
            return -1;
        }
        NSLog(@"sharat write to file");
        fwrite(image, sizeof(unsigned char), (size_t)(long)xsize * ysize * pixel_size, fp);
        fclose(fp);
    }
    return 0;
}

%hookf(kern_return_t, IOMobileFramebufferSwapSetLayer, IOMobileFramebufferRef fb, int layer, IOSurfaceRef buffer, CGRect bounds, CGRect frame, int flags) {
    CGSize size;
    size_t width_;
    size_t height_;
    IOMobileFramebufferGetDisplaySize(fb, &size);
    width_ = size.width;
    height_ = size.height;
    size_t width = IOSurfaceGetWidth(buffer);
    size_t height = IOSurfaceGetHeight(buffer);
    size_t byte_per_pixel = IOSurfaceGetBytesPerElement(buffer);
    NSLog(@"sharat %ld, %ld, %ld, %ld, %ld", width_, height_, width, height, byte_per_pixel);
    NSString *path = @"/tmp/test.bmp";
    void *bytes = IOSurfaceGetBaseAddress(buffer);
    // if(width) {
    //     int ret;
    //     ret = bmp_write(bytes, width, height, [path UTF8String]);
    //     NSLog(@"sharat %d", ret);
    // }

    IOSurfaceLock(buffer, kIOSurfaceLockReadOnly, NULL);
    IOSurfaceFlushProcessorCaches(buffer);
    write_to_file(bytes, width, height, byte_per_pixel, [path UTF8String]);
    IOSurfaceUnlock(buffer, kIOSurfaceLockReadOnly, NULL);

    return %orig;
}

