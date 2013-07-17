//
//  Publisher.h
//  Newsstand
//
//  Created by Carlo Vigiani on 18/Oct/11.
//  Copyright (c) 2011 viggiosoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NewsstandKit/NewsstandKit.h>

extern  NSString *PublisherDidUpdateNotification;
extern  NSString *PublisherFailedUpdateNotification;

@interface NIAUPublisher : NSObject {
    NSArray *issues;
    
}

@property (nonatomic,readonly,getter = isReady) BOOL ready;

+(NIAUPublisher*)getInstance;

-(void)addIssuesInNewsstand;
-(void)getIssuesList;
-(NSInteger)numberOfIssues;
-(NSDictionary *)issueMetaDataAtIndex:(NSInteger)index;
-(NSString *)titleOfIssueAtIndex:(NSInteger)index;
-(NSString *)nameOfIssueAtIndex:(NSInteger)index;
-(void)getCoverOfIssueAtIndex:(NSInteger)index completionBlock:(void(^)(UIImage *img))block;
-(NSURL *)contentURLForIssueWithName:(NSString *)name;
-(NSString *)downloadPathForIssue:(NKIssue *)nkIssue;
-(UIImage *)coverImageForIssue:(NKIssue *)nkIssue;

@end
