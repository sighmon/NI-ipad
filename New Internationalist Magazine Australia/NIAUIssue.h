//
//  NIAUIssue.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 24/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NewsstandKit/NewsstandKit.h>

@interface NIAUIssue : NSObject {
    NSDictionary *dictionary;
}

@property(nonatomic, strong) UIImage *cover;
@property(nonatomic, weak) NSString *name;
@property(nonatomic, weak) NSString *title;
@property(nonatomic, weak) NSString *number;
@property(nonatomic, weak) NSDate *publication;
@property(nonatomic, weak) NSString *editor;
@property(nonatomic, weak) NSString *editorsLetter;

+(NSArray *)issuesFromNKLibrary;
+(NIAUIssue *)issueWithNKIssue:(NKIssue *)issue;
+(NIAUIssue *)issueWithDictionary:(NSDictionary *)dict;

-(void)addToNewsstand;
-(void)writeToCache;
-(void)getCoverWithCompletionBlock:(void(^)(UIImage *img))block;



@end
