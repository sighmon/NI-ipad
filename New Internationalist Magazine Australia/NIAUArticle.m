//
//  NIAUArticle.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 27/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUArticle.h"

@implementation NIAUArticle

// AHA: this makes getters/setters for these readonly properties without exposing them publically
@synthesize complete;
@synthesize issue;

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

-(NIAUArticle *)initWithIssue:(NIAUIssue *)_issue andDictionary:(NSDictionary *)_dictionary {
    
    issue = _issue;
    
    complete = false;
    
    dictionary = _dictionary;
    
    [self writeToCache];
    
    return self;
}

+(NIAUArticle *)articleWithIssue:(NIAUIssue *)_issue andDictionary:(NSDictionary *)_dictionary {
    return [[NIAUArticle alloc] initWithIssue:_issue andDictionary: _dictionary];
}

-(void)writeToCache {
    NSLog(@"TODO: %s", __PRETTY_FUNCTION__);
}

@end
