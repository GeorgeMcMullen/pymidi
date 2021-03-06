/*
    This software is distributed under the terms of Pete's Public License version 1.0, a
    copy of which is included with this software in the file "License.html".  A copy can
    also be obtained from http://pete.yandell.com/software/license/ppl-1_0.html
    
    If you did not receive a copy of the license with this software, please notify the
    author by sending e-mail to pete@yandell.com
    
    The current version of this software can be found at http://pete.yandell.com/software
     
    Copyright (c) 2002-2004 Peter Yandell.  All Rights Reserved.
    
    $Id: PYMIDIManager.h,v 1.11 2004/01/12 10:53:16 pete Exp $
*/


#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>


@class PYMIDIEndpointDescriptor;
@class PYMIDIEndpoint;


@interface PYMIDIManager : NSObject <NSNetServiceBrowserDelegate, NSNetServiceDelegate> {
    BOOL			notificationsEnabled;
    MIDIClientRef	midiClientRef;

    NSMutableArray*	realSourceArray;
    NSMutableArray* realDestinationArray;
    NSMutableDictionary* midiNetworkSessionServicesDict;

    NSNetServiceBrowser* midiNetworkBrowser;

    NSArray*		noteNamesArray;
}

+ (PYMIDIManager*)sharedInstance;

- (PYMIDIManager*)init;
- (void)dealloc;

- (MIDIClientRef)midiClientRef;

#pragma mark NOTIFICATION HANDLING

- (void)disableNotifications;
- (void)enableNotifications;

#pragma mark REAL MIDI SOURCES

- (NSArray*)realSources;
- (NSArray*)realSourcesOnlineOrInUse;
- (PYMIDIEndpoint*)realSourceWithName:(NSString *)name;
- (PYMIDIEndpoint*)realSourceWithDescriptor:(PYMIDIEndpointDescriptor*)descriptor;

#pragma mark REAL MIDI DESTINATIONS

- (NSArray*)realDestinations;
- (NSArray*)realDestinationsOnlineOrInUse;
- (PYMIDIEndpoint*)realDestinationWithName:(NSString *)name;
- (PYMIDIEndpoint*)realDestinationWithDescriptor:(PYMIDIEndpointDescriptor*)descriptor;

#pragma mark NETWORK ENDPOINTS

- (NSArray*)midiNetworkSessionServices;
- (NSArray*)midiNetworkSessionConnections;
- (NSNetService *)midiNetworkSessionServiceWithName:(NSString *)name;

#pragma mark - MIDINetworkSession CONNECTION MANAGEMENT
- (BOOL) midiNetworkSessionEnabled;
- (void) enableMIDINetworkSession;
- (void) disableMIDINetworkSession;
- (void) enableMIDINetworkSessionIncomingConnections;
- (void) disableMIDINetworkSessionIncomingConnections;
- (BOOL) midiNetworkSessionConnected;
- (NSString*) describeMIDINetworkSessionConnections;
- (BOOL) isConnected:(NSNetService*) service;
- (BOOL) connectToServiceManually:(NSNetService*) service;
- (BOOL) connectToService:(NSNetService*) service;
- (BOOL) disconnectFromService:(NSNetService*) service;
- (void) toggleConnected:(NSNetService*) service;

#pragma mark - NSNetServiceBrowserDelegate

- (void)startMIDINetworkBrowser;
- (void)stopMIDINetworkBrowser;

#pragma mark NOTE NAMES

- (NSString*)nameOfNote:(Byte)note;

@end