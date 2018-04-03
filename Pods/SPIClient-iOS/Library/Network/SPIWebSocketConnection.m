//
//  SPIWebSocketConnection.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-27.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "SPIWebSocketConnection.h"

#import <SocketRocket/SocketRocket.h>
#import "SPIConnection.h"
#import "SPILogger.h"

@interface SPIWebSocketConnection () <SRWebSocketDelegate>
@property (nonatomic, strong) SRWebSocket *webSocket;
@end

@implementation SPIWebSocketConnection

- (instancetype)initWithDelegate:(id <SPIConnectionDelegate> )delegate {
    self = [super init];
    
    if (self) {
        self.delegate = delegate;
        _state        = SPIConnectionStateDisconnected;
    }
    
    return self;
}

- (void)connect {
    if (self.state == SPIConnectionStateConnected || self.state == SPIConnectionStateConnecting) {
        NSLog(@"socket not connecting because connected or connecting");
        return;
    }
    
    NSLog(@"socket trying to connect to %@", self.url);
    self.state = SPIConnectionStateConnecting;
    
    //Create a new socket instance specifying the url, SPI protocol and Websocket to use.
    //The will create a TCP/IP socket connection to the provided URL and perform HTTP websocket negotiation
    self.webSocket          = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.url] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:8.0] protocols:@[@"spi.2.0.0"]];
    self.webSocket.delegate = self;
    
    // Let's let our users know that we are now connecting...
    self.state = SPIConnectionStateConnecting;
    [self.webSocket open];
    [self.delegate onSpiConnectionStatusChanged:SPIConnectionStateConnecting];
}

- (void)disconnect {
    NSLog(@"socket disconnect. state before close: %ld", (long)self.webSocket.readyState);
    [self.webSocket close];
    NSLog(@"socket disconnect. state after close: %ld",  (long)self.webSocket.readyState);
    [self didClose];
}

- (void)sendPing {
    [self.webSocket sendPing:nil];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    //NSLog(@"socket onSpiMessageReceived \"%@\"", message);
    [self.delegate onSpiMessageReceived:message];
}

/**
 * key_request
 *
 **/

// Return YES to convert messages sent as Text to an NSString. Return NO to skip NSData -> NSString conversion for Text messages. Defaults to YES.
- (BOOL)webSocketShouldConvertTextFrameToString:(SRWebSocket *)webSocket {
    return YES;
}

- (void)send:(NSString *)msg {
    //NSLog(@"socket Send: %@", msg);
    
    [self.webSocket send:msg];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    SPILog(@"WS Error '%@'. Disconnecting.", error.localizedDescription);
    
    [self.delegate didReceiveError:error];
    [self disconnect];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessageWithString:(nonnull NSString *)string {
    NSLog(@"socket WS didReceiveMessageWithString '%@'", string);
    [self.delegate onSpiMessageReceived:string];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    NSLog(@"socket Websocket Connected");
    self.isConnected = YES;
    self.state       = SPIConnectionStateConnected;
    [self.delegate onSpiConnectionStatusChanged:SPIConnectionStateConnected];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    // This will not be called if disconnection is initiated on our side,
    // because we would have called didClose already which unregisters the delegate.
    NSLog(@"socket WebSocket closed [%ld], %@, wasClean=%@", (long)code, reason, @(wasClean));
    [self didClose];
}

- (void)didClose {
    self.isConnected        = NO;
    self.webSocket.delegate = nil;
    self.webSocket          = nil;
    
    if (self.state != SPIConnectionStateDisconnected) {
        self.state = SPIConnectionStateDisconnected;
        [self.delegate onSpiConnectionStatusChanged:SPIConnectionStateDisconnected];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
    //SPILog(@"WebSocket received pong");
}

@end
