//
//  XCTestCase+MethodSwizzling.h
//  New Internationalist Magazine Australia
//
//  Created by pix on 24/07/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface XCTestCase (MethodSwizzling)

- (void)swizzleMethod:(SEL)aOriginalMethod
              inClass:(Class)aOriginalClass
           withMethod:(SEL)aNewMethod
            fromClass:(Class)aNewClass
         executeBlock:(void (^)(void))aBlock;
@end