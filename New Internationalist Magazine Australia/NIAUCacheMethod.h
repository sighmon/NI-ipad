//
//  NIAUCacheMethod.h
//  New Internationalist Magazine Australia
//
//  Created by pix on 5/09/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NIAUCacheMethod : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) id (^readBlock)(id options, id state);
@property (nonatomic, strong) void (^writeBlock)(id object, id options, id state);

-(id)initMethod:(NSString *)name withReadBlock:(id (^)(id options, id state)) readBlock andWriteBlock:(void (^)(id object, id options, id state)) writeBlock;

@end
