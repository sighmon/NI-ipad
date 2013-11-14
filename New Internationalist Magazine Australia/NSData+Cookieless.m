//
//  NSData+cookieless.m
//  New Internationalist Magazine Australia
//
//  Created by pix on 14/11/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NSData+Cookieless.h"

@implementation NSData (Cookieless)
+ (id)dataWithContentsOfCookielessURL:(NSURL *)aURL {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:aURL];
    [request setHTTPMethod:@"GET"];
    [request setHTTPShouldHandleCookies:NO];
    NSError *error;
    NSHTTPURLResponse *response;
    return [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
}
@end
