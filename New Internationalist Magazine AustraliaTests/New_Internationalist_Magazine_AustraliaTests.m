//
//  New_Internationalist_Magazine_AustraliaTests.m
//  New Internationalist Magazine AustraliaTests
//
//  Created by Simon Loffler on 20/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

//#import <XCTest/XCTest.h>
#import "XCTestCase+MethodSwizzling.h"
#import "NIAUPublisher.h"

#include <objc/runtime.h>

@interface New_Internationalist_Magazine_AustraliaTests : XCTestCase

@end

@implementation New_Internationalist_Magazine_AustraliaTests

Method originalMethod;
Method mockMethod;

NSMutableArray *notifications;

-(void)storeNotification:(NSNotification *)notification {
    [notifications addObject:notification];
}

-(void)clearNotifications {
    [notifications removeAllObjects];
}

-(int)countNotificationsWithName:(NSString *)_name {
    return [[notifications indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [obj name]==_name;
    }] count];
}

+ (void)setUp
{
    [super setUp];
    
    notifications = [NSMutableArray array];
    
    // Set-up code here.
    
     //THIS HAPPENS TOO LATE
    /*
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *directory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSLog(@"directory is %@", directory);
    NSError *error = nil;
    for (NSString *file in [fm contentsOfDirectoryAtPath:directory error:&error]) {
        NSLog(@"%@",file);
        BOOL success = [fm removeItemAtPath:[directory stringByAppendingPathComponent:file] error:&error];
        if (!success || error) {
            NSLog(@"error clearing cache: %@", error);
        }
    }
    */
    
    
    // clear out NKLibrary
    NSLog(@"nklibrary issues: %@", [[NKLibrary sharedLibrary] issues]);
    NSArray *issuesToDelete = [NSArray arrayWithArray:[[NKLibrary sharedLibrary] issues]];
    NSLog(@"issuesToDelete: %@", issuesToDelete);
    for (NKIssue *issue in issuesToDelete) {
        NSLog(@"removing issue %@",issue);
        [[NKLibrary sharedLibrary] removeIssue:issue];
    }
    NSLog(@"post-removal nklibrary issues: %@", [[NKLibrary sharedLibrary] issues]);
    
    /*
    //[NSData dataWithContentsOfURL:issuesURL]
    [self swizzleMethod:@selector(dataWithContentsOfURL:)  inClass:[NSData class]
             withMethod:@selector(dataWithContentsOfURL_nil:) fromClass:[self class]
           executeBlock:^{}]
    */

    
    originalMethod = class_getClassMethod([NSData class], @selector(dataWithContentsOfURL:));
    mockMethod = class_getInstanceMethod([self class], @selector(dataWithContentsOfURL_nil:));
    method_exchangeImplementations(originalMethod, mockMethod);
    
}

- (id)dataWithContentsOfURL_nil:(NSURL *)url {
    return nil;
}

+ (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
    method_exchangeImplementations(mockMethod, originalMethod);
}

- (void)testCacheIsEmptyAndNSDataStubFails
{
    [self clearNotifications];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storeNotification:) name:PublisherDidUpdateNotification object:[NIAUPublisher getInstance]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storeNotification:) name:PublisherFailedUpdateNotification object:[NIAUPublisher getInstance]];

    
    [[NIAUPublisher getInstance] requestIssues];
    
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
    while ([self countNotificationsWithName:PublisherFailedUpdateNotification]<1 && [deadline timeIntervalSinceNow]>0) {
        //spinlock
        NSLog(@"spinning..");
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:deadline];
    }
    XCTAssertTrue([deadline timeIntervalSinceNow]>0,@"timed out waiting for failure");
    NSLog(@"%d",[[NIAUPublisher getInstance] numberOfIssues]);
    XCTAssertTrue([[NIAUPublisher getInstance] numberOfIssues]==0);
}

@end
