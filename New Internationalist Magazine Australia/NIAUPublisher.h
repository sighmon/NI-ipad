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
    
}

@property (nonatomic,readonly,getter = isReady) BOOL ready;

+(NIAUPublisher*)getInstance;

-(void)getIssuesList;
-(NSInteger)numberOfIssues;
-(NIAUIssue *)issueAtIndex:(NSInteger)index;

@end