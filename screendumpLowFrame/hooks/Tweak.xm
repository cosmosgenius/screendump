#include <errno.h>
#include <substrate.h>
#include <rfb/rfb.h>
#import <notify.h>

#undef NSLog

#define kSettingsPath @"//var/mobile/Library/Preferences/com.cosmosgenius.screendump.plist"

extern "C" UIImage* _UICreateScreenUIImage();

static BOOL isEnabled;
static BOOL isBlackScreen;

@interface CapturerScreen : NSObject
- (void)start;
@end

@implementation CapturerScreen
- (id)init
{
	self = [super init];
	
	return self;
}
- (unsigned char *)pixelBRGABytesFromImageRef:(CGImageRef)imageRef
{
    
    NSUInteger iWidth = CGImageGetWidth(imageRef);
    NSUInteger iHeight = CGImageGetHeight(imageRef);
    NSUInteger iBytesPerPixel = 4;
    NSUInteger iBytesPerRow = iBytesPerPixel * iWidth;
    NSUInteger iBitsPerComponent = 8;
    unsigned char *imageBytes = (unsigned char *)malloc(iWidth * iHeight * iBytesPerPixel);
    
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(imageBytes,
                                                 iWidth,
                                                 iHeight,
                                                 iBitsPerComponent,
                                                 iBytesPerRow,
                                                 colorspace,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    CGRect rect = CGRectMake(0 , 0 , iWidth, iHeight);
    CGContextDrawImage(context , rect ,imageRef);
    CGColorSpaceRelease(colorspace);
    CGContextRelease(context);
    CGImageRelease(imageRef);
    
    return imageBytes;
}
- (unsigned char *)pixelBRGABytesFromImage:(UIImage *)image
{
    return [self pixelBRGABytesFromImageRef:image.CGImage];
}
- (void)start
{
	dispatch_async(dispatch_get_main_queue(), ^(void){
		[NSTimer scheduledTimerWithTimeInterval:0.4f target:self selector:@selector(capture) userInfo:nil repeats:YES];
	});
}
- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize
{
    //UIGraphicsBeginImageContext(newSize);
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0f);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();    
    UIGraphicsEndImageContext();
	[image release];
    return newImage;
}
- (void)capture
{
	@autoreleasepool {
		
		if(isBlackScreen || !isEnabled) {
			return;
		}
		
		UIImage* image = _UICreateScreenUIImage();
		
		CGSize newS = CGSizeMake(image.size.width, image.size.height);
		
		image = [[self imageWithImage:image scaledToSize:newS] copy];
		
		CGImageRef imageRef = image.CGImage;
		
		NSUInteger iWidth = CGImageGetWidth(imageRef);
		NSUInteger iHeight = CGImageGetHeight(imageRef);
		NSUInteger iBytesPerPixel = 4;
		
		size_t size = iWidth * iHeight * iBytesPerPixel;
		
		unsigned char * bytes = [self pixelBRGABytesFromImageRef:imageRef];
		
		dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			@autoreleasepool {
				NSData *imageData = [NSData dataWithBytesNoCopy:bytes length:size freeWhenDone:YES];
				[imageData writeToFile:@"//tmp/screendump_Buff.tmp" atomically:YES];
				[@{@"width":@(iWidth), @"height":@(iHeight), @"size":@(size),} writeToFile:@"//tmp/screendump_Info.tmp" atomically:YES];
				notify_post("com.julioverne.screendump/frameChanged");
			}
		});
	}
}
@end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application
{
	%orig;
	CapturerScreen* cap = [[CapturerScreen alloc] init];
	[cap start];
}
%end


static void screenDisplayStatus(CFNotificationCenterRef center, void* observer, CFStringRef name, const void* object, CFDictionaryRef userInfo)
{
    uint64_t state;
    int token;
    notify_register_check("com.apple.iokit.hid.displayStatus", &token);
    notify_get_state(token, &state);
    notify_cancel(token);
    if(!state) {
		isBlackScreen = YES;
    } else {
		isBlackScreen = NO;
	}
}

static void loadPrefs(CFNotificationCenterRef center, void* observer, CFStringRef name, const void* object, CFDictionaryRef userInfo)
{
	@autoreleasepool {
		NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.cosmosgenius.screendump"];
		isEnabled = [[defaults objectForKey:@"CCSisEnabled"]?:@NO boolValue];
	}
}

%ctor
{
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, screenDisplayStatus, CFSTR("com.apple.iokit.hid.displayStatus"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, loadPrefs, CFSTR("com.cosmosgenius.screendump/preferences.changed"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	
	loadPrefs(NULL, NULL, NULL, NULL, NULL);
}