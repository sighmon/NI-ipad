//
//  Publisher.h
//  Newsstand
//
//  Created by Carlo Vigiani on 18/Oct/11.
//  Copyright (c) 2011 viggiosoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NewsstandKit/NewsstandKit.h>
#import "NIAUIssue.h"

extern  NSString *PublisherDidUpdateNotification;
extern  NSString *PublisherFailedUpdateNotification;

@interface NIAUPublisher : NSObject {
    NSArray *issues;
    BOOL requestingIssues;
}

-(BOOL)isReady;
+(NIAUPublisher*)getInstance;

-(void)requestIssues;
-(void)forceDownloadIssues;
-(NSInteger)numberOfIssues;
-(NIAUIssue *)issueAtIndex:(NSInteger)index;
-(NIAUIssue *)issueWithName:(NSString *)name;

@end
