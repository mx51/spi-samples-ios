//
//  SPIConnection.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-28.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM (NSInteger, SPIConnectionState) {
    SPIConnectionStateDisconnected,
    SPIConnectionStateConnecting,
    SPIConnectionStateConnected,
};

@protocol SPIConnectionDelegate <NSObject>

- (void)onSpiConnectionStatusChanged:(SPIConnectionState)newConnectionState;
- (void)onSpiMessageReceived:(NSString *)message;
- (void)didReceiveError:(NSError *)error;

@end

@protocol SPIConnection <NSObject>

- (void)setUrl:(NSString *)url;

- (void)connect;
- (void)disconnect;

- (void)send:(NSString *)msg;

- (BOOL)isConnected;
- (SPIConnectionState)state;

- (id <SPIConnectionDelegate> )delegate;
- (void)setDelegate:(id <SPIConnectionDelegate> )delegate;

@end
