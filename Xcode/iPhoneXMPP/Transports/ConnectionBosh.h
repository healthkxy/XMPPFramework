//
//  ConnectionBosh.h
//  iPhoneXMPP
//
//  Created by 新勇 康 on 7/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPPJID.h"
#import "NSXMLElement+XMPP.h"

typedef enum {
    ATTR_TYPE_BOSH = 0,
    NAMESPACE_TYPE_BOSH = 1
} XMLNodeTypeBosh;

#pragma mark -

/**
 * Handles the in-order processing of responses.
 **/
@interface BoshWindowManagerBosh : NSObject {
	long long maxRidReceived; // all rid value less than equal to maxRidReceived are processed.
	long long maxRidSent;
    NSMutableSet *receivedRids;
}

@property unsigned int windowSize;
@property (readonly) long long maxRidReceived;

- (id)initWithRid:(long long)rid;
- (void)sentRequestForRid:(long long)rid;
- (void)recievedResponseForRid:(long long)rid;
- (BOOL)isWindowFull;
- (BOOL)isWindowEmpty;
@end

@interface RequestResponsePairBosh : NSObject
@property(retain) NSXMLElement *request;
@property(retain) NSXMLElement *response;
- (id)initWithRequest:(NSXMLElement *)request response:(NSXMLElement *)response;
@end

typedef enum {
    CONNECTED_BOSH = 0,
    CONNECTING_BOSH = 1,
    DISCONNECTING_BOSH = 2,
    DISCONNECTED_BOSH = 3,
    TERMINATING_BOSH = 4
} BoshTransportStateBosh;

#pragma mark -
@interface ConnectionBosh : NSObject
{
    BoshWindowManagerBosh *boshWindowManagerBosh;
}

@property (nonatomic, strong) XMPPJID *myJID;
@property (nonatomic, assign) unsigned int wait;
@property (nonatomic, assign) unsigned int hold;
@property (nonatomic, strong) NSString *domain;
@property (nonatomic, strong) NSString *routeProtocol;
@property (nonatomic, strong) NSString *host;
@property (nonatomic, assign) unsigned int port;
@property (nonatomic, assign) unsigned int inactivity;
@property (nonatomic, strong) NSString *sid;
@property (nonatomic, strong) NSString *lang;
@property (nonatomic, readonly) unsigned int requests;
@property (nonatomic, strong) NSString *url;
@property (nonatomic, readonly) BOOL secure; 
@property (nonatomic, strong) NSString *authid;

@property(nonatomic, readonly) BOOL isPaused;

@property (nonatomic,strong) NSString*password;

-(id)initWithBoshServer:(NSString*)urlString xmppHost:(NSString*)xmppHost;
-(BOOL)connect:(NSError **)error;
- (void)disconnect;
- (BOOL)isDisconnected;
@end
