//
//  SPIWebSocketConnection.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-27.
//  Copyright © 2017 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SPIConnection.h"

@interface SPIWebSocketConnection : NSObject <SPIConnection>

@property (nonatomic, assign) BOOL               isConnected;
@property (nonatomic, assign) SPIConnectionState state;
@property (nonatomic, copy) NSString             *url;

@property (nonatomic, weak) id <SPIConnectionDelegate> delegate;

- (instancetype)initWithDelegate:(id <SPIConnectionDelegate>)delegate;

@end
