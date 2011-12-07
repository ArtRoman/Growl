//
//  GNTPSubscriptionController.m
//  Growl
//
//  Created by Daniel Siemer on 11/21/11.
//  Copyright (c) 2011 The Growl Project. All rights reserved.
//

#import "GNTPSubscriptionController.h"
#import "GrowlPreferencesController.h"
#import "GrowlGNTPPacket.h"
#import "GrowlSubscribeGNTPPacket.h"
#import "GNTPSubscriberEntry.h"

#import "GrowlGNTPOutgoingPacket.h"
#import "GrowlGNTPDefines.h"
#import "GrowlNetworkUtilities.h"

#include <netinet/in.h>
#include <arpa/inet.h>

@implementation GNTPSubscriptionController

@synthesize remoteSubscriptions;
@synthesize localSubscriptions;
@synthesize subscriberID;

@synthesize preferences;

+ (GNTPSubscriptionController*)sharedController {
   static GNTPSubscriptionController *instance;
   static dispatch_once_t onceToken;
   dispatch_once(&onceToken, ^{
      instance = [[self alloc] init];
   });
   return instance;
}

-(id)init {
   if((self = [super init])) {
      self.preferences = [GrowlPreferencesController sharedController];
      
      self.subscriberID = [preferences GNTPSubscriberID];
      if(!subscriberID || [subscriberID isEqualToString:@""]) {
         self.subscriberID = [[NSProcessInfo processInfo] globallyUniqueString];
         [preferences setGNTPSubscriberID:subscriberID];
      }
      
      self.remoteSubscriptions = [NSMutableDictionary dictionary];
      __block NSMutableDictionary *blockRemote = self.remoteSubscriptions;
      NSArray *remoteItems = [preferences objectForKey:@"GrowlRemoteSubscriptions"];
      [remoteItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
         //init a subscriber item, check if its still valid, and add it
         GNTPSubscriberEntry *entry = [[GNTPSubscriberEntry alloc] initWithDictionary:obj];
         if([[NSDate date] compare:[NSDate dateWithTimeInterval:[entry timeToLive] sinceDate:[entry initialTime]]] != NSOrderedDescending)
            [blockRemote setValue:entry forKey:[entry subscriberID]];
         else
            [entry invalidate];
         [entry release];
      }];
      
      //We had some subscriptions that have lapsed, remove them
      if([[remoteSubscriptions allValues] count] < [remoteItems count])
         [self saveSubscriptions:YES];
      
      NSArray *localItems = [preferences objectForKey:@"GrowlLocalSubscriptions"];
      self.localSubscriptions = [NSMutableArray arrayWithCapacity:[localItems count]];
      __block NSMutableArray *blockLocal = self.localSubscriptions;
      [localItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
         GNTPSubscriberEntry *entry = [[GNTPSubscriberEntry alloc] initWithDictionary:obj];
         
         //If someone deleted the GNTPSubscriptionID key in the plist, this will make sure they got updated
         if(![[entry subscriberID] isEqualToString:subscriberID])
            [entry setSubscriberID:subscriberID];
            
         [blockLocal addObject:entry];
         if([entry use]){
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
               //attempt to renew the subscription with the remote machine, 
               [entry subscribe];
            });
         }
         [entry release];
      }];
      
      [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(appRegistered:)
                                                   name:@"ApplicationRegistered"
                                                 object:nil];
   }
   return self;
}

-(void)dealloc {
   [[NSNotificationCenter defaultCenter] removeObserver:self];
   [self saveSubscriptions:YES];
   [self saveSubscriptions:NO];
   [localSubscriptions release];
   [remoteSubscriptions release];
   [subscriberID release];
   [super dealloc];
}

-(void)saveSubscriptions:(BOOL)remote {
   NSString *saveKey;
   NSArray *toSave;
   if(remote) {
      toSave = [[[remoteSubscriptions allValues] copy] autorelease];
      saveKey = @"GrowlRemoteSubscriptions";
   } else {
      toSave = [[localSubscriptions copy] autorelease];
      saveKey = @"GrowlLocalSubscriptions";
   }
   NSMutableArray *saveItems = [NSMutableArray arrayWithCapacity:[toSave count]];
   [toSave enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
      [saveItems addObject:[obj dictionaryRepresentation]];
   }];
   
   [preferences setObject:saveItems forKey:saveKey];
}

-(BOOL)addRemoteSubscriptionFromPacket:(GrowlSubscribeGNTPPacket*)packet {
   if(![packet isKindOfClass:[GrowlSubscribeGNTPPacket class]])
      return NO;
   
   GNTPSubscriberEntry *entry = [remoteSubscriptions valueForKey:[packet subscriberID]];
   if(entry){
      //We need to update the entry
      [self willChangeValueForKey:@"remoteSubscriptionsArray"];
      [entry updateRemoteWithPacket:packet];
      [self didChangeValueForKey:@"remoteSubscriptionsArray"];
   }else{
      //We need to try creating the entry
      entry = [[GNTPSubscriberEntry alloc] initWithPacket:packet];
      [self willChangeValueForKey:@"remoteSubscriptionsArray"];
      [remoteSubscriptions setValue:entry forKey:[entry subscriberID]];
      [self didChangeValueForKey:@"remoteSubscriptionsArray"];
   }
   [self saveSubscriptions:YES];
   return YES;
}

-(void)updateLocalSubscriptionWithPacket:(GrowlGNTPPacket*)packet {
   /*
    * Update the appropriate local subscription item with its new TTL, and have it set its timer to fire appropriately
    */   
   __block GNTPSubscriberEntry *entry = nil;
   [localSubscriptions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
      if([[obj addressString] caseInsensitiveCompare:[packet connectedHost]] == NSOrderedSame){
         entry = obj;
      }
   }];
   
   if(!entry) {
      NSLog(@"Error: Cant find Local subscription entry for host: %@", [packet connectedHost]);
      return;
   }
   
   [entry updateLocalWithPacket:packet];
   [self saveSubscriptions:NO];
}

#pragma mark UI Related

-(void)newManualSubscription {
   GNTPSubscriberEntry *newEntry = [[GNTPSubscriberEntry alloc] initWithName:nil
                                                               addressString:nil
                                                                      domain:@"local."
                                                                     address:nil
                                                                        uuid:[[NSProcessInfo processInfo] globallyUniqueString]
                                                                subscriberID:subscriberID
                                                                      remote:NO
                                                                      manual:YES
                                                                         use:NO
                                                                 initialTime:[NSDate distantPast]
                                                                  timeToLive:0
                                                                        port:GROWL_TCP_PORT];
   [self willChangeValueForKey:@"localSubscriptions"];
   [localSubscriptions addObject:newEntry];
   [self didChangeValueForKey:@"localSubscriptions"];
}


-(BOOL)removeRemoteSubscriptionForUUID:(NSString*)uuid {
   [self willChangeValueForKey:@"remoteSubscriptionsArray"];
   [remoteSubscriptions removeObjectForKey:uuid];
   [self didChangeValueForKey:@"remoteSubscriptionsArray"];
   [self saveSubscriptions:YES];
   return YES;
}

-(BOOL)removeLocalSubscriptionAtIndex:(NSUInteger)index {
   if(index < [localSubscriptions count])
      return NO;
   [self willChangeValueForKey:@"localSubscriptions"];
   [localSubscriptions removeObjectAtIndex:index];
   [self didChangeValueForKey:@"localSubscriptions"];
   [self saveSubscriptions:NO];
   return YES;
}

#pragma mark Forwarding

-(NSString*)passwordForLocalSubscriber:(NSString*)host {
   __block NSString *password = nil;
   [localSubscriptions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
      if([[obj addressString] caseInsensitiveCompare:host] == NSOrderedSame){
         password = [obj password];
         //We do this so that the password will stick around long enough to be used by the caller
         password = [[password stringByAppendingString:[obj subscriberID]] retain];
         *stop = YES;
      }
   }];
   //However, it should still be autoreleased, just in the right area
   return [password autorelease];
}

-(void)forwardGrowlDict:(NSDictionary*)dict ofType:(GrowlGNTPOutgoingPacketType)type {
   if(![preferences isSubscriptionAllowed])
      return;

   [remoteSubscriptions enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
      GrowlGNTPOutgoingPacket *outgoingPacket = [GrowlGNTPOutgoingPacket outgoingPacketOfType:type
                                                                                      forDict:dict];
      GNTPKey *cryptoKey = [[GNTPKey alloc] initWithPassword:[NSString stringWithFormat:@"%@%@", [preferences remotePassword], [obj subscriberID]]
                                               hashAlgorithm:GNTPSHA512
                                         encryptionAlgorithm:GNTPNone];
      [outgoingPacket setKey:cryptoKey];
      NSData *coercedAddress = [GrowlNetworkUtilities addressData:[obj lastKnownAddress] coercedToPort:[obj subscriberPort]];
      dispatch_async(dispatch_get_main_queue(), ^{
         [[GrowlGNTPPacketParser sharedParser] sendPacket:outgoingPacket
                                                toAddress:coercedAddress];
      });
   }];
}

-(void)forwardNotification:(NSDictionary*)noteDict {
   [self forwardGrowlDict:noteDict ofType:GrowlGNTPOutgoingPacket_NotifyType];
}

/* Hande forwarding registrations */
-(void)appRegistered:(NSNotification*)note {
   [self forwardGrowlDict:[note userInfo] ofType:GrowlGNTPOutgoingPacket_RegisterType];
}

#pragma mark Table bindings accessor

-(NSArray*)remoteSubscriptionsArray
{
    return [remoteSubscriptions allValues];
}

@end