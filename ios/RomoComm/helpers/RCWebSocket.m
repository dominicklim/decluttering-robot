//
//  RCWebSocket.m
//  RomoComm
//
//  Created by Dominick Lim on 12/15/13.
//  Copyright (c) 2013 Dominick Lim. All rights reserved.
//

#import "RCWebSocket.h"

#import <AFNetworking.h>

@interface RCWebSocket ()

@property (nonatomic, strong) SRWebSocket *webSocket;

@property (nonatomic, strong) NSTimer *checkHeartBeatTimer;
@property (nonatomic, strong) NSDate *lastHeartBeatDate;

- (void)initHandshake;
- (void)socketConnectWithToken:(NSString *)token;
- (void)restart;
- (void)checkHeartBeat;

- (void)startCheckHeartBeatTimer;
- (void)stopCheckHeartBeatTimer;

- (void)didReceiveHeartBeat;
- (void)sendMessage:(NSString *)message;
- (void)emitHeartbeat;

@end

static NSTimeInterval const kHeartBeatTimeout = 5.0;
static NSTimeInterval const kHeartBeatInterval = 2.0;
static NSTimeInterval const kHeartBeatPeriod = kHeartBeatTimeout + kHeartBeatInterval;

// production
static NSString *const serverURL = @"romo-comm-server.herokuapp.com";
// development
//static NSString *const serverURL = @"magneto.local:8000";

@implementation RCWebSocket

#pragma mark -- Object lifecycle

- (id)init
{
    if (self = [super init]) {
        [self initHandshake];
    }
    
    return self;
}

#pragma mark -- Public properties

- (RCReadyState)readyState
{
    return (RCReadyState)[self.webSocket readyState];
}

- (NSURL *)url
{
    return [self.webSocket url];
}

- (NSString *)protocol
{
    return [self.webSocket protocol];
}

#pragma mark -- Public methods

- (void)sendEvent:(NSString *)event withData:(NSDictionary *)data
{
    data = @{@"name": event, @"args": data ? @[data] : @[]};
    
    NSData *JSONData = [NSJSONSerialization dataWithJSONObject:data
                                                       options:0 error:nil];
    NSString *json = [[NSString alloc] initWithData:JSONData
                                           encoding:NSUTF8StringEncoding];
    
    [self sendMessage:[NSString stringWithFormat:@"5:::%@", json]];
}

- (void)sendCommand:(NSString *)command withData:(NSDictionary *)data
{
    data = data ? data : @{};

    NSMutableDictionary *mutableData = [NSMutableDictionary dictionaryWithDictionary:data];
    mutableData[@"name"] = command;

    [self sendEvent:@"sendCommand" withData:mutableData];
}

- (void)disconnect
{
    if ([self.delegate respondsToSelector:@selector(webSocketWillDisconnect:)]) {
        [self.delegate webSocketWillDisconnect:self];
    }

    [self stopCheckHeartBeatTimer];

    [self sendEvent:@"disconnectMe" withData:@{}];
}

#pragma mark -- Private methods

- (void)initHandshake
{
    if (self.webSocket.readyState != SR_OPEN) {
        NSTimeInterval time = [[NSDate date] timeIntervalSince1970];
        NSString *getURL = [NSString stringWithFormat:@"http://%@/socket.io/1?t=%.0f", serverURL, time * 1000];
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        
        [manager POST:getURL parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
            
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            if (error.code == 3840) {
                NSString *token = [operation.responseString componentsSeparatedByString:@":"][0];
                [self socketConnectWithToken:token];
            } else {
                double delayInSeconds = 2.0;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [self initHandshake];
                });
            }
        }];
    }
}

- (void)socketConnectWithToken:(NSString *)token
{
    NSString *urlString = [NSString stringWithFormat:@"ws://%@/socket.io/1/websocket/%@", serverURL, token];
    
    NSURL *url = [NSURL URLWithString:urlString];
    self.webSocket = [[SRWebSocket alloc] initWithURL:url];
    self.webSocket.delegate = self;
    [self.webSocket open];
}

- (void)restart
{
    [self disconnect];
    [self initHandshake];
}

- (void)checkHeartBeat
{
    if ([self.lastHeartBeatDate timeIntervalSinceNow] < -(kHeartBeatPeriod + 0.5)) {
        [self restart];
    }
}

- (void)startCheckHeartBeatTimer
{
    if (self.checkHeartBeatTimer == nil || ![self.checkHeartBeatTimer isValid]) {
        self.checkHeartBeatTimer = [NSTimer timerWithTimeInterval:kHeartBeatPeriod
                                                           target:self
                                                         selector:@selector(checkHeartBeat)
                                                         userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.checkHeartBeatTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)stopCheckHeartBeatTimer
{
    [self.checkHeartBeatTimer invalidate];
    self.checkHeartBeatTimer = nil;
}

#pragma mark -- Socket message handling

- (void)didReceiveHeartBeat
{
    self.lastHeartBeatDate = [NSDate date];
    [self emitHeartbeat];
}

#pragma mark -- SRWebSocket wrapper methods

- (void)sendMessage:(NSString *)message
{
    if ([self.webSocket readyState] == SR_OPEN) {
        [self.webSocket send:message];
    }
}

- (void)emitHeartbeat
{
    [self sendMessage:@"2::"];
}

#pragma mark -- SRWebSocketDelegate methods

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    NSError *jsonError;
    
    NSData *data = [[[message componentsSeparatedByString:@":::"] lastObject] dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
    NSString *event = [json objectForKey:@"name"];
    NSDictionary *args = [[json objectForKey:@"args"] objectAtIndex:0];
    
    int messageType = [[message substringToIndex:1] intValue];
    switch (messageType) {
        case 2:
            [self didReceiveHeartBeat];
            break;
        case 5:
            if ([self.delegate respondsToSelector:@selector(webSocket:didReceiveEvent:withArgs:)]) {
                [self.delegate webSocket:self didReceiveEvent:event withArgs:args];
            }
            break;
        default:
            break;
    }
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    [self startCheckHeartBeatTimer];

    if ([self.delegate respondsToSelector:@selector(webSocketDidOpen:)]) {
        [self.delegate webSocketDidOpen:self];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(webSocket:didFailWithError:)]) {
        [self.delegate webSocket:self didFailWithError:error];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    if ([self.delegate respondsToSelector:@selector(webSocket:didCloseWithCode:reason:wasClean:)]) {
        [self.delegate webSocket:self didCloseWithCode:code
                          reason:reason wasClean:wasClean];
    }
}

@end
