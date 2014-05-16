

#import "iPAFine.h"

//
@interface AppDelegate : iPAFine <NSApplicationDelegate, NSTextFieldDelegate>
{
	NSWindow *window;
	
	NSUserDefaults *defaults;

	IBOutlet NSTextField *pathField;
	IBOutlet NSTextField *provisioningPathField;
	IBOutlet NSTextField *certField;

	IBOutlet NSButton	*browseButton;
	IBOutlet NSButton	*provisioningBrowseButton;
	IBOutlet NSButton	*resignButton;
	IBOutlet NSTextField *statusLabel;
	IBOutlet NSProgressIndicator *flurry;
}

@property (assign) IBOutlet NSWindow *window;

- (IBAction)resign:(id)sender;

@end
