

#import "AppDelegate.h"
#import "iPAFine.h"

@implementation AppDelegate
@synthesize window;

//
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
	return YES;
}

//
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[flurry setAlphaValue:0.5];
	defaults = [NSUserDefaults standardUserDefaults];
	
	if ([defaults valueForKey:@"IPA_PATH"])
		[pathField setStringValue:[defaults valueForKey:@"IPA_PATH"]];
	if ([defaults valueForKey:@"DYLIB_PATH"])
		[dylibField setStringValue:[defaults valueForKey:@"DYLIB_PATH"]];
	if ([defaults valueForKey:@"CERT_NAME"])
		[certField setStringValue:[defaults valueForKey:@"CERT_NAME"]];
	if ([defaults valueForKey:@"MOBILEPROVISION_PATH"])
		[provField setStringValue:[defaults valueForKey:@"MOBILEPROVISION_PATH"]];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/zip"])
	{
		NSRunAlertPanel(@"Error",
						@"This app cannot run without the zip utility present at /usr/bin/zip",
						@"OK",nil,nil);
		exit(0);
	}
	if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/unzip"])
	{
		NSRunAlertPanel(@"Error",
						@"This app cannot run without the unzip utility present at /usr/bin/unzip",
						@"OK",nil,nil);
		exit(0);
	}
	if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/codesign"])
	{
		NSRunAlertPanel(@"Error",
						@"This app cannot run without the codesign utility present at /usr/bin/codesign",
						@"OK",nil, nil);
		exit(0);
	}
}

//
- (IBAction)browse:(id)sender
{
	NSOpenPanel* openDlg = [NSOpenPanel openPanel];
	
	[openDlg setCanChooseFiles:TRUE];
	[openDlg setCanChooseDirectories:TRUE];
	[openDlg setAllowsMultipleSelection:FALSE];
	[openDlg setAllowsOtherFileTypes:FALSE];
	
	if ( [openDlg runModalForTypes:@[@"ipa", @"dylib"]] == NSOKButton )
	{
		NSString* fileNameOpened = [[openDlg filenames] objectAtIndex:0];
		[pathField setStringValue:fileNameOpened];
	}
}

//
- (IBAction)browseProv:(id)sender
{
	NSOpenPanel* openDlg = [NSOpenPanel openPanel];
	
	[openDlg setCanChooseFiles:TRUE];
	[openDlg setCanChooseDirectories:FALSE];
	[openDlg setAllowsMultipleSelection:FALSE];
	[openDlg setAllowsOtherFileTypes:FALSE];
	
	if ( [openDlg runModalForTypes:[NSArray arrayWithObject:@"mobileprovision"]] == NSOKButton )
	{
		NSString* fileNameOpened = [[openDlg filenames] objectAtIndex:0];
		[provField setStringValue:fileNameOpened];
	}
}

//
- (IBAction)browseDylib:(id)sender
{
	NSOpenPanel* openDlg = [NSOpenPanel openPanel];
	
	[openDlg setCanChooseFiles:TRUE];
	[openDlg setCanChooseDirectories:FALSE];
	[openDlg setAllowsMultipleSelection:FALSE];
	[openDlg setAllowsOtherFileTypes:FALSE];
	
	if ( [openDlg runModalForTypes:[NSArray arrayWithObject:@"dylib"]] == NSOKButton )
	{
		NSString* fileNameOpened = [[openDlg filenames] objectAtIndex:0];
		[dylibField setStringValue:fileNameOpened];
	}
}

//
- (IBAction)showHelp:(id)sender
{
	NSRunAlertPanel(@"How to use iReSign",
					@"iReSign allows you to re-sign any unencrypted ipa-file with any certificate for which you hold the corresponding private key.\n\n1. Drag your unsigned .ipa file to the top box, or use the browse button.\n\n2. Enter your full certificate name from Keychain Access, for example \"iPhone Developer: Firstname Lastname (XXXXXXXXXX)\" in the bottom box.\n\n3. Click ReSign! and wait. The resigned file will be saved in the same folder as the original file.",
					@"OK",nil, nil);
}

//
- (IBAction)resign:(id)sender
{
	[defaults setValue:[pathField stringValue] forKey:@"IPA_PATH"];
	[defaults setValue:[dylibField stringValue] forKey:@"DYLIB_PATH"];
	[defaults setValue:[certField stringValue] forKey:@"CERT_NAME"];
	[defaults setValue:[provField stringValue] forKey:@"MOBILEPROVISION_PATH"];
	[defaults synchronize];
	
	[pathField setEnabled:FALSE];
	[certField setEnabled:FALSE];
	[browseButton setEnabled:FALSE];
	[resignButton setEnabled:FALSE];
	
	[flurry startAnimation:self];
	
	[self performSelectorInBackground:@selector(resignThread) withObject:nil];
}

//
- (void)resignThread
{
	@autoreleasepool
	{
		NSString *error = [[[iPAFine alloc] init] refine:pathField.stringValue
											   dylibPath:dylibField.stringValue
												certName:certField.stringValue
												provPath:provField.stringValue];
		[self performSelectorOnMainThread:@selector(resignDone:) withObject:error waitUntilDone:YES];
	}
}

//
- (void)resignDone:(NSString *)error
{
	[pathField setEnabled:TRUE];
	[certField setEnabled:TRUE];
	[browseButton setEnabled:TRUE];
	[resignButton setEnabled:TRUE];
	
	[flurry stopAnimation:self];
	
	if (error)
	{
		NSRunAlertPanel(@"Error", error, @"OK",nil, nil);
	}
}

@end
