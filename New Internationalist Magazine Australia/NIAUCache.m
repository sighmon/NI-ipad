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
        self.state = [NSMutableDictionary dictionary];
    }
    return self;
}

-(void)addMethod:(NIAUCacheMethod *)method {
    [self.methods addObject:method];
}

-(id)readWithOptions:(id)options {
    return [self readWithOptions:options stoppingAt:nil];
}

// to allow cache refreshes, also accepts startingAt
-(id)readWithOptions:(id)options stoppingAt:(NSString *)stopName {
    return [self readWithOptions:options startingAt:nil stoppingAt:stopName];
}

-(id)readWithOptions:(id)options startingAt:(NSString *)startName stoppingAt:(NSString *)stopName {
    __block id result;
    if(![self.methods count]) {
        NSLog(@"*** READING NIAUCache OBJECT WITH NO METHODS ***");
    }
    // we implement starting at by building an NSIndexSet based on the location of the method given by startingAt
    NSUInteger startIndex = [self.methods indexOfObjectPassingTest:^BOOL(NIAUCacheMethod *method, NSUInteger idx, BOOL *stop) {
        return [method.name isEqualToString:startName];
    }];
    if (startIndex==NSNotFound) {
        startIndex=0;
    }
    NSUInteger stopIndex = [self.methods indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [[obj name] isEqualToString:stopName];
    }];
    if (stopIndex==NSNotFound) {
        // stop index is the first rule NOT to run, so this points to the first out-of-bounds index
        stopIndex=[self.methods count];
    }
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(startIndex,(stopIndex-startIndex))];
    [self.methods enumerateObjectsAtIndexes:indexSet options:0 usingBlock:^(NIAUCacheMethod *method, NSUInteger idx, BOOL *stop) {
        result = method.readBlock(options, self.state);
        if (result) {
            // write result back to cache in background queue
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
    }];
    return result;
}

-(void)clear {
    [self write:nil withOptions:nil];
    self.state = [NSMutableDictionary dictionary];
}

-(void)write:(id)object withOptions:(id)options {
    [self write:object withOptions:options stoppingAt:nil];
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
