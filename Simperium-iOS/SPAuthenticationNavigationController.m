#import "SPAuthenticationNavigationController.h"


@implementation SPAuthenticationNavigationController

- (BOOL)shouldAutorotate
{
    UIViewController *firstViewController = self.viewControllers.firstObject;
    if (firstViewController == nil) {
        return YES;
    }

    return firstViewController.shouldAutorotate;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    UIViewController *firstViewController = self.viewControllers.firstObject;
    if (firstViewController == nil) {
        return UIInterfaceOrientationMaskAll;
    }

    return firstViewController.supportedInterfaceOrientations;
}

@end
