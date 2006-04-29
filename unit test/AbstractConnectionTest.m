//
//  AbstractConnectionTest.m
//  Connection
//
//  Created by olivier on 4/23/06.
//  Copyright 2006 Olivier Destrebecq. All rights reserved.
//

#import "AbstractConnectionTest.h"
 
@interface AbstractConnectionTest (Private)

- (void) checkThatFileExistsAtPath: (NSString*) inPath;
- (void) checkThatFileDoesNotExistsAtPath: (NSString*) inPath;

@end

@implementation AbstractConnectionTest

- (NSString *)connectionName
{
	return @"AbstractConnection";
}

- (NSString *)host
{
	return @"localhost";
}

- (NSString *)port
{
	return nil;
}

- (NSString *)username
{
	return NSUserName();
}

- (NSString *)password
{
	return [AbstractConnectionTest keychainPasswordForServer:[self host] account:[self username]];
}

- (void) setUp
{
	//set info for your ftp server here
	//	
	fileNameExistingOnServer = @"unit test/09 moustik.mp3"; 
	
	initialDirectory = NSHomeDirectory();
	NSError *err = nil;
	connection = [[AbstractConnection connectionWithName: [self connectionName]
													host: [self host]
													port: [self port]
												username: [self username]
												password: [self password]
												   error: &err] retain];
	if (!connection)
	{
		if (err)
		{
			NSLog(@"%@", err);
		}
	}
	[connection setDelegate: self];
	
	didUpload = isConnected = receivedError = NO;
}

- (unsigned int)testCaseCount {
  unsigned int count = 0;
  
  if ([self isMemberOfClass:[AbstractConnectionTest class]] == NO) {
    count = [super testCaseCount];
  }
  
  return count;
}

- (void)performTest:(SenTestRun *)testRun {
  if ([self isMemberOfClass: [AbstractConnectionTest class]] == NO) 
  {
    [super performTest:testRun];
  }
}

+ (NSString *)keychainPasswordForServer:(NSString *)aServerName account:(NSString *)anAccountName
{
	NSString *result = nil;
	if ([aServerName length] > 255 || [anAccountName length] > 255)
	{
		return result;
	}
	
	Str255 serverPString, accountPString;
	
	c2pstrcpy(serverPString, [aServerName UTF8String]);
	c2pstrcpy(accountPString, [anAccountName UTF8String]);
	
	char passwordBuffer[256];
	UInt32 actualLength;
	OSStatus theStatus;
	
	theStatus = KCFindInternetPassword (
                                      serverPString,			// StringPtr serverName,
                                      NULL,					// StringPtr securityDomain,
                                      accountPString,		// StringPtr accountName,
                                      kAnyPort,				// UInt16 port,
                                      kAnyProtocol,			// OSType protocol,
                                      kAnyAuthType,			// OSType authType,
                                      255,					// UInt32 maxLength,
                                      passwordBuffer,		// void * passwordData,
                                      &actualLength,			// UInt32 * actualLength,
                                      nil					// KCItemRef * item
                                      );
	if (noErr == theStatus)
	{
		passwordBuffer[actualLength] = 0;		// make it a legal C string by appending 0
		result = [NSString stringWithUTF8String:passwordBuffer];
	}
	return result;
}

- (void) testFileExitence
{
	NSDictionary *env = [[NSProcessInfo processInfo] environment];
	NSString *file = [[env objectForKey:@"SRCROOT"] stringByAppendingPathComponent: fileNameExistingOnServer];
	[self checkThatFileExistsAtPath: file];  
}

- (void) testFileNonExistence
{
	NSDictionary *env = [[NSProcessInfo processInfo] environment];
	NSString *file = [[env objectForKey:@"SRCROOT"] stringByAppendingPathComponent: @"Windows95 was the best OS ever.txt"];
	[self checkThatFileDoesNotExistsAtPath:file];
}

- (void) testGetSetPermission
{
  [connection connect];
  
  NSDate *initialTime = [NSDate date];
  while ((!isConnected) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  //get the directory content to save the permission
  //
  receivedError = NO;  
  [connection directoryContents];
  
  initialTime = [NSDate date];
  while ((!directoryContents) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  STAssertFalse (receivedError, @"received error on get directory content");
  STAssertTrue(([initialTime timeIntervalSinceNow] > -15), @"timed out on directory content");
  STAssertNotNil (directoryContents, @"did not receive directory content");
  
  NSEnumerator *theDirectoryEnum = [directoryContents objectEnumerator];
  NSDictionary *currentFile;
  int savedPermission;
  while (currentFile = [theDirectoryEnum nextObject])
  {
    if ([[currentFile objectForKey: @"cxFilenameKey"] isEqualToString: fileNameExistingOnServer])
    {
      savedPermission = [[currentFile objectForKey: @"NSFilePosixPermissions"] intValue];
      
      break;
    }
  }
  
  //now actually set the permission
  //
  receivedError = NO;
  [connection setPermissions:0660 forFile: fileNameExistingOnServer]; //read write by owner and group only
  
  
  initialTime = [NSDate date];
  while ((!didSetPermission) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  STAssertFalse (receivedError, @"received error on set permission");
  STAssertTrue(([initialTime timeIntervalSinceNow] > -15), @"timed out on set permission");
  STAssertTrue (didSetPermission, @"did not set the permission");
  
  
  //now check that the permission are set
  //
  receivedError = NO;  
  directoryContents = nil;
  [connection directoryContents];
  
  initialTime = [NSDate date];
  while ((!directoryContents) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  STAssertFalse (receivedError, @"received error on get directory content");
  STAssertTrue(([initialTime timeIntervalSinceNow] > -15), @"timed out on directory content");
  STAssertNotNil (directoryContents, @"did not receive directory content");
  
  theDirectoryEnum = [directoryContents objectEnumerator];
  while (currentFile = [theDirectoryEnum nextObject])
  {
    if ([[currentFile objectForKey: @"cxFilenameKey"] isEqualToString: fileNameExistingOnServer])
    {
      STAssertEquals(0600, [[currentFile objectForKey: @"NSFilePosixPermissions"] intValue], @"did not set the remote permission");
      
      break;
    }
  }
  
  //set the permission back, don't care about the result that much
  //
  receivedError = NO;
  [connection setPermissions: savedPermission forFile: fileNameExistingOnServer]; //read write by owner only
  
  
  initialTime = [NSDate date];
  while ((!didSetPermission) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
}

- (void) testUpload
{
  [connection connect];
  
  NSDate *initialTime = [NSDate date];
  while ((!isConnected) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  NSDictionary *env = [[NSProcessInfo processInfo] environment];
  [connection uploadFile: [[env objectForKey:@"SRCROOT"] stringByAppendingPathComponent: fileNameExistingOnServer]];
  
  didUpload = receivedError = NO;
  initialTime = [NSDate date];
  while ((!didUpload) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  STAssertFalse(receivedError, @"received error on upload");
  STAssertTrue(([initialTime timeIntervalSinceNow] > -15), @"timeout on upload");
  
  //check that the file exists (using the connectino framework, so maybe not the best check, but at least will work with every connection
  //
  [self checkThatFileExistsAtPath: [fileNameExistingOnServer lastPathComponent]];
  
  //clean up
  //
  [connection deleteFile: [fileNameExistingOnServer lastPathComponent]];
  
  didDelete = receivedError = NO;
  initialTime = [NSDate date];
  while ((!didDelete) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  //check that the file was removed
  //
  [self checkThatFileDoesNotExistsAtPath: [fileNameExistingOnServer lastPathComponent]];
  
}

- (void) testUploadToFileAndDelete
{
  [connection connect];
  
  NSDate *initialTime = [NSDate date];
  while ((!isConnected) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  NSDictionary *env = [[NSProcessInfo processInfo] environment];
  [connection uploadFile:[[env objectForKey:@"SRCROOT"] stringByAppendingPathComponent: fileNameExistingOnServer] 
				  toFile:[fileNameExistingOnServer lastPathComponent]];
  
  didUpload = receivedError = NO;
  initialTime = [NSDate date];
  while ((!didUpload) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  STAssertFalse(receivedError, @"received error on upload");
  STAssertTrue(([initialTime timeIntervalSinceNow] > -15), @"timeout on upload");
  
  //check that the file exists (using the connectino framework, so maybe not the best check, but at least will work with every connection
  //
  [self checkThatFileExistsAtPath: [fileNameExistingOnServer lastPathComponent]];
  
  //clean up
  //
  [connection deleteFile: [fileNameExistingOnServer lastPathComponent]];
  
  didDelete = receivedError = NO;
  initialTime = [NSDate date];
  while ((!didDelete) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];

  //Check that the file was removed
  //
  [self checkThatFileDoesNotExistsAtPath: [fileNameExistingOnServer lastPathComponent]];
}

- (void) testUploadMultipleFiles
{
  [connection connect];
  
  NSDate *initialTime = [NSDate date];
  while ((!isConnected) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  NSDictionary *env = [[NSProcessInfo processInfo] environment];
  [connection uploadFile: [[env objectForKey:@"SRCROOT"] stringByAppendingPathComponent: @"unit test/AbstractConnectionTest.h"] toFile:  @"AbstractConnectionTest.h"];
  [connection uploadFile: [[env objectForKey:@"SRCROOT"] stringByAppendingPathComponent: @"unit test/AbstractConnectionTest.m"] toFile:  @"AbstractConnectionTest.m"];
  
  didUpload = receivedError = NO;
  initialTime = [NSDate date];
  while ((!didUpload) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  STAssertFalse(receivedError, @"received error on upload");
  STAssertTrue(([initialTime timeIntervalSinceNow] > -15), @"timeout on upload");
  
  [self checkThatFileExistsAtPath: @"AbstractConnectionTest.h"];
  [self checkThatFileExistsAtPath: @"AbstractConnectionTest.m"];
  
  //clean up
  [connection deleteFile: @"AbstractConnectionTest.h"];
  
  didDelete = receivedError = NO;
  initialTime = [NSDate date];
  while ((!didDelete) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  [connection deleteFile: @"AbstractConnectionTest.m"];
  
  didDelete = receivedError = NO;
  initialTime = [NSDate date];
  while ((!didDelete) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  [self checkThatFileDoesNotExistsAtPath: @"AbstractConnectionTest.h"];
  [self checkThatFileDoesNotExistsAtPath: @"AbstractConnectionTest.m"];
}

- (void) testConnect
{
  [connection connect];
  
  NSDate *initialTime = [NSDate date];
  while ((!isConnected) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  STAssertTrue(([initialTime timeIntervalSinceNow] > -15), @"timed out on connection");
  STAssertTrue([connection isConnected], @"did not connect");
  STAssertFalse(receivedError, @"error while connecting");
  STAssertEqualObjects(initialDirectory, [connection currentDirectory], @"invalid current directory");
}

- (void) testDisconnect
{
  [connection connect];
  
  NSDate *initialTime = [NSDate date];
  while ((!isConnected) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  [connection disconnect];
  initialTime = [NSDate date];
  while (([connection isConnected])  && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  
  STAssertTrue(([initialTime timeIntervalSinceNow] > -15), @"timed out on deconnection");
  STAssertFalse([connection isConnected], @"did not disconnect");
}

- (void) testConnectWithBadUserName
{
  [connection setUsername: @""];
  [connection connect];
  
  NSDate *initialTime = [NSDate date];
  while ((!isConnected) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  STAssertTrue([initialTime timeIntervalSinceNow] > -15, @"timed out on connection");
  STAssertFalse([connection isConnected], @"did not connect");
  STAssertTrue(receivedError, @"error while connecting");
}

- (void) testConnectWithBadpassword
{
  [connection setPassword: @""];
  [connection connect];
  
  NSDate *initialTime = [NSDate date];
  while ((!isConnected) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  STAssertTrue([initialTime timeIntervalSinceNow] > -15, @"timed out on connection");
  STAssertFalse([connection isConnected], @"did not connect");
  STAssertTrue(receivedError, @"error while connecting");
}

- (void) testConnectWithBadHost
{
  [connection setHost: @"asdfdsf"];
  [connection connect];
  
  NSDate *initialTime = [NSDate date];
  while ((!isConnected) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -30))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  STAssertTrue([initialTime timeIntervalSinceNow] > -30, @"timed out on connection");
  STAssertFalse([connection isConnected], @"connected");
  STAssertTrue(receivedError, @"error while connecting");
}

- (void)connection:(id <AbstractConnectionProtocol>)con didConnectToHost:(NSString *)host
{
  isConnected = YES;
}

- (void)connection:(id <AbstractConnectionProtocol>)con didDisconnectFromHost:(NSString *)host
{
  receivedError = YES;
}

- (void)connection:(id <AbstractConnectionProtocol>)con didReceiveError:(NSError *)error
{
  NSLog (@"%@\n%@", NSStringFromSelector(_cmd), error);
  receivedError = YES;
}

- (void)connectionDidSendBadPassword:(id <AbstractConnectionProtocol>)con
{
  receivedError = YES;
}


- (void)connection:(id <AbstractConnectionProtocol>)con uploadDidFinish:(NSString *)remotePath
{
  if (![con numberOfTransfers])
    didUpload = YES;
}


- (void)connection:(id <AbstractConnectionProtocol>)con didDeleteFile:(NSString *)path
{
  didDelete = YES;
}

- (void)connection:(id <AbstractConnectionProtocol>)con checkedExistenceOfPath:(NSString *)path pathExists:(BOOL)exists
{
  fileExists = exists;
  returnedFromFileExists = YES;
}


- (void)connection:(id <AbstractConnectionProtocol>)con didReceiveContents:(NSArray *)contents ofDirectory:(NSString *)dirPath
{
  directoryContents = [contents retain];
}

- (void)connection:(id <AbstractConnectionProtocol>)con didSetPermissionsForFile:(NSString *)path
{
  didSetPermission = YES;
}

- (void) checkThatFileExistsAtPath: (NSString*) inPath
{
  //check that the file was removed
  //
	NSLog(@"Checking for file: %@", inPath);
  [connection checkExistenceOfPath: inPath];
  
  fileExists = returnedFromFileExists = receivedError = NO;
  NSDate *initialTime = [NSDate date];
  while ((!returnedFromFileExists) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  STAssertFalse(receivedError, @"did receive an error while checking for file existence");
  STAssertTrue(([initialTime timeIntervalSinceNow] > -15), @"timeout on check file existence");
  STAssertTrue(fileExists, @"file does not exist");
}

- (void) checkThatFileDoesNotExistsAtPath: (NSString*) inPath
{
  //check that the file was removed
  //
  [connection checkExistenceOfPath: inPath];
  
  fileExists = returnedFromFileExists = receivedError = NO;
  NSDate *initialTime = [NSDate date];
  while ((!returnedFromFileExists) && (!receivedError) && ([initialTime timeIntervalSinceNow] > -15))  //wait for connection or 30 sec
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  
  STAssertFalse(receivedError, @"did receive an error while checking for file existence");
  STAssertTrue(([initialTime timeIntervalSinceNow] > -15), @"timeout on check file existence");
  STAssertFalse(fileExists, @"file exists");
}
@end