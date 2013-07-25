//
//  XCTestCase+MethodSwizzling.m
//  New Internationalist Magazine Australia
//
//  Created by pix on 24/07/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "XCTestCase+MethodSwizzling.h"

@implementation XCTestCase (MethodSwizzling)

- (void)swizzleMethod:(SEL)aOriginalMethod
              inClass:(Class)aOriginalClass
           withMethod:(SEL)aNewMethod
            fromClass:(Class)aNewClass
         executeBlock:(void (^)(void))aBlock {
    Method originalMethod = class_getClassMethod(aOriginalClass, aOriginalMethod);
    Method mockMethod = class_getInstanceMethod(aNewClass, aNewMethod);
    method_exchangeImplementations(originalMethod, mockMethod);
    aBlock();
    method_exchangeImplementations(mockMethod, originalMethod);
}

@end
