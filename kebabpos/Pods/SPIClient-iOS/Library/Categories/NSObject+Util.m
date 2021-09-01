//
//  NSObject+Util.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2018-01-15.
//  Copyright © 2018 mx51. All rights reserved.
//

#import "NSObject+Util.h"
#import <objc/runtime.h>

@implementation NSObject (Util)

- (NSString *)dynamicDescription {
    
    NSMutableString *str = [NSString stringWithFormat:@"<%@: %p [", NSStringFromClass([self class]), &self].mutableCopy;
    
    @autoreleasepool {
        
        unsigned int    numberOfProperties = 0;
        objc_property_t *propertyArray     = class_copyPropertyList([self class], &numberOfProperties);
        
        for (NSUInteger i = 0; i < numberOfProperties; i++) {
            objc_property_t property = propertyArray[i];
            NSString        *name    = [[NSString alloc] initWithUTF8String:property_getName(property)];
            [str appendFormat:@"%@:%@, ", name, [self valueForKey:name]];
        }
        
        [str appendString:@"]>"];
        free(propertyArray);
    }
    
    return str.copy;
}

@end
