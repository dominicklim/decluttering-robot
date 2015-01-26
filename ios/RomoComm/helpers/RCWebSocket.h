//
//  RCWebSocket.h
//  RomoComm
//
//  Created by Dominick Lim on 12/15/13.
//  Copyright (c) 2013 Dominick Lim. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SRWebSocket.h>

typedef enum {
    RC_CONNECTING   = 0,
    RC_OPEN         = 1,
    RC_CLOSING      = 2,
    RC_CLOSED       = 3,
} RCReadyState;

@protocol RCWebSocketDelegate;

@interface RCWebSocket : NSObject <SRWebSocketDelegate>

@property (nonatomic, assign) id <RCWebSocketDelegate> delegate;

@property (nonatomic, readonly) RCReadyState readyState;
@property (nonatomic, readonly, retain) NSURL *url;

// This returns the negotiated protocol.
// It will be nil until after the handshake completes.
@property (nonatomic, readonly, copy) NSString *protocol;

- (void)sendEvent:(NSString *)event withData:(NSDictionary *)data;
- (void)sendCommand:(NSString *)command withData:(NSDictionary *)data;

- (void)disconnect;
- (void)restart;

@end

@protocol RCWebSocketDelegate <NSObject>

- (void)webSocket:(RCWebSocket *)webSocket didReceiveEvent:(NSString *)event withArgs:(NSDictionary *)args;

@optional

- (void)webSocketDidOpen:(RCWebSocket *)webSocket;
- (void)webSocket:(RCWebSocket *)webSocket didFailWithError:(NSError *)error;
- (void)webSocketWillDisconnect:(RCWebSocket *)webSocket;
- (void)webSocket:(RCWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;

@end
