

#import "iPAFine.h"

//
@interface AppDelegate : iPAFine <NSApplicationDelegate, NSTextFieldDelegate>
{
	NSWindow *window;
	
	NSUserDefaults *defaults;

	IBOutlet NSTextField *pathField;
	IBOutlet NSTextField *provField;
	IBOutlet NSTextField *certField;
	IBOutlet NSTextField *dylibField;

	IBOutlet NSButton	*browseButton;
	IBOutlet NSButton	*browseProvButton;
	IBOutlet NSButton	*resignButton;
	IBOutlet NSTextField *statusLabel;
	IBOutlet NSProgressIndicator *flurry;
}

@property (assign) IBOutlet NSWindow *window;

- (IBAction)resign:(id)sender;

@end
