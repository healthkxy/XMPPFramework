//
//  ConnectionBosh.m
//  iPhoneXMPP
//
//  Created by 新勇 康 on 7/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ConnectionBosh.h"
#import "XMPPJID.h"
#import "NSXMLElement+XMPP.h"

@interface ConnectionBosh ()
- (BOOL)createSession:(NSError **)error;
- (void)makeBodyAndSendHTTPRequestWithPayload:(NSArray *)bodyPayload 
                                   attributes:(NSMutableDictionary *)attributes 
                                   namespaces:(NSMutableDictionary *)namespaces;
- (NSXMLElement *)newBodyElementWithPayload:(NSArray *)payload 
                                 attributes:(NSMutableDictionary *)attributes 
                                 namespaces:(NSMutableDictionary *)namespaces;
- (void)sendHTTPRequestWithBody:(NSXMLElement *)body rid:(long long)rid;
@end

@implementation ConnectionBosh
{
    long long nextRidToSend;
    long long maxRidProcessed;

    NSString *boshVersion;
    
    NSString *boshServerString;
    NSString *xmppHostString;
}

@synthesize hold;
@synthesize domain;
@synthesize routeProtocol;
@synthesize host;
@synthesize myJID;
@synthesize wait;
@synthesize inactivity;
@synthesize port;
@synthesize sid;

static const int RETRY_COUNT_LIMIT = 25;
static const NSTimeInterval RETRY_DELAY = 1.0;
static const NSTimeInterval DELAY_UPPER_LIMIT = 32.0;
static const NSTimeInterval DELAY_EXPONENTIATING_FACTOR = 2.0;
static const NSTimeInterval INITIAL_RETRY_DELAY = 1.0;

static const NSString *CONTENT_TYPE = @"text/xml; charset=utf-8";
static NSString *BODY_NS = @"http://jabber.org/protocol/httpbind";
static const NSString *XMPP_NS = @"urn:xmpp:xbosh";

#define BoshVersion @"1.6"

#pragma mark Protocol NSCoding Method Implementation

#define kNextRidToSend		@"nextRidToSend"
#define kMaxRidProcessed	@"maxRidProcessed"

#define kPendingXMPPStanza	@"pendingXMPPStanzas"
#define kBoshWindowManager	@"boshWindowManager"
#define kState				@"state"

#define kRequestResponsePairs @"requestResponsePairs"

#define kDisconnectError_	@"disconnectError_"

#define kMyJID			@"myJID"
#define kWait			@"wait"
#define kHold			@"hold"
#define kLang			@"lang"
#define kDomain			@"domain"
#define kRouteProtocol	@"routeProtocol"
#define kHost			@"host"
#define kPort			@"port"
#define kInactivity		@"inactivity"
#define kSecure			@"secure"
#define kRequest		@"requests"
#define kAuthId			@"authid"
#define kSid			@"sid"
#define kUrl			@"url"
#define kPersistedCookies  @"persistedCookies"


- (void)encodeWithCoder: (NSCoder *)coder
{
	[coder encodeInt64:nextRidToSend forKey:kNextRidToSend];
	[coder encodeInt64:maxRidProcessed forKey:kMaxRidProcessed];
	
	[coder encodeObject:pendingXMPPStanzas forKey:kPendingXMPPStanza];
	[coder encodeObject:boshWindowManager forKey:kBoshWindowManager] ;
	[coder encodeInt:state forKey:kState];
	
	[coder encodeObject:requestResponsePairs forKey:kRequestResponsePairs];
	
	[coder encodeObject:disconnectError_ forKey:kDisconnectError_];
	
	[coder encodeObject:self.myJID forKey:kMyJID];
	[coder encodeInt:self.wait forKey:kWait];
	[coder encodeInt:self.hold forKey:kHold];
	[coder encodeObject:self.lang forKey:kLang];
	[coder encodeObject:self.domain forKey:kDomain];
	[coder encodeObject:self.routeProtocol forKey:kRouteProtocol];
	[coder encodeObject:self.host forKey:kHost];
	[coder encodeInt:self.port forKey:kPort];
	[coder encodeInt:self.inactivity forKey:kInactivity];
	[coder encodeBool:self.secure forKey:kSecure];
	[coder encodeInt:self.requests forKey:kRequest];
	[coder encodeObject:self.authid forKey:kAuthId];
	[coder encodeObject:self.sid forKey:kSid];
	[coder encodeObject:self.url forKey:kUrl];
    
    [coder encodeObject:[[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies] forKey:kPersistedCookies];
}

- (void)commonInitWithCoder:(NSCoder *)coder
{
	boshVersion = BoshVersion;
	
	nextRidToSend = [coder decodeInt64ForKey:kNextRidToSend];
	maxRidProcessed = [coder decodeInt64ForKey:kMaxRidProcessed];
	
	pendingXMPPStanzas =[coder decodeObjectForKey:kPendingXMPPStanza];
	boshWindowManager = [coder decodeObjectForKey:kBoshWindowManager];
	state = [coder decodeIntForKey:kState];
	
	requestResponsePairs = [coder decodeObjectForKey:kRequestResponsePairs];
	
	disconnectError_ = [coder decodeObjectForKey:kDisconnectError_];
    
	self.myJID= [coder decodeObjectForKey:kMyJID];
	self.wait= [coder decodeIntForKey:kWait];
	self.hold= [coder decodeIntForKey:kHold];
	self.lang= [coder decodeObjectForKey:kLang];
	self.domain= [coder decodeObjectForKey:kDomain];
	self.routeProtocol= [coder decodeObjectForKey:kRouteProtocol];
	self.host= [coder decodeObjectForKey:kHost];
	self.port= [coder decodeIntForKey:kPort];
	self.inactivity= [coder decodeIntForKey:kInactivity];
	secure = [coder decodeBoolForKey:kSecure];
	requests = [coder decodeIntForKey:kRequest];
	self.authid= [coder decodeObjectForKey:kAuthId];
	self.sid= [coder decodeObjectForKey:kSid];
	self.url= [coder decodeObjectForKey:kUrl];
	
	pendingHTTPRequests_ = [[NSMutableSet alloc] initWithCapacity:2];
    
	for ( NSHTTPCookie *cookie in [coder decodeObjectForKey:kPersistedCookies] ) 
	{
		[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
	}
    
	retryCounter = 0;
	nextRequestDelay= INITIAL_RETRY_DELAY;
    
	multicastDelegate = [[GCDMulticastDelegate alloc] init];
	
}

- (id)initWithCoder: (NSCoder *)coder
{
	self = [super init];
	if (self && coder)
	{
		[self commonInitWithCoder:coder];
	}
	return self;
}

-(id)initWithBoshServer:(NSString*)urlString xmppHost:(NSString*)xmppHost
{
    self = [super init];
    if (self) {
        boshServerString = urlString;
        xmppHostString = xmppHost;
    }
    return self;
}

-(BOOL)connect:(NSError **)error
{
    return [self createSession:error];
}

- (BOOL)createSession:(NSError **)error
{
    NSMutableDictionary *attr = [NSMutableDictionary dictionaryWithCapacity:8];
    
    [attr setObject:CONTENT_TYPE forKey:@"content"];
    [attr setObject:[NSString stringWithFormat:@"%u", self.hold] forKey:@"hold"];
    [attr setObject:self.domain forKey:@"to"];
    [attr setObject:boshVersion forKey:@"ver"];
    [attr setObject:[NSString stringWithFormat:@"%u", self.wait] forKey:@"wait"];
    [attr setObject:[self.myJID bare] forKey:@"from"];
    [attr setObject:@"false" forKey:@"secure"];
    [attr setObject:@"en" forKey:@"xml:lang"];
    [attr setObject:@"1.0" forKey:@"xmpp:version"];
    [attr setObject:[NSString stringWithFormat:@"%u", self.inactivity] forKey:@"inactivity"];
    [attr setObject:@"iphone" forKey:@"ua"];
    if (self.host != nil) {
        NSString *route = [NSString stringWithFormat:@"%@:%@:%u", self.routeProtocol, self.host, self.port];
        [attr setObject:route forKey:@"route"];
    }
    
    NSMutableDictionary *ns = [NSMutableDictionary dictionaryWithObjectsAndKeys: XMPP_NS, @"xmpp", nil];
    
    [self makeBodyAndSendHTTPRequestWithPayload:nil attributes:attr namespaces:ns];
    
    return YES;
}

- (void)makeBodyAndSendHTTPRequestWithPayload:(NSArray *)bodyPayload 
                                   attributes:(NSMutableDictionary *)attributes 
                                   namespaces:(NSMutableDictionary *)namespaces
{
    NSXMLElement *requestPayload = [self newBodyElementWithPayload:bodyPayload 
                                                        attributes:attributes 
                                                        namespaces:namespaces];
    [self sendHTTPRequestWithBody:requestPayload rid:nextRidToSend];
    [boshWindowManager sentRequestForRid:nextRidToSend];
    ++nextRidToSend;
}

- (NSXMLElement *)newBodyElementWithPayload:(NSArray *)payload 
                                 attributes:(NSMutableDictionary *)attributes 
                                 namespaces:(NSMutableDictionary *)namespaces
{
    attributes = attributes ? attributes : [NSMutableDictionary dictionaryWithCapacity:3];
    namespaces = namespaces ? namespaces : [NSMutableDictionary dictionaryWithCapacity:1];
    
    /* Adding ack and sid attribute on every outgoing request after sid is created */
    if( self.sid ) 
    {
        [attributes setValue:self.sid forKey:@"sid"];
        long long ack = maxRidProcessed;
        if( ack != nextRidToSend - 1 ) 
        {
            [attributes setValue:[NSString stringWithFormat:@"%qi", ack] forKey:@"ack"];
        }
    }
    else
    {
        [attributes setValue:@"1" forKey:@"ack"];
    }
    
    [attributes setValue:[NSString stringWithFormat:@"%d", nextRidToSend] forKey:@"rid"];
    [namespaces setValue:BODY_NS forKey:@""];
	
    NSXMLElement *body = [[NSXMLElement alloc] initWithName:@"body"];
	
    NSArray *namespaceArray = [self newXMLNodeArrayFromDictionary:namespaces 
                                                           ofType:NAMESPACE_TYPE];
    NSArray *attributesArray = [self newXMLNodeArrayFromDictionary:attributes 
                                                            ofType:ATTR_TYPE];
    [body setNamespaces:namespaceArray];
    [body setAttributes:attributesArray];
    //[namespaceArray release];
    //[attributesArray release];
    
    if(payload != nil)
    {
        for(NSXMLElement *child in payload)
        {
            [body addChild:child];
        }
    }
    
    return body;
}

- (void)sendHTTPRequestWithBody:(NSXMLElement *)body rid:(long long)rid
{
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:self.url];
    [request setRequestMethod:@"POST"];
    [request setDelegate:self];
    [request setTimeOutSeconds:(self.wait + 4)];
    request.userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:rid]
                                                   forKey:@"rid"];
    if(body) 
    {
        [request appendPostData:[[body compactXMLString] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    RequestResponsePair *pair = [[RequestResponsePair alloc] initWithRequest:body response:nil];
    [requestResponsePairs setObject:pair forLongLongKey:rid];
    //[pair release];
    
    [pendingHTTPRequests_ addObject:request];
    
    [request startAsynchronous];
	if (DEBUG_SEND) {
		DDLogSend(@"BOSH: SEND[%qi] = %@", rid, body);
	} else {
		//DDLogInfo(@"BOSH: SEND sid: %@, rid: %qi", sid_, rid);
	}
    
    return;
}

@end
