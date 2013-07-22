//
//  NIAUArticle.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 27/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUArticle.h"

@implementation NIAUArticle

-(NSString *)author {
    return [dictionary objectForKey:@"author"];
}

-(NSString *)teaser {
    return [dictionary objectForKey:@"teaser"];
}

-(NSString *)title {
    return [dictionary objectForKey:@"title"];
}


-(NSString *)body {
    // TODO: the body will be stored as a file in the cache dir
    if (self.isComplete) {
        return [dictionary objectForKey:@"body"];
    } else {
        return nil;
    }
}

-(NIAUArticle *)initWithDictionary:(NSDictionary *)dict {
    
    self->_complete = false;
    
    dictionary = dict;
    
    [self writeToCache];
    
    return self;
}

-(void)writeToCache {
    NSLog(@"TODO: %s", __PRETTY_FUNCTION__);
}

@end
