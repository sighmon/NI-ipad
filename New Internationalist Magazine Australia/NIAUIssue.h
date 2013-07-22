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
    NSArray *articles;
}

-(NSString *)name;
-(NSDate *)publication;

-(NSString *)title;
-(NSString *)editorsLetter;
-(NSString *)editorsName;

+(NSArray *)issuesFromNKLibrary;
+(NIAUIssue *)issueWithDictionary:(NSDictionary *)dict;

-(void)getCoverWithCompletionBlock:(void(^)(UIImage *img))block;


@end
