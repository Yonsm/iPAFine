

#import <Cocoa/Cocoa.h>

//
@interface iPAFine : NSObject
{
@private
	NSString *_error;
}

- (NSString *)refine:(NSString *)ipaPath dylibPath:(NSString *)dylibPath certName:(NSString *)certName provPath:(NSString *)provPath;

- (void)injectMachO:(NSString *)exePath dylibPath:(NSString *)dylibPath;

@end
