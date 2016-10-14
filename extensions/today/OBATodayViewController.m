//
//  OBATodayViewController.m
//  OneBusAway Today Screen Extension
//
//  Created by Chad Royal on 10/14/16.
//  Copyright © 2016 OneBusAway. All rights reserved.
//

#import "OBATodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>

@interface OBATodayViewController () <NCWidgetProviding>

@end

@implementation OBATodayViewController

- (id)init
{
    self = [super initWithNibName:@"OBATodayViewController" bundle:nil];
    if (self) {

    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

}

#pragma mark - NCWidgetProviding delegate methods

- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context {

}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    // If an error is encountered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData

    completionHandler(NCUpdateResultNewData);
}

@end
