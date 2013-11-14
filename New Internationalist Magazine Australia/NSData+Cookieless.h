//
//  NSData+cookieless.h
//  New Internationalist Magazine Australia
//
//  Created by pix on 14/11/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (Cookieless)
+ (id)dataWithContentsOfCookielessURL:(NSURL *)aURL;
@end
