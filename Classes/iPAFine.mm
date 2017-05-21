

#import "iPAFine.h"
#include <mach-o/loader.h>
#include <mach-o/fat.h>

@implementation iPAFine

//
- (NSString *)doTask:(NSString *)path arguments:(NSArray *)arguments currentDirectory:(NSString *)currentDirectory
{
	NSTask *task = [[NSTask alloc] init];
	task.launchPath = path;
	task.arguments = arguments;
	if (currentDirectory) task.currentDirectoryPath = currentDirectory;
	
	NSPipe *pipe = [NSPipe pipe];
	task.standardOutput = pipe;
	task.standardError = pipe;
	
	NSFileHandle *file = [pipe fileHandleForReading];
	
	[task launch];
	
	NSData *data = [file readDataToEndOfFile];
	NSString *result = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
	
	//NSLog(@"CMD:\n%@\n%@ARG\n\n%@\n\n", path, arguments, (result ? result : @""));
	return result;
}


//
- (NSString *)doTask:(NSString *)path arguments:(NSArray *)arguments
{
	return [self doTask:path arguments:arguments currentDirectory:nil];
}

//
- (NSString *)unzipIPA:(NSString *)ipaPath workPath:(NSString *)workPath
{
	NSString *result = [self doTask:@"/usr/bin/unzip" arguments:[NSArray arrayWithObjects:@"-q", ipaPath, @"-d", workPath, nil]];
	NSString *payloadPath = [workPath stringByAppendingPathComponent:@"Payload"];
	if ([[NSFileManager defaultManager] fileExistsAtPath:payloadPath])
	{
		NSArray *dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadPath error:nil];
		for (NSString *dir in dirs)
		{
			if ([dir.pathExtension.lowercaseString isEqualToString:@"app"])
			{
				return [payloadPath stringByAppendingPathComponent:dir];
			}
		}
		_error = @"Invalid app";
		return nil;
	}
	_error = [@"Unzip failed:" stringByAppendingString:result ? result : @""];
	return nil;
}

- (uint32_t)bigEndianToSmallEndian:(uint32_t)bigEndian
{
	uint32_t smallEndian = 0;
	unsigned char *small = (unsigned char *)&smallEndian;
	unsigned char *big = (unsigned char *)&bigEndian;
	for (int i=0; i<4; i++)
	{
		small[i] = big[3-i];
	}
	return smallEndian;
}

//
- (void)stripApp:(NSString *)appPath
{
	// Find executable
	NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
	NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath];
	NSString *exeName = [info objectForKey:@"CFBundleExecutable"];
	if (exeName == nil)
	{
		_error = @"Strip failed: No CFBundleExecutable";
		return;
	}
	NSString *exePath = [appPath stringByAppendingPathComponent:exeName];
	
	NSString *result = [self doTask:@"/usr/bin/lipo" arguments:[NSArray arrayWithObjects:@"-info", exePath, nil]];
	
	if (([result rangeOfString:@"armv6 armv7"].location == NSNotFound) && ([result rangeOfString:@"armv7 armv6"].location == NSNotFound))
	{
		return;
	}
	
	NSString *newPath = [exePath stringByAppendingString:@"NEW"];
	result = [self doTask:@"/usr/bin/lipo" arguments:[NSArray arrayWithObjects:@"-remove", @"armv6", @"-output", newPath, exePath, nil]];
	if (result.length)
	{
		_error = [@"Strip failed:" stringByAppendingString:result];
	}
	
	NSError *error = nil;
	BOOL ret = [[NSFileManager defaultManager] removeItemAtPath:exePath error:&error] && [[NSFileManager defaultManager] moveItemAtPath:newPath toPath:exePath error:&error];
	if (!ret)
	{
		_error = [@"Strip failed:" stringByAppendingString:error.localizedDescription];
	}
}

//
- (NSString *)renameApp:(NSString *)appPath ipaPath:(NSString *)ipaPath
{
	// 获取显示名称
	NSString *DISPNAME = ipaPath.lastPathComponent.stringByDeletingPathExtension;
	
	if ([DISPNAME hasPrefix:@"iOS."]) DISPNAME = [DISPNAME substringFromIndex:4];
	else if ([DISPNAME hasPrefix:@"iPad."]) DISPNAME = [DISPNAME substringFromIndex:5];
	else if ([DISPNAME hasPrefix:@"iPhone."]) DISPNAME = [DISPNAME substringFromIndex:7];
	
	NSRange range = [DISPNAME rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"_- .（(["]];
	if (range.location != NSNotFound)
	{
		DISPNAME = [DISPNAME substringToIndex:range.location];
	}
	
	if ([DISPNAME hasSuffix:@"HD"]) DISPNAME = [DISPNAME substringToIndex:DISPNAME.length - 2];
	
	//
	NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
	NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath];
	
	// 获取程序类型
	NSArray *devices = [info objectForKey:@"UIDeviceFamily"];
	NSUInteger family = 0;
	for (id device in devices) family += [device intValue];
	NSString *PREFIX = (family == 3) ? @"iOS" : ((family == 2) ? @"iPad" : @"iPhone");
	
	// 修改显示名称
	[info setObject:DISPNAME forKey:@"CFBundleDisplayName"];
	[info writeToFile:infoPath atomically:YES];
	
	static const NSString *langs[] = {@"zh-Hans", @"zh_Hans", @"zh_CN", @"zh-CN", @"zh"};
	for (NSUInteger i = 0; i < sizeof(langs) / sizeof(langs[0]); i++)
	{
		NSString *localizePath = [appPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.lproj/InfoPlist.strings", langs[i]]];
		if ([[NSFileManager defaultManager] fileExistsAtPath:localizePath])
		{
			NSMutableDictionary *localize = [NSMutableDictionary dictionaryWithContentsOfFile:localizePath];
			[localize removeObjectForKey:@"CFBundleDisplayName"];
			[localize writeToFile:localizePath atomically:YES];
		}
	}
	
	// 修改 iTunes 项目名称
	NSString *metaPath = [[[appPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"iTunesMetadata.plist"];
	NSMutableDictionary *meta = [NSMutableDictionary dictionaryWithContentsOfFile:metaPath];
	if (meta == nil) meta = [NSMutableDictionary dictionary];
	{
		[meta setObject:DISPNAME forKey:@"playlistName"];
		[meta setObject:DISPNAME forKey:@"itemName"];
		[meta writeToFile:metaPath atomically:YES];
	}
	
	//
	/*NSString *VERSION = meta ? [meta objectForKey:@"bundleShortVersionString"] : nil;
	 if (VERSION.length == 0) VERSION = [info objectForKey:@"CFBundleVersion"];
	 if (VERSION.length == 0) VERSION = [info objectForKey:@"CFBundleShortVersionString"];*/
	
	return [NSString stringWithFormat:@"%@/%@.%@.ipa", ipaPath.stringByDeletingLastPathComponent, PREFIX, DISPNAME/*, VERSION*/];
}

//
- (void)checkProv:(NSString *)appPath provPath:(NSString *)provPath
{
	// Check
	NSString *embeddedProvisioning = [NSString stringWithContentsOfFile:provPath encoding:NSASCIIStringEncoding error:nil];
	NSArray* embeddedProvisioningLines = [embeddedProvisioning componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	for (int i = 0; i <= [embeddedProvisioningLines count]; i++)
	{
		if ([[embeddedProvisioningLines objectAtIndex:i] rangeOfString:@"application-identifier"].location != NSNotFound)
		{
			NSInteger fromPosition = [[embeddedProvisioningLines objectAtIndex:i+1] rangeOfString:@"<string>"].location + 8;
			NSInteger toPosition = [[embeddedProvisioningLines objectAtIndex:i+1] rangeOfString:@"</string>"].location;
			
			NSRange range;
			range.location = fromPosition;
			range.length = toPosition - fromPosition;
			
			NSString *identifier = [[embeddedProvisioningLines objectAtIndex:i+1] substringWithRange:range];
			if (![identifier hasSuffix:@".*"])
			{
				NSRange range = [identifier rangeOfString:@"."];
				if (range.location != NSNotFound) identifier = [identifier substringFromIndex:range.location + 1];
				
				NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingPathComponent:@"Info.plist"]];
				if (![[info objectForKey:@"CFBundleIdentifier"] isEqualToString:identifier])
				{
					_error = @"Identifiers match";
					return;
				}
			}
			return;
		}
	}
	_error = @"Invalid prov";
}

//
- (void)injectArchitecture:(int)fd dylibPath:(NSString *)dylibPath exePath:(NSString *)exePathForInfoOnly
{
	off_t archPoint = lseek(fd, 0, SEEK_CUR);
	struct mach_header header;
	read(fd, &header, sizeof(header));
	if (header.magic != MH_MAGIC && header.magic != MH_MAGIC_64)
	{
		_error = [NSString stringWithFormat:@"Inject failed: Invalid executable %@", exePathForInfoOnly];
	}
	else
	{
		if (header.magic == MH_MAGIC_64)
		{
			int delta = sizeof(mach_header_64) - sizeof(mach_header);
			lseek(fd, delta, SEEK_CUR);
		}
		
		char *buffer = (char *)malloc(header.sizeofcmds + 2048);
		read(fd, buffer, header.sizeofcmds);
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:dylibPath])
		{
			dylibPath = [@"@executable_path" stringByAppendingPathComponent:[dylibPath lastPathComponent]];
		}
		const char *dylib = dylibPath.UTF8String;
		struct dylib_command *p = (struct dylib_command *)buffer;
		struct dylib_command *last = NULL;
		for (uint32_t i = 0; i < header.ncmds; i++, p = (struct dylib_command *)((char *)p + p->cmdsize))
		{
			if (p->cmd == LC_LOAD_DYLIB || p->cmd == LC_LOAD_WEAK_DYLIB)
			{
				char *name = (char *)p + p->dylib.name.offset;
				if (strcmp(dylib, name) == 0)
				{
					NSLog(@"Already Injected: %@ with %s", exePathForInfoOnly, dylib);
					close(fd);
					return;
				}
				last = p;
			}
		}
		
		if ((char *)p - buffer != header.sizeofcmds)
		{
			NSLog(@"LC payload not mismatch: %@", exePathForInfoOnly);
		}
		
		if (last)
		{
			struct dylib_command *inject = (struct dylib_command *)((char *)last + last->cmdsize);
			char *movefrom = (char *)inject;
			uint32_t cmdsize = sizeof(*inject) + (uint32_t)strlen(dylib) + 1;
			cmdsize = (cmdsize + 0x10) & 0xFFFFFFF0;
			char *moveout = (char *)inject + cmdsize;
			for (int i = (int)(header.sizeofcmds - (movefrom - buffer) - 1); i >= 0; i--)
			{
				moveout[i] = movefrom[i];
			}
			memset(inject, 0, cmdsize);
			inject->cmd = LC_LOAD_DYLIB;
			inject->cmdsize = cmdsize;
			inject->dylib.name.offset = sizeof(dylib_command);
			inject->dylib.timestamp = 2;
			inject->dylib.current_version = 0x00010000;
			inject->dylib.compatibility_version = 0x00010000;
			strcpy((char *)inject + inject->dylib.name.offset, dylib);
			
			header.ncmds++;
			header.sizeofcmds += inject->cmdsize;
			lseek(fd, archPoint, SEEK_SET);
			write(fd, &header, sizeof(header));
			
			lseek(fd, archPoint + ((header.magic == MH_MAGIC_64) ? sizeof(mach_header_64) : sizeof(mach_header)), SEEK_SET);
			write(fd, buffer, header.sizeofcmds);
		}
		else
		{
			_error = [NSString stringWithFormat:@"Inject failed: No valid LC_LOAD_DYLIB %@", exePathForInfoOnly];
		}
		
		free(buffer);
	}
}

//
- (void)injectMachO:(NSString *)exePath dylibPath:(NSString *)dylibPath
{
	int fd = open(exePath.UTF8String, O_RDWR, 0777);
	if (fd < 0)
	{
		_error = [NSString stringWithFormat:@"Inject failed: failed to open %@", exePath];
		return;
	}
	else
	{
		uint32_t magic;
		read(fd, &magic, sizeof(magic));
		if (magic == MH_MAGIC || magic == MH_MAGIC_64)
		{
			lseek(fd, 0, SEEK_SET);
			[self injectArchitecture:fd dylibPath:dylibPath exePath:exePath];
		}
		else if (magic == FAT_MAGIC || magic == FAT_CIGAM)
		{
			struct fat_header header;
			lseek(fd, 0, SEEK_SET);
			read(fd, &header, sizeof(fat_header));
			int nArch = header.nfat_arch;
			if (magic == FAT_CIGAM) nArch = [self bigEndianToSmallEndian:header.nfat_arch];
			
			struct fat_arch arch;
			NSMutableArray *offsetArray = [NSMutableArray array];
			for (int i = 0; i < nArch; i++)
			{
				memset(&arch, 0, sizeof(fat_arch));
				read(fd, &arch, sizeof(fat_arch));
				int offset = arch.offset;
				if (magic == FAT_CIGAM) offset = [self bigEndianToSmallEndian:arch.offset];
				[offsetArray addObject:[NSNumber numberWithUnsignedInt:offset]];
			}
			
			for (NSNumber *offsetNum in offsetArray)
			{
				lseek(fd, [offsetNum unsignedIntValue], SEEK_SET);
				[self injectArchitecture:fd dylibPath:dylibPath exePath:exePath];
				//				if (_error)
				//					break;
			}
		}
		
		close(fd);
	}
}

//
- (void)injectApp:(NSString *)appPath dylibPath:(NSString *)dylibPath
{
	if (dylibPath.length)
	{
		if ([[NSFileManager defaultManager] fileExistsAtPath:dylibPath])
		{
			NSString *targetPath = [appPath stringByAppendingPathComponent:[dylibPath lastPathComponent]];
			if ([[NSFileManager defaultManager] fileExistsAtPath:targetPath])
			{
				[[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
			}
			
			NSString *result = [self doTask:@"/bin/cp" arguments:[NSArray arrayWithObjects:dylibPath, targetPath, nil]];
			if (![[NSFileManager defaultManager] fileExistsAtPath:targetPath])
			{
				_error = [@"Failed to copy dylib file: " stringByAppendingString:result ? result : @""];
			}
		}
		
		// Find executable
		NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
		NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath];
		NSString *exeName = [info objectForKey:@"CFBundleExecutable"];
		if (exeName == nil)
		{
			_error = [NSString stringWithFormat:@"Inject failed: No CFBundleExecutable on %@", infoPath];
			return;
		}
		NSString *exePath = [appPath stringByAppendingPathComponent:exeName];
		[self injectMachO:exePath dylibPath:dylibPath];
	}
}

//
- (void)provApp:(NSString *)appPath provPath:(NSString *)provPath
{
	NSString *targetPath = [appPath stringByAppendingPathComponent:@"embedded.mobileprovision"];
	if ([[NSFileManager defaultManager] fileExistsAtPath:targetPath])
	{
		//NSLog(@"Found embedded.mobileprovision, deleting.");
		[[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
	}
	
	if (provPath.length)
	{
		NSString *result = [self doTask:@"/bin/cp" arguments:[NSArray arrayWithObjects:provPath, targetPath, nil]];
		if (![[NSFileManager defaultManager] fileExistsAtPath:targetPath])
		{
			_error = [@"Failed to copy provisioning file: " stringByAppendingString:result ?: @""];
		}
	}
}

//
- (void)signApp:(NSString *)appPath certName:(NSString *)certName
{
	if (certName.length)
	{
		BOOL isDir;
		if ([[NSFileManager defaultManager] fileExistsAtPath:appPath isDirectory:&isDir] && isDir)
		{
			// 生成 application-identifier entitlements
			NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
			NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
			NSString *bundleID = info[@"CFBundleIdentifier"];
			
			//security find-certificate -c "iPhone Developer: Qian Wu (V569CJEC8A)" | grep \"subj\"\<blob\> | grep "\\\\0230\\\\021\\\\006\\\\003U\\\\004\\\\013\\\\014\\\\012" | sed 's/.*\\0230\\021\\006\\003U\\004\\013\\014\\012\(.\{10\}\).*/\1/'
			NSString *entitlementsPath = nil;
			NSString *certInfo = [self doTask:@"/usr/bin/security" arguments:@[@"find-certificate", @"-c", certName]];
			NSRange range = [certInfo rangeOfString:@"\\0230\\021\\006\\003U\\004\\013\\014\\012"];
			if (range.location != NSNotFound)
			{
				range.location += range.length;
				range.length = 10;
				NSString *teamID = [certInfo substringWithRange:range];
				if (teamID)
				{
					NSDictionary *dict = @{@"application-identifier":[NSString stringWithFormat:@"%@.%@", teamID, bundleID],
										   @"com.apple.developer.team-identifier":teamID};
					entitlementsPath = [appPath.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent stringByAppendingFormat:@"/%@.xcent", bundleID];
					[dict writeToFile:entitlementsPath atomically:YES];
				}
			}
			
			//
			NSString *result1 = [self doTask:@"/usr/bin/codesign" arguments:[NSArray arrayWithObjects:@"-fs", certName, appPath, (entitlementsPath ? @"--entitlements" : nil), entitlementsPath, nil]];
			if ([result1 rangeOfString:@"replacing existing signature"].location == NSNotFound)
			{
				NSString *result2 = [self doTask:@"/usr/bin/codesign" arguments:[NSArray arrayWithObjects:@"-v", appPath, nil]];
				if (result2.length)
				{
					NSString *resourceRulesPath = [[NSBundle mainBundle] pathForResource:@"ResourceRules" ofType:@"plist"];
					NSString *resourceRulesArgument = [NSString stringWithFormat:@"--resource-rules=%@",resourceRulesPath];
					NSString *result3 = [self doTask:@"/usr/bin/codesign" arguments:[NSArray arrayWithObjects:@"-fs", certName, resourceRulesArgument, (entitlementsPath ? @"--entitlements" : nil), entitlementsPath, appPath, nil]];
					if ([result3 rangeOfString:@"replacing existing signature"].location == NSNotFound)
					{
						NSString *result4 = [self doTask:@"/usr/bin/codesign" arguments:[NSArray arrayWithObjects:@"-v", appPath, nil]];
						if (result4.length)
						{
							_error = [NSString stringWithFormat:@"Failed to sign %@\n\n%@\n\n%@\n\n%@\n\n%@", appPath, result1, result2, result3, result4];
						}
					}
				}
				if (!_error)
				{
					[[NSFileManager defaultManager] removeItemAtPath:entitlementsPath error:nil];
				}
			}
		}
		else
		{
			NSString *result1 = [self doTask:@"/usr/bin/codesign" arguments:[NSArray arrayWithObjects:@"-fs", certName, appPath, nil]];
			if ([result1 rangeOfString:@"replacing existing signature"].location == NSNotFound)
			{
				NSString *result2 = [self doTask:@"/usr/bin/codesign" arguments:[NSArray arrayWithObjects:@"-v", appPath, nil]];
				if (result2.length)
				{
					_error = [NSString stringWithFormat:@"Failed to sign %@\n\n%@\n\n%@", appPath, result1, result2];
				}
			}
		}
	}
}

- (void)zipIPA:(NSString *)workPath outPath:(NSString *)outPath
{
	//TODO: Current Dir Error
	/*NSString *result = */[self doTask:@"/usr/bin/zip" arguments:[NSArray arrayWithObjects:@"-qr", outPath, @".", nil] currentDirectory:workPath];
	[[NSFileManager defaultManager] removeItemAtPath:workPath error:nil];
}

//
- (void)refineIPA:(NSString *)ipaPath dylibPath:(NSString *)dylibPath certName:(NSString *)certName provPath:(NSString *)provPath
{
	//
	NSString *workPath = ipaPath.stringByDeletingPathExtension;//[NSTemporaryDirectory() stringByAppendingPathComponent:@"CeleWare.iPAFine"];
	
	//NSLog(@"Setting up working directory in %@",workPath);
	[[NSFileManager defaultManager] removeItemAtPath:workPath error:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:workPath withIntermediateDirectories:TRUE attributes:nil error:nil];
	
	// Unzip
	_error = nil;
	NSString *appPath = [self unzipIPA:ipaPath workPath:workPath];
	if (_error) return;
	
	// Strip
	//[self stripApp:appPath];
	//if (_error) return;
	
	// Rename
	NSString *outPath = [self renameApp:appPath ipaPath:ipaPath];
	
	// Provision
	[self injectApp:appPath dylibPath:dylibPath];
	if (_error) return;
	
	// Provision
	[self provApp:appPath provPath:provPath];
	if (_error) return;
	
	// Sign
	[self signApp:appPath certName:certName];
	if (_error) return;
	
	// Remove origin
	[[NSFileManager defaultManager] removeItemAtPath:ipaPath error:nil];
	
	// Zip
	[self zipIPA:workPath outPath:outPath];
}

//
- (NSString *)refine:(NSString *)ipaPath dylibPath:(NSString *)dylibPath certName:(NSString *)certName provPath:(NSString *)provPath
{
	_error = nil;
	
	if (dylibPath.length && [[NSFileManager defaultManager] fileExistsAtPath:dylibPath])
	{
		[self signApp:dylibPath certName:certName];
		if (_error) return _error;
	}
	
	BOOL isDir = NO;
	if ([[NSFileManager defaultManager] fileExistsAtPath:ipaPath isDirectory:&isDir])
	{
		if (isDir)
		{
			NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:ipaPath error:nil];
			for (NSString *file in files)
			{
				if ([file.pathExtension.lowercaseString isEqualToString:@"ipa"])
				{
					[self refineIPA:[ipaPath stringByAppendingPathComponent:file] dylibPath:dylibPath certName:certName provPath:provPath];
				}
			}
		}
		else if ([ipaPath.pathExtension.lowercaseString isEqualToString:@"ipa"])
		{
			[self refineIPA:ipaPath dylibPath:dylibPath certName:certName provPath:provPath];
		}
		else
		{
			if (dylibPath.length)
			{
				[self injectMachO:ipaPath dylibPath:dylibPath];
				if (_error == nil) return nil;
			}
			_error = NSLocalizedString(@"You must choose an IPA file.", @"必须选择 IPA 或 Mach-O 文件。");
		}
	}
	else
	{
		_error = @"Path not found";
	}
	return _error;
}

@end
