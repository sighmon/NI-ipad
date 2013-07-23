//
//  NIAUArticle.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 27/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NIAUIssue;

@interface NIAUArticle : NSObject {
    NSDictionary *dictionary;
}

@property(nonatomic,readonly,getter = isComplete) BOOL complete;

@property(nonatomic, strong) NIAUIssue *issue;

-(NSString *)title;
-(NSString *)teaser;
-(NSString *)author;
-(NSString *)body;

+(NIAUArticle *)articleWithIssue:(NIAUIssue *)issue andDictionary:(NSDictionary *)dict;

@end
