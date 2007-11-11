// gcc -Wall -arch i386 -arch ppc -Os -s -framework AppKit -o relaunch relaunch.m

#import <AppKit/AppKit.h>
#import <unistd.h>

@interface TerminationListener : NSObject
{
	const char *executablePath;
	pid_t parentProcessId;
}

- (void) relaunch;

@end

@implementation TerminationListener

- (id) initWithExecutablePath:(const char *)execPath parentProcessId:(pid_t)ppid
{
	self = [super init];
	if (self != nil) {
		executablePath = execPath;
		parentProcessId = ppid;
		
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(applicationDidTerminate:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
		if (getppid() == 1) {
			// ppid is launchd (1) => parent terminated already
			[self relaunch];
		}
		
		ProcessSerialNumber psn;
		if (GetProcessForPID(ppid, &psn) == procNotFound) {
			[self relaunch];
		}
	}
	return self;
}

- (void) applicationDidTerminate:(NSNotification *)notification
{
	if (parentProcessId == [[[notification userInfo] valueForKey:@"NSApplicationProcessIdentifier"] intValue]) {
		// parent just terminated
		[self relaunch];
	}
}

- (void) relaunch
{
	[[NSWorkspace sharedWorkspace] launchApplication:[NSString stringWithUTF8String:executablePath]];	
	[NSApp terminate:self];
}

@end

int main (int argc, const char * argv[])
{
	if (argc != 3) return EXIT_FAILURE;
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[NSApplication sharedApplication];
	[[[TerminationListener alloc] initWithExecutablePath:argv[1] parentProcessId:atoi(argv[2])] autorelease];
	[NSApp run];
	
	// This will not be executed because -[NSApp terminate:] is called
	[pool release];
	
	return EXIT_SUCCESS;
}