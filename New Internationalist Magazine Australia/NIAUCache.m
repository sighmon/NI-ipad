//
//  NIAUCache.m
//  New Internationalist Magazine Australia
//
//  Created by pix on 5/09/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUCache.h"
#import "NIAUCacheMethod.h"

@implementation NIAUCache


- (id)init
{
    self = [super init];
    if (self) {
        self.methods = [NSMutableArray array];
    }
    return self;
}

-(void)addMethod:(NIAUCacheMethod *)method {
    [self.methods addObject:method];
}

-(id)readWithOptions:(id)options {
    return [self readWithOptions:options stoppingAt:nil];
}

// TODO: to allow cache refreshes, also accept startingAt
-(id)readWithOptions:(id)options stoppingAt:(NSString *)stopName {
    __block id result;
    if(![self.methods count]) {
        NSLog(@"*** READING NIAUCache OBJECT WITH NO METHODS ***");
    }
    // TODO: implement starting at by building an NSIndexSet based on the location of the method given by startingAt
    //NSLog(@"readWithOptions:%@ stoppingAt:%@",options,stopName);
    //NSLog(@"methods:%@", self.methods);
    [self.methods enumerateObjectsUsingBlock:^(NIAUCacheMethod *method, NSUInteger idx, BOOL *stop) {
        if(stopName!=nil && (method.name == stopName)) {
            //NSLog(@"read stopping at %@",method.name);
            *stop = YES;
        } else {
            //NSLog(@"method: %@",method.name);
            result = method.readBlock(options, _state);
            //NSLog(@"-->%@",result);
            if (result) {
                *stop = YES;
                // write result back to cache in backround queue
                NSString *secondMethodName = nil;
                if([self.methods count]>1) {
                    secondMethodName = self.methods[2];
                }
                // make sure we at least write it in to the first level cache before returning
                [self write:result withOptions:options stoppingAt:secondMethodName];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                               // startingAt:secondMethodName
                               ^{ [self write:result withOptions:options stoppingAt:method.name]; });
            }
        }
    }];
    return result;
}

-(void)write:(id)object withOptions:(id)options stoppingAt:(NSString*)stopName {
    [self.methods enumerateObjectsUsingBlock:^(NIAUCacheMethod *method, NSUInteger idx, BOOL *stop) {
        if(method.name == stopName) {
            *stop = YES;
        } else {
            method.writeBlock(object,options,_state);
        }
    }];
}

@end
