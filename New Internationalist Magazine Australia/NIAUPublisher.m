//
//  Publisher.m
//  Newsstand
//
//  Created by Carlo Vigiani on 18/Oct/11.
//  Copyright (c) 2011 viggiosoft. All rights reserved.
//

#import "NIAUPublisher.h"
#import <NewsstandKit/NewsstandKit.h>
#import "NSData+Cookieless.h"
#import "local.h"

#import "NIAUIssue.h"

NSString *PublisherDidUpdateNotification = @"PublisherDidUpdate";
NSString *PublisherFailedUpdateNotification = @"PublisherFailedUpdate";

@interface NIAUPublisher ()

@end

@implementation NIAUPublisher


-(BOOL)isReady {
    return (issues != nil);
}

static NIAUPublisher *instance =nil;
+(NIAUPublisher *)getInstance
{
    @synchronized(self)
    {
        if(instance==nil)
        {
            instance= [NIAUPublisher new];
        }
    }
    return instance;
}

-(id)init {
    self = [super init];
    
    if(self) {
        issues = nil;
        requestingIssues = FALSE;
        issuesCache = [NIAUPublisher buildIssuesCache];
    }
    return self;
}

+(NIAUCache *)buildIssuesCache {
    NIAUCache *cache = [[NIAUCache alloc] init];
    
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"memory"withReadBlock:^id(id options, id state) {
        return state[@"issues"];
    } andWriteBlock:^(id object, id options, id state) {
        state[@"issues"] = object;
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"disk"withReadBlock:^id(id options, id state) {
        NSArray *issues = [NIAUIssue issuesFromNKLibrary];
        if (issues && [issues count]>0) {
            return issues;
        } else {
            return nil;
        }
    } andWriteBlock:^(id object, id options, id state) {
        // the net read block already writes to the cache (via the initWithDictionary method) so we probably don't need to do anything here.
        // if leaving this as a no-op causes problems, we could iterate the array and call -writeToCache
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"net"withReadBlock:^id(id options, id state) {
        NSURL *issuesURL = [NSURL URLWithString:@"issues.json" relativeToURL:[NSURL URLWithString:SITE_URL]];
        NSLog(@"try to download issues.json from %@", issuesURL);
        NSData *data = [NSData dataWithContentsOfCookielessURL:issuesURL];
        if(data) {
            NSError *error;
            NSArray *tmpIssues = [NSJSONSerialization
                                  JSONObjectWithData:data //1
                                  
                                  options:kNilOptions
                                  error:&error];
            [tmpIssues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                
                // we could add each of these to our issues array
                // but instead we re-read the nklibrary after building all of the issues
                // NOTE: this has the side effect of writing to disk
                [NIAUIssue issueWithDictionary:obj];
            }];
            
            // re-read issues
            return [NIAUIssue issuesFromNKLibrary];
        } else {
            return nil;
        }
    } andWriteBlock:^(id object, id options, id state) {
        //no-op
    }]];
    return cache;
}

-(void)requestIssues {
    if(!requestingIssues) {
        requestingIssues = TRUE;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            issues = [issuesCache readWithOptions:nil];
            if(issues && [issues count]>0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:PublisherDidUpdateNotification object:self];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:PublisherFailedUpdateNotification object:self];
                });
            }
            requestingIssues = FALSE;
        });
    }
}

-(void)forceDownloadIssues {
    issues = [issuesCache readWithOptions:nil startingAt:@"net" stoppingAt:nil];
}

-(NSInteger)numberOfIssues {
    if(issues) {
        return [issues count];
    } else {
        return 0;
    }
}

-(NIAUIssue *)issueAtIndex:(NSInteger)index {
    return [issues objectAtIndex:index];
}

-(NIAUIssue *)issueWithName:(NSString *)name {
    // TODO: Catch out of bounds exception when the issue doesn't get found.
    return [issues objectAtIndex:[issues indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        //        NSLog(@"Object: %@, railsID: %@",[obj railsID], railsID);
        return ([[obj name] isEqualToString:name]);
    }]];
}

-(NIAUIssue *)issueWithRailsID:(NSNumber *)railsID
{
    // TODO: Catch out of bounds exception when the issue doesn't get found.
    return [issues objectAtIndex:[issues indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        //        NSLog(@"Object: %@, railsID: %@",[obj railsID], railsID);
        return ([[obj railsID] isEqualToNumber:railsID]);
    }]];
}

-(NIAUIssue *)lastIssue
{
    // Last issue in the issues.json list, not the latest
    return [issues lastObject];
}

@end
