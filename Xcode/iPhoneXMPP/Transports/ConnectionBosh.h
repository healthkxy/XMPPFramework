//
//  ConnectionBosh.h
//  iPhoneXMPP
//
//  Created by 新勇 康 on 7/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMPPJID.h"

@interface ConnectionBosh : NSObject

@property (nonatomic, strong) XMPPJID *myJID;
@property (nonatomic, assign) unsigned int wait;
@property (nonatomic, assign) unsigned int hold;
@property (nonatomic, strong) NSString *domain;
@property (nonatomic, strong) NSString *routeProtocol;
@property (nonatomic, strong) NSString *host;
@property (nonatomic, assign) unsigned int port;
@property (nonatomic, assign) unsigned int inactivity;
@property (nonatomic, strong) NSString *sid;

-(id)initWithBoshServer:(NSString*)urlString xmppHost:(NSString*)xmppHost;
-(BOOL)connect:(NSError **)error;
@end
