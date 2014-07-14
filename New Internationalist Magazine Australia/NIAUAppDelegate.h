//
//  NIAUAppDelegate.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 20/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <UIKit/UIKit.h>

extern const char NotificationKey;

@class TAGManager;
@class TAGContainer;

@interface NIAUAppDelegate : UIResponder <UIApplicationDelegate, NSURLConnectionDownloadDelegate, NSURLConnectionDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic, strong) TAGManager *tagManager;
@property (nonatomic, strong) TAGContainer *container;

@end
