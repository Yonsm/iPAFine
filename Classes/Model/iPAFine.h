

#import <Cocoa/Cocoa.h>

//
@interface iPAFine : NSObject
{
@private
	NSString *_error;
}

- (NSString *)refine:(NSString *)ipaPath certName:(NSString *)certName provPath:(NSString *)provPath;

@end
