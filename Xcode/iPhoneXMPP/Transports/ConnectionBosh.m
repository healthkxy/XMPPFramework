//
//  ConnectionBosh.m
//  iPhoneXMPP
//
//  Created by 新勇 康 on 7/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ConnectionBosh.h"
#import "XMPPJID.h"
#import "XMPPIQ.h"
#import "NSXMLElement+XMPP.h"
#import "ASIHTTPRequest.h"
#import "XMPPDigestMD5Authentication.h"
#import "NSData+XMPP.h"
#import "XMPPMessage.h"
#import "XMPPPresence.h"

@interface NSMutableSet(ConnectionBosh)
- (void)addLongLong:(long long)number;
- (void)removeLongLong:(long long)number;
- (BOOL)containsLongLong:(long long)number;
@end

@interface NSMutableDictionary(ConnectionBosh) 
- (void)setObject:(id)anObject forLongLongKey:(long long)number;
- (void)removeObjectForLongLongKey:(long long)number;
- (id)objectForLongLongKey:(long long)number;
@end

@implementation NSMutableSet(ConnectionBosh)
- (void)addLongLong:(long long)number 
{
    NSNumber *nsNumber = [NSNumber numberWithLongLong:number];
    [self addObject:nsNumber];
}
- (void)removeLongLong:(long long)number
{
    NSNumber *nsNumber = [NSNumber numberWithLongLong:number];
    [self removeObject:nsNumber];
}
- (BOOL)containsLongLong:(long long)number
{
    NSNumber *nsNumber = [NSNumber numberWithLongLong:number];
    return [self containsObject:nsNumber];
}
@end

@implementation NSMutableDictionary(ConnectionBosh)
- (void)setObject:(id)anObject forLongLongKey:(long long)number 
{
    NSNumber *nsNumber = [NSNumber numberWithLongLong:number];
    [self setObject:anObject forKey:nsNumber];
}

- (void)removeObjectForLongLongKey:(long long)number 
{
    NSNumber *nsNumber = [NSNumber numberWithLongLong:number];
    [self removeObjectForKey:nsNumber];
}
- (id)objectForLongLongKey:(long long)number
{
    NSNumber *nsNumber = [NSNumber numberWithLongLong:number];
    return [self objectForKey:nsNumber];
}
@end

#pragma -
#pragma RequestResponsePair Class
@implementation RequestResponsePairBosh

@synthesize request=request_;
@synthesize response=response_;

- (id) initWithRequest:(NSXMLElement *)request response:(NSXMLElement *)response
{
	if( (self = [super init]) ) 
    {
		request_ = request;
		response_ = response;
	}
	return self;
}
@end

#pragma -
#pragma BoshWindowManager Class

@implementation BoshWindowManagerBosh

@synthesize windowSize;
@synthesize maxRidReceived;

- (id)initWithRid:(long long)rid
{
	if((self = [super init]))
	{
		windowSize = 0;
		maxRidSent = rid;
		maxRidReceived = rid;
        receivedRids = [[NSMutableSet alloc] initWithCapacity:2];
	}
	return self;
}

- (void)sentRequestForRid:(long long)rid
{
	NSAssert(![self isWindowFull], @"Sending request when should not be: Exceeding request count" );
	NSAssert2(rid == maxRidSent + 1, @"Sending request with rid = %qi greater than expected rid = %qi", rid, maxRidSent + 1);
	++maxRidSent;
}

- (void)recievedResponseForRid:(long long)rid
{
	NSAssert2(rid > maxRidReceived, @"Recieving response for rid = %qi where maxRidReceived = %qi", rid, maxRidReceived);
	NSAssert3(rid <= maxRidReceived + windowSize, @"Recieved response for a request outside the rid window. responseRid = %qi, maxRidReceived = %qi, windowSize = %qi", rid, maxRidReceived, windowSize);
    [receivedRids addLongLong:rid];
	while ( [receivedRids containsLongLong:(maxRidReceived + 1)] )
	{
		++maxRidReceived;
	}
}

- (BOOL)isWindowFull
{
	return (maxRidSent - maxRidReceived) == windowSize;
}

- (BOOL)isWindowEmpty
{
	return (maxRidSent - maxRidReceived) < 1;
}

@end

@interface ConnectionBosh ()
@property (nonatomic, strong) NSMutableSet *pendingHTTPRequests;

- (void)setInactivityFromString:(NSString *)givenInactivity;
- (void)setSecureFromString:(NSString *)isSecure;
- (void)setRequestsFromString:(NSString *)maxRequests;
- (void)setSidFromString:(NSString *)sid;

- (NSNumber *)numberFromString:(NSString *)stringNumber;

- (BOOL)createSession:(NSError **)error;
- (void)makeBodyAndSendHTTPRequestWithPayload:(NSArray *)bodyPayload 
                                   attributes:(NSMutableDictionary *)attributes 
                                   namespaces:(NSMutableDictionary *)namespaces;

- (NSXMLElement *)makeAndSendHTTPRequestWithPayload:(NSArray *)bodyPayload 
                                   attributes:(NSMutableDictionary *)attributes 
                                   namespaces:(NSMutableDictionary *)namespaces;

- (NSXMLElement *)newBodyElementWithPayload:(NSArray *)payload 
                                 attributes:(NSMutableDictionary *)attributes 
                                 namespaces:(NSMutableDictionary *)namespaces;
- (void)sendHTTPRequestWithBody:(NSXMLElement *)body rid:(long long)rid;
-(NSXMLElement*)sendHTTPRequestWithBody:(NSXMLElement *)body;
- (NSArray *)newXMLNodeArrayFromDictionary:(NSDictionary *)dict 
                                    ofType:(XMLNodeTypeBosh)type;
- (long long)generateRid;
- (NSXMLElement *)parseXMLData:(NSData *)xml error:(NSError **)error;
- (NSXMLElement *)newRootElement;
-(void)transportDidConnect;
- (BOOL)isConnected;
- (NSXMLElement *)broadcastStanzas:(NSXMLNode *)body;
-(NSXMLElement *)transportDidReceiveStanza:(NSXMLElement *)node;
- (void)handleStreamFeatures;
- (NSXMLElement *)handleStreamFeaturesAndReturn;
- (void)handleStartTLSResponse:(NSXMLElement *)response;
- (void)sendStartTLSRequest;
- (BOOL)sendStanzaWithString:(NSString *)string;
- (void)handleRegistration:(NSXMLElement *)response;
- (void)handleAuth1:(NSXMLElement *)response;
- (BOOL)supportsPlainAuthentication;
- (void)restartStream;
- (BOOL)authenticateWithPassword:(NSString *)password1 error:(NSError **)errPtr;
- (NSXMLElement *)authenticateWithPassword:(NSString *)password1;
- (void)sendElement:(NSXMLElement *)element;
- (void)sendElement:(NSXMLElement *)element withTag:(long)tag;
-(void)makeRootElement:(NSXMLElement *)element;
- (NSXMLElement *)handleBindingAndReturn:(NSXMLElement *)response;
@end

@implementation ConnectionBosh
{
    long long nextRidToSend;
    long long maxRidProcessed;
    NSMutableArray *pendingXMPPStanzas;
    BoshTransportStateBosh state;
    NSMutableDictionary *requestResponsePairs;
    NSError *disconnectError_;

    Byte flags;
    
    NSString *boshVersion;
    
    NSString *boshServerString;
    NSString *xmppHostString;
    int retryCounter;
    NSTimeInterval nextRequestDelay;
    int stream_state;
    NSXMLElement *rootElement;
    NSString *tempPassword;
}

typedef enum {
    HOST_UNKNOWN = 1,
    HOST_GONE = 2,
    ITEM_NOT_FOUND = 3,
    POLICY_VIOLATION = 4,
    REMOTE_CONNECTION_FAILED = 5,
    BAD_REQUEST = 6,
    INTERNAL_SERVER_ERROR = 7,
    REMOTE_STREAM_ERROR = 8,
    UNDEFINED_CONDITION = 9
} BoshTerminateConditions;

enum {
	STATE_DISCONNECTED,
	STATE_OPENING,
	STATE_NEGOTIATING,
	STATE_STARTTLS,
	STATE_REGISTERING,
	STATE_AUTH_1,
	STATE_AUTH_2,
	STATE_AUTH_3,
	STATE_BINDING,
	STATE_START_SESSION,
	STATE_CONNECTED,
};

@synthesize hold = hold_;
@synthesize domain = domain_;
@synthesize routeProtocol = routeProtocol_;
@synthesize host = host_;
@synthesize myJID = myJID_;
@synthesize wait = wait_;
@synthesize inactivity;
@synthesize port = port_;
@synthesize sid = sid_;
@synthesize lang = lang_;
@synthesize requests;
@synthesize url = url_;
@synthesize secure;
@synthesize authid = authid_;
@synthesize isPaused;
@synthesize password;

@synthesize pendingHTTPRequests = pendingHTTPRequests_;

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

#pragma mark -
#pragma mark Private Accessor Method Implementation

- (void)setSidFromString:(NSString *)sid 
{
    self.sid = sid;
}

- (void)setInactivityFromString:(NSString *)inactivityString
{
    NSNumber *givenInactivity = [self numberFromString:inactivityString];
    inactivity = [givenInactivity unsignedIntValue];
}

- (void)setRequestsFromString:(NSString *)requestsString
{
    NSNumber *maxRequests = [self numberFromString:requestsString];
    [boshWindowManagerBosh setWindowSize:[maxRequests unsignedIntValue]];
    requests = [maxRequests unsignedIntValue];
}

- (void)setSecureFromString:(NSString *)isSecure
{
    if ([isSecure isEqualToString:@"true"]) secure=YES;
    else secure = NO;
}

#pragma mark -

- (void)encodeWithCoder: (NSCoder *)coder
{
	[coder encodeInt64:nextRidToSend forKey:kNextRidToSend];
	[coder encodeInt64:maxRidProcessed forKey:kMaxRidProcessed];
	
	[coder encodeObject:pendingXMPPStanzas forKey:kPendingXMPPStanza];
	[coder encodeObject:boshWindowManagerBosh forKey:kBoshWindowManager] ;
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
	boshWindowManagerBosh = [coder decodeObjectForKey:kBoshWindowManager];
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
        //
        boshVersion = BoshVersion;
        lang_ = @"en";
        wait_ = 60.0;
        hold_ = 1;
        
        nextRidToSend = [self generateRid];
        maxRidProcessed = nextRidToSend - 1;
        
        sid_ = nil;
        inactivity = 5*60;//48 * 3600;
        //requests_ = 2;
        url_ = urlString;
        
        domain_ = xmppHost;//[domain copy];
        
        routeProtocol_ = nil;
        //if (routeProtocol != nil) {
            //routeProtocol_ = [routeProtocol copy];
        //}
        
        host_ = nil;
        //if (xmppHost != nil) {
            //host_ = xmppHost;
        //}
        port_ = 5222;
        
        myJID_ = nil;
        state = DISCONNECTED_BOSH;
        disconnectError_ = nil;
        
        /* Keeping a random capacity right now */
        pendingXMPPStanzas = [[NSMutableArray alloc] initWithCapacity:25];
        requestResponsePairs = [[NSMutableDictionary alloc] initWithCapacity:3];
        retryCounter = 0;
        nextRequestDelay = INITIAL_RETRY_DELAY;
        
        pendingHTTPRequests_ = [[NSMutableSet alloc] initWithCapacity:2];
        
        boshWindowManagerBosh = [[BoshWindowManagerBosh alloc] initWithRid:(nextRidToSend - 1)];
        [boshWindowManagerBosh setWindowSize:1];

    }
    return self;
}

-(BOOL)connect:(NSError **)error
{
    return [self createSession:error];
}

-(void)makeRootElement:(NSXMLElement *)element
{
    while ([element childCount] > 0) {
        NSXMLNode *node = [element childAtIndex:0];
        if ([node isKindOfClass:[NSXMLElement class]]) {
            [node detach];
            [rootElement setChildren:[NSArray arrayWithObject:node]];
            break;
        }
    }    
}

- (NSXMLElement *)handleStreamFeaturesAndReturn
{
	// Extract the stream features
	NSXMLElement *features = [rootElement elementForName:@"stream:features"];
	
	// Check to see if TLS is required
	// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
	NSXMLElement *f_starttls = [features elementForName:@"starttls" xmlns:@"urn:ietf:params:xml:ns:xmpp-tls"];
	
	if (f_starttls)
	{
		if ([f_starttls elementForName:@"required"])
		{
			// TLS is required for this connection
			
			// Update state
			stream_state = STATE_STARTTLS;
			
			// Send the startTLS XML request
			[self sendStartTLSRequest];
			
			// We do not mark the stream as secure yet.
			// We're waiting to receive the <proceed/> response from the
			// server before we actually start the TLS handshake.
			
			// We're already listening for the response...
			return nil;
		}
	}
	
	// Check to see if resource binding is required
	// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
	NSXMLElement *f_bind = [features elementForName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
	
	if (f_bind)
	{
		// Binding is required for this connection
		stream_state = STATE_BINDING;
		
		NSString *requestedResource = [self.myJID resource];
		
		if ([requestedResource length] > 0)
		{
			// Ask the server to bind the user specified resource
			
			NSXMLElement *resource = [NSXMLElement elementWithName:@"resource"];
			[resource setStringValue:requestedResource];
			
			NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
			[bind addChild:resource];
			
			NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
			[iq addAttributeWithName:@"type" stringValue:@"set"];
			[iq addChild:bind];
			
            //[transport sendStanza:iq];
            [pendingXMPPStanzas removeAllObjects];
            [pendingXMPPStanzas addObject:iq];
            return  [self makeAndSendHTTPRequestWithPayload:pendingXMPPStanzas attributes:nil namespaces:nil];

		}
		else
		{
			// The user didn't specify a resource, so we ask the server to bind one for us
			
			NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
			
			NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
			[iq addAttributeWithName:@"type" stringValue:@"set"];
			[iq addChild:bind];
			
            //[transport sendStanza:iq];
            [pendingXMPPStanzas removeAllObjects];
            [pendingXMPPStanzas addObject:iq];
            return  [self makeAndSendHTTPRequestWithPayload:pendingXMPPStanzas attributes:nil namespaces:nil];
		}
		
		// We're already listening for the response...
		return nil;
	}
	
	// It looks like all has gone well, and the connection should be ready to use now
	//state = STATE_CONNECTED;
	
	//if (![self isAuthenticated])
	{
		// Notify delegates
		//[multicastDelegate xmppStreamDidConnect:self];
	}
    return nil;
}


- (BOOL)createSession:(NSError **)error
{
    self.sid = nil;
    nextRidToSend = [self generateRid];
    
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
    
    //NSData *responseData = nil;
    NSXMLElement *parsedResponse = nil;
    //[self makeBodyAndSendHTTPRequestWithPayload:nil attributes:attr namespaces:ns];
    /*NSXMLElement *requestPayload = [self newBodyElementWithPayload:nil 
                                                        attributes:attr 
                                                        namespaces:ns];

    parsedResponse = [self sendHTTPRequestWithBody:requestPayload];*/
    parsedResponse = [self makeAndSendHTTPRequestWithPayload:nil attributes:attr namespaces:ns];
    if (parsedResponse==nil) {
        return NO;
    }
    
    NSArray *responseAttributes = [parsedResponse attributes];
    rootElement = [self newRootElement];
    
    /* Setting inactivity, sid, wait, hold, lang, authid, secure, requests */
    for(NSXMLNode *attr in responseAttributes)
    {
        NSString *attrName = [attr name];
        NSString *attrValue = [attr stringValue];
        SEL setter = [self setterForProperty:attrName];
        
        if([self respondsToSelector:setter]) 
        {
            [self performSelector:setter withObject:attrValue];
        }
    }
    stream_state = STATE_NEGOTIATING;
    [self broadcastStanzas:parsedResponse];
    
    [pendingXMPPStanzas removeAllObjects];
    NSXMLElement *requestPayload = [self authenticateWithPassword:self.password];
    [pendingXMPPStanzas addObject:requestPayload];
    parsedResponse = [self makeAndSendHTTPRequestWithPayload:pendingXMPPStanzas attributes:nil namespaces:nil];
    if (parsedResponse==nil) {
        return NO;
    }
    DebugLog(@"%@",parsedResponse);
    if(![[rootElement name] isEqualToString:@"success"]){
        //return NO;
    }
    /////
    attr = [NSMutableDictionary dictionaryWithObjectsAndKeys: @"true", @"xmpp:restart", nil];
    ns = [NSMutableDictionary dictionaryWithObjectsAndKeys:XMPP_NS, @"xmpp", nil];
    parsedResponse = [self makeAndSendHTTPRequestWithPayload:nil attributes:attr namespaces:ns];
    if (parsedResponse==nil) {
        return NO;
    }
    
    /////////
    stream_state = STATE_NEGOTIATING;
    parsedResponse = [self broadcastStanzas:parsedResponse];
    if (parsedResponse==nil) {
        return NO;
    }
    DebugLog(@"%@",parsedResponse);

    /*parsedResponse = [self broadcastStanzas:parsedResponse];
    if (parsedResponse==nil) {
        return NO;
    }
    DebugLog(@"%@",parsedResponse);*/

    XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
    //[self sendElement:presence];
    [pendingXMPPStanzas removeAllObjects];
    [pendingXMPPStanzas addObject:presence];
    parsedResponse = [self makeAndSendHTTPRequestWithPayload:pendingXMPPStanzas attributes:nil namespaces:nil];
    if (parsedResponse==nil) {
        return NO;
    }
    DebugLog(@"%@",parsedResponse);

    return YES;
}

- (NSXMLElement *)makeAndSendHTTPRequestWithPayload:(NSArray *)bodyPayload 
                                         attributes:(NSMutableDictionary *)attributes 
                                         namespaces:(NSMutableDictionary *)namespaces
{
    NSXMLElement *requestPayload = [self newBodyElementWithPayload:bodyPayload 
                                                        attributes:attributes 
                                                        namespaces:namespaces];
    NSXMLElement *parsedResponse = nil;
    parsedResponse = [self sendHTTPRequestWithBody:requestPayload];
    ++nextRidToSend;
    return parsedResponse;
}

- (void)makeBodyAndSendHTTPRequestWithPayload:(NSArray *)bodyPayload 
                                   attributes:(NSMutableDictionary *)attributes 
                                   namespaces:(NSMutableDictionary *)namespaces
{
    NSXMLElement *requestPayload = [self newBodyElementWithPayload:bodyPayload 
                                                        attributes:attributes 
                                                        namespaces:namespaces];
    [boshWindowManagerBosh sentRequestForRid:nextRidToSend];
    [self sendHTTPRequestWithBody:requestPayload rid:nextRidToSend];
    //++nextRidToSend;
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
                                                           ofType:NAMESPACE_TYPE_BOSH];
    NSArray *attributesArray = [self newXMLNodeArrayFromDictionary:attributes 
                                                            ofType:ATTR_TYPE_BOSH];
    [body setNamespaces:namespaceArray];
    [body setAttributes:attributesArray];
    
    if(payload != nil)
    {
        for(NSXMLElement *child in payload)
        {
            [body addChild:child];
        }
    }
    
    return body;
}

-(NSXMLElement *)sendHTTPRequestWithBody:(NSXMLElement *)body
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:self.url]];
    [request setHTTPMethod:@"POST"];
    [request setTimeoutInterval:(self.wait+4)];
    if(body) 
    {
        [request setHTTPBody:[[body compactXMLString] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    NSError *error = nil;
    NSURLResponse* response;
    NSData* result = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (error != nil) {
        DebugLog(@"%@",error);
        return nil;
    }
    //NSString *resultString = [[NSString alloc] initWithData:result
                                                   //encoding:NSUTF8StringEncoding];
    NSXMLElement *parsedResponse = [self parseXMLData:result error:&error];
	
    if (!parsedResponse || parsedResponse.kind != DDXMLElementKind || 
        ![parsedResponse.name isEqualToString:@"body"]  || 
        ![[parsedResponse namespaceStringValueForPrefix:@""] isEqualToString:BODY_NS])
    {
		if (parsedResponse != nil) {
			//DDLogWarn(@"BOSH: Parse Failure: Unexpected XML in response: %@", parsedResponse);
			//error = [NSError errorWithDomain:BOSHParsingErrorDomain
			//							code:0
			//						userInfo:nil];
		} else {
			//DDLogWarn(@"BOSH: Parse Failure: Cannot parse response string: %@", [request responseString]);
		}
		//DDLogWarn(@"BOSH: Parse Failure: Response headers: %@", [request responseHeaders]);
		//[self processError:error forRequest:request];
        return nil;
    }

    return parsedResponse;
}

- (void)sendHTTPRequestWithBody:(NSXMLElement *)body rid:(long long)rid
{
    /*ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:self.url]];
    [request setRequestMethod:@"POST"];
    [request setTimeOutSeconds:(self.wait + 4)];
    request.userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:rid]
                                                   forKey:@"rid"];
    if(body) 
    {
        [request appendPostData:[[body compactXMLString] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    RequestResponsePairBosh *pair = [[RequestResponsePairBosh alloc] initWithRequest:body response:nil];
    [requestResponsePairs setObject:pair forLongLongKey:rid];
    
    [pendingHTTPRequests_ addObject:request];*/
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:self.url]];
    [request setHTTPMethod:@"POST"];
    [request setTimeoutInterval:(self.wait+4)];
    if(body) 
    {
        [request setHTTPBody:[[body compactXMLString] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    RequestResponsePairBosh *pair = [[RequestResponsePairBosh alloc] initWithRequest:body response:nil];
    [requestResponsePairs setObject:pair forLongLongKey:rid];
    
    //NSURLConnection *theConnection = [[NSURLConnection alloc]init]; 
    //[request startAsynchronous];
    if (state!=CONNECTED_BOSH) {
        state = CONNECTING_BOSH;
    }
    //[request startAsynchronous];
    NSError *error = nil;//[request error];
    NSURLResponse* response;
    NSData* result = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (error != nil) {
        NSLog(@"%@",error);
        return;
    }
    NSString *resultString = [NSString stringWithUTF8String:result.bytes];
    NSLog(@"%@",resultString);
    ++nextRidToSend;
    [pendingXMPPStanzas removeAllObjects];
    [self requestFinished:result rid:rid];
}

- (NSArray *)newXMLNodeArrayFromDictionary:(NSDictionary *)dict 
                                    ofType:(XMLNodeTypeBosh)type
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    for (NSString *key in dict) 
    {
        NSString *value = [dict objectForKey:key];
        NSXMLNode *node;
        
        if(type == ATTR_TYPE_BOSH) 
        {
            node = [NSXMLNode attributeWithName:key stringValue:value];
        }
        else if(type == NAMESPACE_TYPE_BOSH)
        {
            node = [NSXMLNode namespaceWithName:key stringValue:value];
        }
        else
        {
            NSException *exception = [NSException exceptionWithName:@"InvalidXMLNodeType"
                                                             reason:@"BOSH: Wrong Type Passed to createArrayFrom Dictionary"
                                                           userInfo:nil];
            @throw exception;
        }
		
        [array addObject:node];
    }
    return array;
}

- (long long)generateRid
{
    return (arc4random() % 1000000000LL + 1000000001LL);
}

- (SEL)setterForProperty:(NSString *)property
{
    NSString *setter = @"set";
    setter = [setter stringByAppendingString:[property capitalizedString]];
    setter = [setter stringByAppendingString:@"FromString:"];
    return NSSelectorFromString(setter);
}


- (NSNumber *)numberFromString:(NSString *)stringNumber
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    NSNumber *number = [formatter numberFromString:stringNumber];
    //[formatter release];
    return number;
}


- (BOOL)isDisconnected
{
	return (state == DISCONNECTED_BOSH);
}

- (void)requestFinished:(NSData*)responseData rid:(long long)rid
{
    //long long rid = [self getRidFromRequest:request];
    
    //if (DEBUG_RECV_PRE) {
        //DDLogRecvPre(@"BOSH: RECD[%qi] = %@", rid, [request responseString]);
    //} else {
        //DDLogInfo(@"BOSH: RECD sid: %@, rid: %qi", sid_, rid);
    //}
    
    //NSData *responseData = [request responseData];
    
	NSError *error;
    NSXMLElement *parsedResponse = [self parseXMLData:responseData error:&error];
	
    if (!parsedResponse || parsedResponse.kind != DDXMLElementKind || 
        ![parsedResponse.name isEqualToString:@"body"]  || 
        ![[parsedResponse namespaceStringValueForPrefix:@""] isEqualToString:BODY_NS])
    {
		if (parsedResponse != nil) {
			//DDLogWarn(@"BOSH: Parse Failure: Unexpected XML in response: %@", parsedResponse);
			//error = [NSError errorWithDomain:BOSHParsingErrorDomain
			//							code:0
			//						userInfo:nil];
		} else {
			//DDLogWarn(@"BOSH: Parse Failure: Cannot parse response string: %@", [request responseString]);
		}
		//DDLogWarn(@"BOSH: Parse Failure: Response headers: %@", [request responseHeaders]);
		//[self processError:error forRequest:request];
        return;
    }
    
    retryCounter = 0;
    nextRequestDelay = INITIAL_RETRY_DELAY;
    
    RequestResponsePairBosh *requestResponsePair = [requestResponsePairs objectForLongLongKey:rid];
    [requestResponsePair setResponse:parsedResponse];
    
    //[pendingHTTPRequests_ removeObject:request];

    [boshWindowManagerBosh recievedResponseForRid:rid];
    [self processResponses];
    
    [self trySendingStanzas];
}

- (void)sendTerminateRequestWithPayload:(NSArray *)bodyPayload 
{
    NSMutableDictionary *attr = [NSMutableDictionary dictionaryWithObjectsAndKeys: @"terminate", @"type", nil];
    [self makeBodyAndSendHTTPRequestWithPayload:bodyPayload attributes:attr namespaces:nil];
}

- (void)trySendingStanzas
{
    if( state != DISCONNECTED_BOSH && ![boshWindowManagerBosh isWindowFull] ) 
    {
        if (state == CONNECTED_BOSH) {
            if ( [pendingXMPPStanzas count] > 0 || [boshWindowManagerBosh isWindowEmpty] )
            {
                [self makeBodyAndSendHTTPRequestWithPayload:pendingXMPPStanzas 
                                                 attributes:nil 
                                                 namespaces:nil];
                [pendingXMPPStanzas removeAllObjects];
            } 
        }
        else if(state == DISCONNECTING_BOSH) 
        { 
            state = TERMINATING_BOSH;
            [self sendTerminateRequestWithPayload:pendingXMPPStanzas];
            [pendingXMPPStanzas removeAllObjects];
        }
        else if ([boshWindowManagerBosh isWindowEmpty] && state == TERMINATING_BOSH) 
        {
            /* sending more empty requests till we get a terminate response */
            [self makeBodyAndSendHTTPRequestWithPayload:nil 
                                             attributes:nil 
                                             namespaces:nil];                
        }
    }
}

- (NSXMLElement *)parseXMLData:(NSData *)xml error:(NSError **)error
{
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData:xml 
                                                     options:0 
                                                       error:error];
	if (doc == nil) {
		return nil;
	}
    NSXMLElement *element = [doc rootElement];
    [element detach];
    return element;
}

- (void)processResponses
{
    while ( maxRidProcessed < [boshWindowManagerBosh maxRidReceived] ) 
    {
        ++maxRidProcessed;
        RequestResponsePairBosh *pair = [requestResponsePairs objectForLongLongKey:maxRidProcessed];
        NSAssert( [pair response], @"Processing nil response" );
        [self handleAttributesInResponse:[pair response]];
        [self broadcastStanzas:[pair response]];
        [requestResponsePairs removeObjectForLongLongKey:maxRidProcessed];
        if ( state == DISCONNECTED_BOSH )
        {
            [self handleDisconnection];
        }
    }
}

#define BoshTerminateConditionDomain @"BoshTerminateCondition"

- (void)handleAttributesInResponse:(NSXMLElement *)parsedResponse
{
    NSXMLNode *typeAttribute = [parsedResponse attributeForName:@"type"];
    if( typeAttribute != nil && [[typeAttribute stringValue] isEqualToString:@"terminate"] ) 
    {
        NSXMLNode *conditionNode = [parsedResponse attributeForName:@"condition"];
        if(conditionNode != nil) 
        {
            NSString *condition = [conditionNode stringValue];
            if( [condition isEqualToString:@"host-unknown"] )
                disconnectError_ = [[NSError alloc] initWithDomain:BoshTerminateConditionDomain
                                                              code:HOST_UNKNOWN userInfo:nil];
            else if ( [condition isEqualToString:@"host-gone"] ) 
                disconnectError_ = [[NSError alloc] initWithDomain:BoshTerminateConditionDomain
                                                              code:HOST_GONE userInfo:nil];
            else if( [condition isEqualToString:@"item-not-found"] )
                disconnectError_ = [[NSError alloc] initWithDomain:BoshTerminateConditionDomain
                                                              code:ITEM_NOT_FOUND userInfo:nil];
            else if ( [condition isEqualToString:@"policy-violation"] ) 
                disconnectError_ = [[NSError alloc] initWithDomain:BoshTerminateConditionDomain
                                                              code:POLICY_VIOLATION userInfo:nil];
            else if( [condition isEqualToString:@"remote-connection-failed"] )
                disconnectError_ = [[NSError alloc] initWithDomain:BoshTerminateConditionDomain
                                                              code:REMOTE_CONNECTION_FAILED userInfo:nil];
            else if ( [condition isEqualToString:@"bad-request"] ) 
                disconnectError_ = [[NSError alloc] initWithDomain:BoshTerminateConditionDomain
                                                              code:BAD_REQUEST userInfo:nil];
            else if( [condition isEqualToString:@"internal-server-error"] )
                disconnectError_ = [[NSError alloc] initWithDomain:BoshTerminateConditionDomain
                                                              code:INTERNAL_SERVER_ERROR userInfo:nil];
            else if ( [condition isEqualToString:@"remote-stream-error"] ) 
                disconnectError_ = [[NSError alloc] initWithDomain:BoshTerminateConditionDomain
                                                              code:REMOTE_STREAM_ERROR userInfo:nil];
            else if ( [condition isEqualToString:@"undefined-condition"] ) 
                disconnectError_ = [[NSError alloc] initWithDomain:BoshTerminateConditionDomain
                                                              code:UNDEFINED_CONDITION userInfo:nil];
            else NSAssert( false, @"Terminate Condition Not Valid");
        }
        state = DISCONNECTED_BOSH;
    }
    else if( !self.sid )
    {
        [self createSessionResponseHandler:parsedResponse];
    }
}

- (void)disconnect
{
    /*if(state != CONNECTED_BOSH && state != CONNECTING_BOSH )
    {
        //DDLogError(@"BOSH: Need to be connected to disconnect");
        return;
    }
    //DDLogInfo(@"Bosh: Will Terminate Session");
    state = DISCONNECTING_BOSH;
    //[multicastDelegate transportWillDisconnect:self];
    [self trySendingStanzas];*/
    NSMutableDictionary *attr = [NSMutableDictionary dictionaryWithObjectsAndKeys: @"terminate", @"type", nil];
    [self makeAndSendHTTPRequestWithPayload:nil attributes:attr namespaces:nil];
}

- (void)createSessionResponseHandler:(NSXMLElement *)parsedResponse
{
    NSArray *responseAttributes = [parsedResponse attributes];
    
    /* Setting inactivity, sid, wait, hold, lang, authid, secure, requests */
    for(NSXMLNode *attr in responseAttributes)
    {
        NSString *attrName = [attr name];
        NSString *attrValue = [attr stringValue];
        SEL setter = [self setterForProperty:attrName];
        
        if([self respondsToSelector:setter]) 
        {
            [self performSelector:setter withObject:attrValue];
        }
    }
    
    /* Not doing anything with namespaces right now - because chirkut doesn't send it */
    //NSArray *responseNamespaces = [rootElement namespaces];
    
    if ( state == CONNECTING_BOSH ) {
        state = CONNECTED_BOSH;
        //[multicastDelegate transportDidConnect:self];
        [self transportDidConnect];
        //[multicastDelegate transportDidStartNegotiation:self];
    }
}

- (void)handleDisconnection
{
    //if(self.disconnectError != nil)
    {
        //[multicastDelegate transportWillDisconnect:self withError:self.disconnectError];
        //[disconnectError_ release];
        //self.disconnectError = nil;
    }
    [pendingXMPPStanzas removeAllObjects];
    state = DISCONNECTED_BOSH;
    //for (ASIHTTPRequest *request in pendingHTTPRequests_) 
    {
        //DDLogWarn(@"Cancelling pending request with rid = %qi", [self getRidFromRequest:request]);
        //[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(resendRequest:) object:request];
        //[request clearDelegatesAndCancel];
    }
    [pendingHTTPRequests_ removeAllObjects];
    //[multicastDelegate transportDidDisconnect:self];
}

- (NSXMLElement *)newRootElement
{
    NSString *streamNamespaceURI = @"http://etherx.jabber.org/streams";
    NSXMLElement *element = [[NSXMLElement alloc] initWithName:@"stream" URI:streamNamespaceURI];
    [element addNamespaceWithPrefix:@"stream" stringValue:streamNamespaceURI];
    [element addNamespaceWithPrefix:@"" stringValue:@"jabber:client"];
    return element;
}

/* Implemet this as well */
- (float)serverXmppStreamVersionNumber
{
    return 1.0;
}

-(void)transportDidConnect
{
    rootElement = [self newRootElement];
    // Check for RFC compliance
    if([self serverXmppStreamVersionNumber] >= 1.0)
    {
        // Update state - we're now onto stream negotiations
        stream_state = STATE_NEGOTIATING;
        
        // Note: We're waiting for the <stream:features> now
    }
    else
    {
        // The server isn't RFC comliant, and won't be sending any stream features.
        
        // We would still like to know what authentication features it supports though,
        // so we'll use the jabber:iq:auth namespace, which was used prior to the RFC spec.
        
        // Update state - we're onto psuedo negotiation
        stream_state = STATE_NEGOTIATING;
        
        NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:auth"];
        
        NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
        [iq addAttributeWithName:@"type" stringValue:@"get"];
        [iq addChild:query];
        
        [self sendStanza:iq];
        
        // Now wait for the response IQ
    }
}

- (BOOL)sendStanza:(NSXMLElement *)stanza
{
    if (self.isPaused)
    {
        //DDLogError(@"BOSH: Need to unpaused to be able to send stanza");
        return NO;
    }
    if (![self isConnected])
    {
        //DDLogError(@"BOSH: Need to be connected to be able to send stanza");
        return NO;
    }
    //[multicastDelegate transport:self willSendStanza:stanza];
    [pendingXMPPStanzas addObject:stanza];
    [self trySendingStanzas];
    //[multicastDelegate transport:self didSendStanza:stanza];
    return YES;
}

- (BOOL)isConnected
{
    return state == CONNECTED_BOSH;
}

enum XMPPStreamFlags
{
kP2PInitiator                 = 1 << 0,  // If set, we are the P2P initializer
kIsSecure                     = 1 << 1,  // If set, connection has been secured via SSL/TLS
kIsAuthenticated              = 1 << 2,  // If set, authentication has succeeded
kDidStartNegotiation          = 1 << 3,  // If set, negotiation has started at least once
};

enum XMPPStreamConfig
{
kP2PMode                      = 1 << 0,  // If set, the XMPPStream was initialized in P2P mode
kResetByteCountPerConnection  = 1 << 1,  // If set, byte count should be reset per connection
#if TARGET_OS_IPHONE
kEnableBackgroundingOnSocket  = 1 << 2,  // If set, the VoIP flag should be set on the socket
#endif
};

/**
 * Returns YES if SSL/TLS has been used to secure the connection.
 **/
- (BOOL)isSecure
{
	return (flags & kIsSecure) ? YES : NO;
}
- (void)setIsSecure:(BOOL)flag
{
	if(flag)
		flags |= kIsSecure;
	else
		flags &= ~kIsSecure;
}

- (void)restartStream
{
    if (self.isPaused)
    {
        //DDLogError(@"BOSH: Need to be unpaused to restart the stream.");
        return;
    }
    if(![self isConnected])
    {
        //DDLogError(@"BOSH: Need to be connected to restart the stream.");
        return ;
    }
    //DDLogVerbose(@"Bosh: Will Restart Stream");
    NSMutableDictionary *attr = [NSMutableDictionary dictionaryWithObjectsAndKeys: @"true", @"xmpp:restart", nil];
    NSMutableDictionary *ns = [NSMutableDictionary dictionaryWithObjectsAndKeys:XMPP_NS, @"xmpp", nil];
    [self makeBodyAndSendHTTPRequestWithPayload:nil attributes:attr namespaces:ns];
}

- (BOOL)isAuthenticated
{
	return (flags & kIsAuthenticated) ? YES : NO;
}
- (void)setIsAuthenticated:(BOOL)flag
{
	if(flag)
		flags |= kIsAuthenticated;
	else
		flags &= ~kIsAuthenticated;
}

/*
 For each received stanza the client might send out packets.
 We should ideally put all the request in the queue and call
 processRequestQueue with a timeOut.
 */ 
- (NSXMLElement *)broadcastStanzas:(NSXMLNode *)body
{
    while ([body childCount] > 0) {
        NSXMLNode *node = [body childAtIndex:0];
        if ([node isKindOfClass:[NSXMLElement class]]) {
            [node detach];
            //[multicastDelegate transport:self didReceiveStanza:(NSXMLElement *)node];
            return [self transportDidReceiveStanza:(NSXMLElement *)node];
        }
    }
}

- (void)handleRegistration:(NSXMLElement *)response
{
	if([[[response attributeForName:@"type"] stringValue] isEqualToString:@"error"])
	{
		// Revert back to connected state (from authenticating state)
		stream_state = STATE_CONNECTED;
		
		//[multicastDelegate xmppBoshStream:self didNotRegister:response];
	}
	else
	{
		// Revert back to connected state (from authenticating state)
		stream_state = STATE_CONNECTED;
		
		//[multicastDelegate xmppBoshStreamDidRegister:self];
	}
}

- (BOOL)supportsDigestMD5Authentication
{
	// The root element can be properly queried for authentication mechanisms anytime after the
	// stream:features are received, and TLS has been setup (if required)
	if (stream_state > STATE_STARTTLS)
	{
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		NSXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
		
		NSArray *mechanisms = [mech elementsForName:@"mechanism"];
		
		for (NSXMLElement *mechanism in mechanisms)
		{
			if ([[mechanism stringValue] isEqualToString:@"DIGEST-MD5"])
			{
				return YES;
			}
		}
	}
	return NO;
}

- (BOOL)supportsPlainAuthentication
{
	// The root element can be properly queried for authentication mechanisms anytime after the
	//stream:features are received, and TLS has been setup (if required)
	//if (stream_state > STATE_STARTTLS)
	{
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		NSXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
		
		NSArray *mechanisms = [mech elementsForName:@"mechanism"];
		
		for (NSXMLElement *mechanism in mechanisms)
		{
			if ([[mechanism stringValue] isEqualToString:@"PLAIN"])
			{
				return YES;
			}
		}
	}
	return NO;
}

/**
 * After the authenticateUser:withPassword:resource method is invoked, a authentication message is sent to the server.
 * If the server supports digest-md5 sasl authentication, it is used.  Otherwise plain sasl authentication is used,
 * assuming the server supports it.
 * 
 * Now if digest-md5 was used, we sent a challenge request, and we're waiting for a challenge response.
 * If plain sasl was used, we sent our authentication information, and we're waiting for a success response.
 **/
- (void)handleAuth1:(NSXMLElement *)response
{
	if([self supportsDigestMD5Authentication])
	{
		// We're expecting a challenge response
		// If we get anything else we can safely assume it's the equivalent of a failure response
		if(![[response name] isEqualToString:@"challenge"])
		{
			// Revert back to connected state (from authenticating state)
			stream_state = STATE_CONNECTED;
			
			//[multicastDelegate xmppBoshStream:self didNotAuthenticate:response];
		}
		else
		{
			// Create authentication object from the given challenge
			// We'll release this object at the end of this else block
			/*XMPPDigestAuthentication *auth = [[XMPPDigestAuthentication alloc] initWithChallenge:response];
			
			NSString *virtualHostName = [self.myJID domain];
			
			// Sometimes the realm isn't specified
			// In this case I believe the realm is implied as the virtual host name
            // Note: earlier, in case the virtual host name was not set, the server host name was used.
            // However with the introduction of BOSH, we can't always know the server host name,
            // so we rely only on virtual hostnames for auth realm and digest URI.
			if (![auth realm])
			{
                [auth setRealm:virtualHostName];
			}
			
			// Set digest-uri
            [auth setDigestURI:[NSString stringWithFormat:@"xmpp/%@", virtualHostName]];
			
			// Set username and password
			[auth setUsername:[myJID user] password:tempPassword];
			
			// Create and send challenge response element
			NSXMLElement *cr = [NSXMLElement elementWithName:@"response" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			[cr setStringValue:[auth base64EncodedFullResponse]];
			
            [transport sendStanza:cr];
            
			// Release unneeded resources
			[auth release];
			[tempPassword release]; tempPassword = nil;
			
			// Update state
			state = STATE_AUTH_2;*/
		}
	}
	else if([self supportsPlainAuthentication])
	{
		// We're expecting a success response
		// If we get anything else we can safely assume it's the equivalent of a failure response
		if(![[response name] isEqualToString:@"success"])
		{
			// Revert back to connected state (from authenticating state)
			stream_state = STATE_CONNECTED;
			
			//[multicastDelegate xmppBoshStream:self didNotAuthenticate:response];
		}
		else
		{
			// We are successfully authenticated (via sasl:plain)
			[self setIsAuthenticated:YES];
			stream_state = STATE_NEGOTIATING;
			
			// Now we start our negotiation over again...
			[self restartStream];
		}
	}
	else
	{
		// We used the old fashioned jabber:iq:auth mechanism
		
		if([[[response attributeForName:@"type"] stringValue] isEqualToString:@"error"])
		{
			// Revert back to connected state (from authenticating state)
			stream_state = STATE_CONNECTED;
			
			//[multicastDelegate xmppBoshStream:self didNotAuthenticate:response];
		}
		else
		{
			// We are successfully authenticated (via non-sasl:digest)
			// And we've binded our resource as well
			[self setIsAuthenticated:YES];
			
			// Revert back to connected state (from authenticating state)
			stream_state = STATE_CONNECTED;
			
			//[multicastDelegate xmppBoshStreamDidAuthenticate:self];
            XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
            [self sendElement:presence];
		}
	}
}

/**
 * Private method.
 * Presencts a common method for the various public sendElement methods.
 **/
- (void)sendElement:(NSXMLElement *)element withTag:(long)tag
{
	if ([element isKindOfClass:[XMPPIQ class]])
	{
		//[multicastDelegate xmppStream:self willSendIQ:(XMPPIQ *)element];
	}
	else if ([element isKindOfClass:[XMPPMessage class]])
	{
		//[multicastDelegate xmppStream:self willSendMessage:(XMPPMessage *)element];
	}
	else if ([element isKindOfClass:[XMPPPresence class]])
	{
		//[multicastDelegate xmppStream:self willSendPresence:(XMPPPresence *)element];
	}
	else
	{
		NSString *elementName = [element name];
		
		if ([elementName isEqualToString:@"iq"])
		{
			//[multicastDelegate xmppStream:self willSendIQ:[XMPPIQ iqFromElement:element]];
		}
		else if ([elementName isEqualToString:@"message"])
		{
			//[multicastDelegate xmppStream:self willSendMessage:[XMPPMessage messageFromElement:element]];
		}
		else if ([elementName isEqualToString:@"presence"])
		{
			//[multicastDelegate xmppStream:self willSendPresence:[XMPPPresence presenceFromElement:element]];
		}
	}
	
    [self sendStanza:element];
	
	if ([element isKindOfClass:[XMPPIQ class]])
	{
		//[multicastDelegate xmppStream:self didSendIQ:(XMPPIQ *)element];
	}
	else if ([element isKindOfClass:[XMPPMessage class]])
	{
		//[multicastDelegate xmppStream:self didSendMessage:(XMPPMessage *)element];
	}
	else if ([element isKindOfClass:[XMPPPresence class]])
	{
		//[multicastDelegate xmppStream:self didSendPresence:(XMPPPresence *)element];
	}
}

- (void)sendElement:(NSXMLElement *)element
{
	if (state == STATE_CONNECTED)
	{
		[self sendElement:element withTag:0];
	}
}

- (void)handleStartSessionResponse:(NSXMLElement *)response
{
	if([[[response attributeForName:@"type"] stringValue] isEqualToString:@"result"])
	{
		// Revert back to connected state (from start session state)
		stream_state = STATE_CONNECTED;
		
		//[multicastDelegate xmppStreamDidAuthenticate:self];
        XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
        [self sendElement:presence];
	}
	else
	{
		// Revert back to connected state (from start session state)
		stream_state = STATE_CONNECTED;
		
		//[multicastDelegate xmppStream:self didNotAuthenticate:response];
	}
}

- (NSXMLElement *)handleBindingAndReturn:(NSXMLElement *)response
{
    NSXMLElement *r_bind = [response elementForName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
	NSXMLElement *r_jid = [r_bind elementForName:@"jid"];
	
	if(r_jid)
	{
		// We're properly binded to a resource now
		// Extract and save our resource (it may not be what we originally requested)
		NSString *fullJIDStr = [r_jid stringValue];
		
		self.myJID = [XMPPJID jidWithString:fullJIDStr];
		
		// And we may now have to do one last thing before we're ready - start an IM session
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		
		// Check to see if a session is required
		// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
		NSXMLElement *f_session = [features elementForName:@"session" xmlns:@"urn:ietf:params:xml:ns:xmpp-session"];
		
		if(f_session)
		{
			NSXMLElement *session = [NSXMLElement elementWithName:@"session"];
			[session setXmlns:@"urn:ietf:params:xml:ns:xmpp-session"];
			
			NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
			[iq addAttributeWithName:@"type" stringValue:@"set"];
			[iq addChild:session];
			
            //[self sendStanza:iq];
            [pendingXMPPStanzas removeAllObjects];
            [pendingXMPPStanzas addObject:iq];
            return  [self makeAndSendHTTPRequestWithPayload:pendingXMPPStanzas attributes:nil namespaces:nil];

		}
		else
		{
			// Revert back to connected state (from binding state)
			stream_state = STATE_CONNECTED;
			
			//[multicastDelegate xmppStreamDidAuthenticate:self];
            XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
            //[self sendElement:presence];
            [pendingXMPPStanzas removeAllObjects];
            [pendingXMPPStanzas addObject:presence];
            return  [self makeAndSendHTTPRequestWithPayload:pendingXMPPStanzas attributes:nil namespaces:nil];

		}
	}
	else
	{
		// It appears the server didn't allow our resource choice
		// We'll simply let the server choose then
		
		NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
		
		NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
		[iq addAttributeWithName:@"type" stringValue:@"set"];
		[iq addChild:bind];
		
		//[self sendStanza:iq];
        [pendingXMPPStanzas removeAllObjects];
        [pendingXMPPStanzas addObject:iq];
        return  [self makeAndSendHTTPRequestWithPayload:pendingXMPPStanzas attributes:nil namespaces:nil];

		// The state remains in STATE_BINDING
	}
}

- (void)handleBinding:(NSXMLElement *)response
{
	NSXMLElement *r_bind = [response elementForName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
	NSXMLElement *r_jid = [r_bind elementForName:@"jid"];
	
	if(r_jid)
	{
		// We're properly binded to a resource now
		// Extract and save our resource (it may not be what we originally requested)
		NSString *fullJIDStr = [r_jid stringValue];
		
		self.myJID = [XMPPJID jidWithString:fullJIDStr];
		
		// And we may now have to do one last thing before we're ready - start an IM session
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		
		// Check to see if a session is required
		// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
		NSXMLElement *f_session = [features elementForName:@"session" xmlns:@"urn:ietf:params:xml:ns:xmpp-session"];
		
		if(f_session)
		{
			NSXMLElement *session = [NSXMLElement elementWithName:@"session"];
			[session setXmlns:@"urn:ietf:params:xml:ns:xmpp-session"];
			
			NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
			[iq addAttributeWithName:@"type" stringValue:@"set"];
			[iq addChild:session];
			
            [self sendStanza:iq];
			// Update state
			stream_state = STATE_START_SESSION;
		}
		else
		{
			// Revert back to connected state (from binding state)
			stream_state = STATE_CONNECTED;
			
			//[multicastDelegate xmppStreamDidAuthenticate:self];
            XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
            [self sendElement:presence];
		}
	}
	else
	{
		// It appears the server didn't allow our resource choice
		// We'll simply let the server choose then
		
		NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
		
		NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
		[iq addAttributeWithName:@"type" stringValue:@"set"];
		[iq addChild:bind];
		
		[self sendStanza:iq];
		// The state remains in STATE_BINDING
	}
}

-(NSXMLElement *)transportDidReceiveStanza:(NSXMLElement *)node
{
	NSString *elementName = [node name];
    
	if([elementName isEqualToString:@"stream:error"] || [elementName isEqualToString:@"error"])
	{
		//[multicastDelegate xmppBoshStream:self didReceiveError:element];
		return nil;
	}
    
	if(stream_state == STATE_NEGOTIATING)
	{
		// We've just read in the stream features
		// We consider this part of the root element, so we'll add it (replacing any previously sent features)
		[rootElement setChildren:[NSArray arrayWithObject:node]];
		
		// Call a method to handle any requirements set forth in the features
		//[self handleStreamFeatures];
        return [self handleStreamFeaturesAndReturn];
	}
	else if(stream_state == STATE_STARTTLS)
	{
		// The response from our starttls message
		[self handleStartTLSResponse:node];
	}
	else if(stream_state == STATE_REGISTERING)
	{
		// The iq response from our registration request
		[self handleRegistration:node];
	}
	else if(stream_state == STATE_AUTH_1)
	{
		// The challenge response from our auth message
		[self handleAuth1:node];
	}
	else if(stream_state == STATE_AUTH_2)
	{
		// The response from our challenge response
		//[self handleAuth2:node];
	}
	else if(stream_state == STATE_AUTH_3)
	{
		// The response from our x-facebook-platform or authenticateAnonymously challenge
		//[self handleAuth3:node];
	}
	else if(stream_state == STATE_BINDING)
	{
		// The response from our binding request
		//[self handleBinding:node];
        return [self handleBindingAndReturn:node];
	}
	else if(stream_state == STATE_START_SESSION)
	{
		// The response from our start session request
		[self handleStartSessionResponse:node];
	}
	else
	{
		if([elementName isEqualToString:@"iq"])
		{
			XMPPIQ *iq = [XMPPIQ iqFromElement:node];
			
			BOOL responded = NO;
			
			/*GCDMulticastDelegateEnumerator *delegateEnumerator = [multicastDelegate delegateEnumerator];
			id delegate;
			SEL selector = @selector(xmppStream:didReceiveIQ:);
			dispatch_queue_t dq;
			//while((delegate = [delegateEnumerator nextDelegateForSelector:selector]))
            while ([delegateEnumerator getNextDelegate:&delegate delegateQueue:&dq forSelector:selector]) 
			{
                dispatch_sync(dq, ^{ @autoreleasepool {
					
                    [delegate xmppBoshStream:self willSendIQ:iq];
					
				}});
                
				//BOOL delegateDidRespond = [delegate xmppBoshStream:self didReceiveIQ:iq];
				
				//responded = responded || delegateDidRespond;
			}*/
			
			// An entity that receives an IQ request of type "get" or "set" MUST reply
			// with an IQ response of type "result" or "error".
			// 
			// The response MUST preserve the 'id' attribute of the request.
			
			if (!responded && [iq requiresResponse])
			{
				// Return error message:
				// 
				// <iq to="jid" type="error" id="id">
				//   <query xmlns="ns"/>
				//   <error type="cancel" code="501">
				//     <feature-not-implemented xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/>
				//   </error>
				// </iq>
				
				NSXMLElement *reason = [NSXMLElement elementWithName:@"feature-not-implemented"
				                                               xmlns:@"urn:ietf:params:xml:ns:xmpp-stanzas"];
				
				NSXMLElement *error = [NSXMLElement elementWithName:@"error"];
				[error addAttributeWithName:@"type" stringValue:@"cancel"];
				[error addAttributeWithName:@"code" stringValue:@"501"];
				[error addChild:reason];
				
				XMPPIQ *iqResponse = [XMPPIQ iqWithType:@"error" to:[iq from] elementID:[iq elementID] child:error];
				
				NSXMLElement *iqChild = [iq childElement];
				if (iqChild)
				{
					NSXMLNode *iqChildCopy = [iqChild copy];
					[iqResponse insertChild:iqChildCopy atIndex:0];
				}
				
				[self sendElement:iqResponse];
			}
		}
		else if([elementName isEqualToString:@"message"])
		{
			//[multicastDelegate xmppBoshStream:self didReceiveMessage:[XMPPMessage messageFromElement:element]];
		}
		else if([elementName isEqualToString:@"presence"])
		{
			//[multicastDelegate xmppBoshStream:self didReceivePresence:[XMPPPresence presenceFromElement:element]];
		}
		/*else if([self isP2P] &&
                ([elementName isEqualToString:@"stream:features"] || [elementName isEqualToString:@"features"]))
		{
			//[multicastDelegate xmppBoshStream:self didReceiveP2PFeatures:element];
		}*/
		else
		{
			//[multicastDelegate xmppBoshStream:self didReceiveError:element];
		}
	}    
    return nil;
}

/**
 * This method is called anytime we receive the server's stream features.
 * This method looks at the stream features, and handles any requirements so communication can continue.
 **/
- (void)handleStreamFeatures
{
	// Extract the stream features
	NSXMLElement *features = [rootElement elementForName:@"stream:features"];
	
	// Check to see if TLS is required
	// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
	NSXMLElement *f_starttls = [features elementForName:@"starttls" xmlns:@"urn:ietf:params:xml:ns:xmpp-tls"];
	
	if (f_starttls)
	{
		if ([f_starttls elementForName:@"required"])
		{
			// TLS is required for this connection
			
			// Update state
			stream_state = STATE_STARTTLS;
			
			// Send the startTLS XML request
			[self sendStartTLSRequest];
			
			// We do not mark the stream as secure yet.
			// We're waiting to receive the <proceed/> response from the
			// server before we actually start the TLS handshake.
			
			// We're already listening for the response...
			return;
		}
	}
	
	// Check to see if resource binding is required
	// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
	NSXMLElement *f_bind = [features elementForName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
	
	if ([self isAuthenticated] && f_bind)
	{
		// Binding is required for this connection
		stream_state = STATE_BINDING;
		
		NSString *requestedResource = [self.myJID resource];
		
		if ([requestedResource length] > 0)
		{
			// Ask the server to bind the user specified resource
			
			NSXMLElement *resource = [NSXMLElement elementWithName:@"resource"];
			[resource setStringValue:requestedResource];
			
			NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
			[bind addChild:resource];
			
			NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
			[iq addAttributeWithName:@"type" stringValue:@"set"];
			[iq addChild:bind];
			
            [self sendStanza:iq];
		}
		else
		{
			// The user didn't specify a resource, so we ask the server to bind one for us
			
			NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
			
			NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
			[iq addAttributeWithName:@"type" stringValue:@"set"];
			[iq addChild:bind];
			
            [self sendStanza:iq];
		}
		
		// We're already listening for the response...
		return;
	}
	
	// It looks like all has gone well, and the connection should be ready to use now
	stream_state = STATE_CONNECTED;
	
	if (![self isAuthenticated])
	{
		// Notify delegates
		//[multicastDelegate xmppBoshStreamDidConnect:self];
        NSError *error = nil;
        [self authenticateWithPassword:self.password error:&error];
	}
}

- (void)handleStartTLSResponse:(NSXMLElement *)response
{
	// We're expecting a proceed response
	// If we get anything else we can safely assume it's the equivalent of a failure response
	if(![[response name] isEqualToString:@"proceed"])
	{
		// We can close our TCP connection now
		[self disconnect];
		
		// The onSocketDidDisconnect: method will handle everything else
		return;
	}
	
	// Start TLS negotiation
	[self secure];
	
	// Make a note of the switch to TLS
	[self setIsSecure:YES];
}

- (void)sendStartTLSRequest
{
	NSString *starttls = @"<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>";
	[self sendStanzaWithString:starttls];
}

- (NSXMLElement *)parseXMLString:(NSString *)xml
{
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:xml
                                                          options:0
                                                            error:NULL];
    NSXMLElement *element = [doc rootElement];
    [element detach];
    return element;
}


- (BOOL)sendStanzaWithString:(NSString *)string
{
    NSXMLElement *payload = [self parseXMLString:string];
    return [self sendStanza:payload];
}

+ (NSString *)generateUUID
{
	NSString *result = nil;
	
	CFUUIDRef uuid = CFUUIDCreate(NULL);
	if (uuid)
	{
		result = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
		CFRelease(uuid);
	}
	
	return result;
}

- (NSString *)generateUUID
{
	return [[self class] generateUUID];
}

- (NSXMLElement *)authenticateWithPassword:(NSString *)password1
{
    if ([self supportsDigestMD5Authentication])
	{
		NSString *auth = @"<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='DIGEST-MD5'/>";
        [self sendStanzaWithString:auth];
        NSXMLElement *payload = [self parseXMLString:auth];
        return payload;
		tempPassword = password1;
	}
	else if ([self supportsPlainAuthentication])
	{
		NSString *username = [self.myJID user];
		
		NSString *payload = [NSString stringWithFormat:@"%C%@%C%@", 0, username, 0, password1];
		NSString *base64 = [[payload dataUsingEncoding:NSUTF8StringEncoding] base64Encoded];
		
		NSXMLElement *auth = [NSXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
		[auth addAttributeWithName:@"mechanism" stringValue:@"PLAIN"];
		[auth setStringValue:base64];
        return auth;
	}
	else
	{
		// The server does not appear to support SASL authentication (at least any type we can use)
		// So we'll revert back to the old fashioned jabber:iq:auth mechanism
		
		NSString *username = [self.myJID user];
		NSString *resource = [self.myJID resource];
		
		if ([resource length] == 0)
		{
			// If resource is nil or empty, we need to auto-create one
			
			resource = [self generateUUID];
		}
		
		NSXMLElement *queryElement = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:auth"];
		[queryElement addChild:[NSXMLElement elementWithName:@"username" stringValue:username]];
		[queryElement addChild:[NSXMLElement elementWithName:@"resource" stringValue:resource]];
		
		/*if ([self supportsDeprecatedDigestAuthentication])
         {
         NSString *rootID = [[[self rootElement] attributeForName:@"id"] stringValue];
         NSString *digestStr = [NSString stringWithFormat:@"%@%@", rootID, password];
         NSData *digestData = [digestStr dataUsingEncoding:NSUTF8StringEncoding];
         
         NSString *digest = [[digestData sha1Digest] hexStringValue];
         
         [queryElement addChild:[NSXMLElement elementWithName:@"digest" stringValue:digest]];
         }
         else
         {
         [queryElement addChild:[NSXMLElement elementWithName:@"password" stringValue:password]];
         }*/
		
		NSXMLElement *iqElement = [NSXMLElement elementWithName:@"iq"];
		[iqElement addAttributeWithName:@"type" stringValue:@"set"];
		[iqElement addChild:queryElement];
        return iqElement;
	}
    return nil;
}
/**
 * This method attempts to sign-in to the server using the configured myJID and given password.
 * If this method immediately fails
 **/
- (BOOL)authenticateWithPassword:(NSString *)password1 error:(NSError **)errPtr
{
	if (stream_state != STATE_CONNECTED)
	{
		if (errPtr)
		{
			NSString *errMsg = @"Please wait until the stream is connected.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidState userInfo:info];
		}
		return NO;
	}
	
	if (self.myJID == nil)
	{
		if (errPtr)
		{
			NSString *errMsg = @"You must set myJID before calling authenticateWithPassword:error:.";
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			
			*errPtr = [NSError errorWithDomain:XMPPStreamErrorDomain code:XMPPStreamInvalidProperty userInfo:info];
		}
		return NO;
	}
	
	if ([self supportsDigestMD5Authentication])
	{
		NSString *auth = @"<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='DIGEST-MD5'/>";
        [self sendStanzaWithString:auth];
		
		// Save authentication information
		tempPassword = password1;
		
		// Update state
		stream_state = STATE_AUTH_1;
	}
	else if ([self supportsPlainAuthentication])
	{
		// From RFC 4616 - PLAIN SASL Mechanism:
		// [authzid] UTF8NUL authcid UTF8NUL passwd
		// 
		// authzid: authorization identity
		// authcid: authentication identity (username)
		// passwd : password for authcid
		
		NSString *username = [self.myJID user];
		
		NSString *payload = [NSString stringWithFormat:@"%C%@%C%@", 0, username, 0, password1];
		NSString *base64 = [[payload dataUsingEncoding:NSUTF8StringEncoding] base64Encoded];
		
		NSXMLElement *auth = [NSXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
		[auth addAttributeWithName:@"mechanism" stringValue:@"PLAIN"];
		[auth setStringValue:base64];
		
		// Update state
		stream_state = STATE_AUTH_1;
		
        [self sendStanza:auth];
	}
	else
	{
		// The server does not appear to support SASL authentication (at least any type we can use)
		// So we'll revert back to the old fashioned jabber:iq:auth mechanism
		
		NSString *username = [self.myJID user];
		NSString *resource = [self.myJID resource];
		
		if ([resource length] == 0)
		{
			// If resource is nil or empty, we need to auto-create one
			
			resource = [self generateUUID];
		}
		
		NSXMLElement *queryElement = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:auth"];
		[queryElement addChild:[NSXMLElement elementWithName:@"username" stringValue:username]];
		[queryElement addChild:[NSXMLElement elementWithName:@"resource" stringValue:resource]];
		
		/*if ([self supportsDeprecatedDigestAuthentication])
		{
			NSString *rootID = [[[self rootElement] attributeForName:@"id"] stringValue];
			NSString *digestStr = [NSString stringWithFormat:@"%@%@", rootID, password];
			NSData *digestData = [digestStr dataUsingEncoding:NSUTF8StringEncoding];
			
			NSString *digest = [[digestData sha1Digest] hexStringValue];
			
			[queryElement addChild:[NSXMLElement elementWithName:@"digest" stringValue:digest]];
		}
		else
		{
			[queryElement addChild:[NSXMLElement elementWithName:@"password" stringValue:password]];
		}*/
		
		NSXMLElement *iqElement = [NSXMLElement elementWithName:@"iq"];
		[iqElement addAttributeWithName:@"type" stringValue:@"set"];
		[iqElement addChild:queryElement];
		
        [self sendStanza:iqElement];
        
		// Update state
		stream_state = STATE_AUTH_1;
	}
	
	return YES;
}

@end
