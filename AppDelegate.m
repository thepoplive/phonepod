#import "AppDelegate.h"
#import "PhonePodViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.window.rootViewController = [[PhonePodViewController alloc] init];
	self.window.backgroundColor = [UIColor blackColor];
	[self.window makeKeyAndVisible];
	return YES;
}

@end
