//
//  NIAUCacheMethod.m
//  New Internationalist Magazine Australia
//
//  Created by pix on 5/09/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUCacheMethod.h"

@implementation NIAUCacheMethod

-(id)initMethod:(NSString *)name withReadBlock:(id (^)(id options,id state)) readBlock andWriteBlock:(void (^)(id object, id options, id state)) writeBlock
{
    self = [super init];
    if (self) {
        self.name = name;
        self.readBlock = readBlock;
        self.writeBlock = writeBlock;
    }
    return self;
}

@end