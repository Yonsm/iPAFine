

#import <Cocoa/Cocoa.h>

//
@interface AppDelegate : NSObject <NSApplicationDelegate, NSTextFieldDelegate>
{
	NSUserDefaults *defaults;

	IBOutlet NSTextField *pathField;
	IBOutlet NSTextField *provField;
	IBOutlet NSTextField *certField;
	IBOutlet NSTextField *dylibField;

	IBOutlet NSButton	*browseButton;
	IBOutlet NSButton	*browseProvButton;
	IBOutlet NSButton	*resignButton;
	IBOutlet NSProgressIndicator *flurry;
}

@property (assign) IBOutlet NSWindow *window;

- (IBAction)resign:(id)sender;

@end
