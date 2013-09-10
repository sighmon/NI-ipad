//
//  NIAUCache.h
//  New Internationalist Magazine Australia
//
//  Created by pix on 5/09/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NIAUCacheMethod.h"

@interface NIAUCache : NSObject

-(void)addMethod:(NIAUCacheMethod *) method;

@property (nonatomic, strong) NSMutableArray *methods;
@property (nonatomic, strong) NSMutableDictionary *state;

-(id)readWithOptions:(id)options;
-(id)readWithOptions:(id)options stoppingAt:(NSString *)methodName;

@end
