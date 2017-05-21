

#import <Cocoa/Cocoa.h>

//
@interface iPAFine : NSObject
{
	NSString *_error;
}

- (NSString *)refine:(NSString *)ipaPath dylibPath:(NSString *)dylibPath certName:(NSString *)certName provPath:(NSString *)provPath;

@end
