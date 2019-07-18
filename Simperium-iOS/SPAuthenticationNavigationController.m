#import "SPAuthenticationNavigationController.h"


@implementation SPAuthenticationNavigationController

- (BOOL)shouldAutorotate
{
    if (self.topViewController == nil) {
        return YES;
    }

    return self.topViewController.shouldAutorotate;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if (self.topViewController == nil) {
        return UIInterfaceOrientationMaskAll;
    }

    return self.topViewController.supportedInterfaceOrientations;
}

@end
