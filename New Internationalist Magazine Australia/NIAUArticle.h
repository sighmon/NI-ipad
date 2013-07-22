//
//  NIAUArticle.h
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 27/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NIAUArticle : NSObject {
    NSDictionary *dictionary;
}

@property(nonatomic,readonly,getter = isComplete) BOOL complete;

-(NSString *)title;
-(NSString *)teaser;
-(NSString *)author;
-(NSString *)body;

-(NIAUArticle *)initWithDictionary:(NSDictionary *)dict;


@end
