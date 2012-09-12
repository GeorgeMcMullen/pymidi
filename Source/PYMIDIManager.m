/*
    This software is distributed under the terms of Pete's Public License version 1.0, a
    copy of which is included with this software in the file "License.html".  A copy can
    also be obtained from http://pete.yandell.com/software/license/ppl-1_0.html
    
    If you did not receive a copy of the license with this software, please notify the
    author by sending e-mail to pete@yandell.com
    
    The current version of this software can be found at http://pete.yandell.com/software
     
    Copyright (c) 2002-2004 Peter Yandell.  All Rights Reserved.
    
    $Id: PYMIDIManager.m,v 1.14 2004/01/12 04:39:28 pete Exp $
*/


#ifdef PYMIDI_FRAMEWORK
    #import "PYMIDI/PYMIDIManager.h"

    #import <PYMIDI/PYMIDIUtils.h>
    #import <PYMIDI/PYMIDIEndpoint.h>
    #import <PYMIDI/PYMIDIEndpointSet.h>
    #import <PYMIDI/PYMIDIRealEndpoint.h>
    #import <PYMIDI/PYMIDIRealSource.h>
    #import <PYMIDI/PYMIDIRealDestination.h>
    #import <PYMIDI/PYMidiDefines.h>
#else
    #import "PYMIDIManager.h"

    #import "PYMIDIUtils.h"
    #import "PYMIDIEndpoint.h"
    #import "PYMIDIEndpointSet.h"
    #import "PYMIDIRealEndpoint.h"
    #import "PYMIDIRealSource.h"
    #import "PYMIDIRealDestination.h"
    #import "PYMidiDefines.h"
#endif

#import <CoreMIDI/MIDINetworkSession.h>
#import <UIKit/UIKit.h> // Requires check for UIKit vs. AppKit on OSX

@interface PYMIDIManager(Private)

- (void)processMIDINotification:(const MIDINotification*)message;

- (void)updateRealSources;
- (PYMIDIEndpoint*)realSourceWithMIDIEndpointRef:(MIDIEndpointRef)midiEndpointRef;
- (void)updateRealDestinations;
- (PYMIDIEndpoint*)realDestinationWithMIDIEndpointRef:(MIDIEndpointRef)midiEndpointRef;

- (void)buildNoteNamesArray;

@end


@implementation PYMIDIManager


static void midiNotifyProc (const MIDINotification* message, void* refCon);


+ (PYMIDIManager*)sharedInstance
{
    static PYMIDIManager* sharedInstance = nil;

    if (sharedInstance == nil) sharedInstance = [[PYMIDIManager alloc] init];
    
    return sharedInstance;
}


- (PYMIDIManager*)init
{
    if (self = [super init]) {
        notificationsEnabled = NO;
        
        OSStatus err = MIDIClientCreate (CFSTR(MIDI_MANAGER), midiNotifyProc, (void*)self, &midiClientRef);
        if (err != noErr) {
            NSLog(@"Error creating MIDI client: %ld", err);
            [self release];
            return nil;
        }

        [self enableMIDINetworkSession];
        [self startMIDINetworkBrowser];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(processNetworkMIDINotification:)
                                                     name:MIDINetworkNotificationSessionDidChange
                                                   object:[MIDINetworkSession defaultSession]];


        realSourceArray = [[NSMutableArray alloc] init];
        realDestinationArray = [[NSMutableArray alloc] init];
        midiNetworkSessionServicesDict = [[NSMutableDictionary alloc] init];

        [self updateRealSources];
        [self updateRealDestinations];

        [self buildNoteNamesArray];
        
        notificationsEnabled = YES;
    }
    return self;
}


- (void)dealloc
{
    [self stopMIDINetworkBrowser];
    [realSourceArray release];
    [realDestinationArray release];
    [midiNetworkSessionServicesDict release];
    
    [noteNamesArray release];
    
    [super dealloc];
}


- (MIDIClientRef)midiClientRef
{
    return midiClientRef;
}



#pragma mark NOTIFICATION HANDLING


- (void)disableNotifications
{
    notificationsEnabled = NO;
}

- (void)enableNotifications
{
    notificationsEnabled = YES;
}


- (void)processMIDINotification:(const MIDINotification*)message
{
    static BOOL isHandlingNotification = NO;
    static BOOL shouldRetryWhenDone    = NO;
    
    if (isHandlingNotification) {
        shouldRetryWhenDone = YES;
        return;
    }
    
    do {
        isHandlingNotification = YES;
        shouldRetryWhenDone    = NO;
        
        switch (message->messageID) {
        case kMIDIMsgSetupChanged:
            if (notificationsEnabled) {
                [self updateRealSources];
                [self updateRealDestinations];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"PYMIDISetupChanged" object:self];
            }
            break;
        }
        
        isHandlingNotification = NO;
    } while (shouldRetryWhenDone);
}


static void
midiNotifyProc (const MIDINotification* message, void* refCon)
{
    PYMIDIManager* manager = (PYMIDIManager*)refCon;
    [manager processMIDINotification:message];
}



#pragma mark REAL MIDI SOURCES


- (void)updateRealSources
{
    NSEnumerator*			enumerator;
    PYMIDIRealEndpoint*		endpoint;
    
    // Sync up all the known MIDI endpoints with CoreMIDI
    enumerator = [realSourceArray objectEnumerator];
    while (endpoint = [enumerator nextObject])
        [endpoint syncWithMIDIEndpoint];
    
    // Find any non-virtual endpoints that we don't already know about
    int i;
    int count = MIDIGetNumberOfSources();
    for (i = 0; i < count; i++) {
        MIDIEndpointRef midiEndpointRef = MIDIGetSource (i);
        
        // If this endpoint is real and previously unknown then add it to our list
        if (!PYMIDIIsEndpointLocalVirtual (midiEndpointRef) &&
            [self realSourceWithMIDIEndpointRef:midiEndpointRef] == nil)
        {
            endpoint = [[PYMIDIRealSource alloc] initWithMIDIEndpointRef:midiEndpointRef];
            [realSourceArray addObject:endpoint];
            [endpoint release];
        }
    }
    
    // Keep our endpoints sorted
    [realSourceArray sortUsingSelector:@selector(compareByDisplayName:)];
}


- (PYMIDIEndpoint*)realSourceWithMIDIEndpointRef:(MIDIEndpointRef)midiEndpointRef
{
    PYMIDIEndpoint* endpoint;
    
    NSEnumerator* enumerator = [realSourceArray objectEnumerator];
    while ((endpoint = [enumerator nextObject]) && [endpoint midiEndpointRef] != midiEndpointRef);
    
    return endpoint;
}


- (NSArray*)realSources
{
    return realSourceArray;
}


- (NSArray*)realSourcesOnlineOrInUse
{
    return [realSourceArray filteredArrayUsingSelector:@selector(isOnlineOrInUse)];
}

- (PYMIDIEndpoint*)realSourceWithName:(NSString *)name
{
    NSEnumerator* enumerator = [realSourceArray objectEnumerator];
    PYMIDIEndpoint* endpoint;
    while (endpoint = [enumerator nextObject])
    {
        if ([[endpoint displayName] isEqualToString:name])
        {
            return endpoint;
        }
    }
    return nil;
}

- (PYMIDIEndpoint*)realSourceWithDescriptor:(PYMIDIEndpointDescriptor*)descriptor
{
    PYMIDIEndpointSet*	endpointSet;
    PYMIDIEndpoint*		endpoint;
    
    endpointSet = [PYMIDIEndpointSet endpointSetWithArray:realSourceArray];
    endpoint = [endpointSet endpointWithDescriptor:descriptor];
    
    // Create a placeholder if no endpoint matches the descriptor
    if (endpoint == nil) {
        endpoint = [[PYMIDIRealSource alloc] initWithDescriptor:descriptor];
        [realSourceArray addObject:endpoint];
        [endpoint release];
    }
    
    return endpoint;
}



#pragma mark REAL MIDI DESTINATIONS


- (void)updateRealDestinations
{
    NSEnumerator*			enumerator;
    PYMIDIRealEndpoint*		endpoint;
    
    // Sync up all the known MIDI endpoints with CoreMIDI
    enumerator = [realDestinationArray objectEnumerator];
    while (endpoint = [enumerator nextObject])
        [endpoint syncWithMIDIEndpoint];
    
    // Find any non-virtual endpoints that we don't already know about
    int i;
    int count = MIDIGetNumberOfDestinations();
    for (i = 0; i < count; i++) {
        MIDIEndpointRef midiEndpointRef = MIDIGetDestination (i);
        
        // If this endpoint is real and previously unknown then add it to our list
        if (!PYMIDIIsEndpointLocalVirtual (midiEndpointRef) &&
            [self realDestinationWithMIDIEndpointRef:midiEndpointRef] == nil)
        {
            endpoint = [[PYMIDIRealDestination alloc] initWithMIDIEndpointRef:midiEndpointRef];
            [realDestinationArray addObject:endpoint];
            [endpoint release];
        }
    }
    
    // Keep our endpoints sorted
    [realDestinationArray sortUsingSelector:@selector(compareByDisplayName:)];
}


- (PYMIDIEndpoint*)realDestinationWithMIDIEndpointRef:(MIDIEndpointRef)midiEndpointRef
{
    PYMIDIEndpoint* endpoint;
    
    NSEnumerator* enumerator = [realDestinationArray objectEnumerator];
    while ((endpoint = [enumerator nextObject]) && [endpoint midiEndpointRef] != midiEndpointRef);
    
    return endpoint;
}


- (NSArray*)realDestinations
{
    return realDestinationArray;
}

- (NSArray*)realDestinationsOnlineOrInUse
{
    return [realDestinationArray filteredArrayUsingSelector:@selector(isOnlineOrInUse)];
}

- (PYMIDIEndpoint*)realDestinationWithName:(NSString *)name
{
    NSEnumerator* enumerator = [realDestinationArray objectEnumerator];
    PYMIDIEndpoint* endpoint;
    while (endpoint = [enumerator nextObject])
    {
        if ([[endpoint displayName] isEqualToString:name])
        {
            return endpoint;
        }
    }
    return nil;
}

- (PYMIDIEndpoint*)realDestinationWithDescriptor:(PYMIDIEndpointDescriptor*)descriptor
{
    PYMIDIEndpointSet*	endpointSet;
    PYMIDIEndpoint*		endpoint;
    
    endpointSet = [PYMIDIEndpointSet endpointSetWithArray:realDestinationArray];
    endpoint = [endpointSet endpointWithDescriptor:descriptor];
    
    // Create a placeholder if no endpoint matches the descriptor
    if (endpoint == nil) {
        endpoint = [[PYMIDIRealDestination alloc] initWithDescriptor:descriptor];
        [realDestinationArray addObject:endpoint];
        [endpoint release];
    }
    
    return endpoint;
}

#pragma mark MIDI NETWORK CONNECTIONS

- (void) processNetworkMIDINotification:(NSNotification*) notification {
    if (notificationsEnabled) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"PYMIDISetupChanged" object:self];
    }
}

- (NSArray*)midiNetworkSessionServices
{
    return [midiNetworkSessionServicesDict allKeys];
}

- (NSArray*)midiNetworkSessionConnections
{
    NSMutableArray* connections = [NSMutableArray arrayWithCapacity:[[[MIDINetworkSession defaultSession] connections] count]];
    for (MIDINetworkConnection* connection in [[MIDINetworkSession defaultSession] connections]) {
        [connections addObject:[[connection host] name]];
    }
    return connections;
}

- (NSNetService *)midiNetworkSessionServiceWithName:(NSString *)name
{
    if ([midiNetworkSessionServicesDict objectForKey:name] && [[midiNetworkSessionServicesDict objectForKey:name] isKindOfClass:[NSNetService class]])
    {
        return ((NSNetService *)[midiNetworkSessionServicesDict objectForKey:name]);
    }
    return nil;
}

#pragma mark - MIDINetworkSession CONNECTION MANAGEMENT
- (BOOL) midiNetworkSessionEnabled
{
    return [MIDINetworkSession defaultSession].enabled;
}

- (void) enableMIDINetworkSession
{
    MIDINetworkSession* session = [MIDINetworkSession defaultSession];
    session.enabled = YES;
    session.connectionPolicy = MIDINetworkConnectionPolicy_Anyone;
}

- (void) disableMIDINetworkSession
{
    MIDINetworkSession* session = [MIDINetworkSession defaultSession];
    session.enabled = NO;
    session.connectionPolicy = MIDINetworkConnectionPolicy_NoOne;
}

- (BOOL) midiNetworkSessionConnected {
    return  [[[MIDINetworkSession defaultSession] connections] count] > 0;
}

- (NSString*) describeMIDINetworkSessionConnections {
    NSMutableArray* connections = [NSMutableArray arrayWithCapacity:[[[MIDINetworkSession defaultSession] connections] count]];
    for (MIDINetworkConnection* connection in [[MIDINetworkSession defaultSession] connections]) {
        [connections addObject:[[connection host] name]];
    }

    if ([connections count] > 0) {
        return [connections componentsJoinedByString:@", "];
    }
    else
        return @"(Not connected)";
}

- (BOOL) isConnected:(NSNetService*) service {
    for (MIDINetworkConnection* connection in [[MIDINetworkSession defaultSession] connections]) {
        NSLog(@"Name: %@ net service name: %@ service name: %@", [[connection host] name], [[connection host] netServiceName], [service name]);
        if ([[connection host] netServiceName] != nil) {
            if ([[[connection host] netServiceName] isEqualToString:[service name]])
                return YES;
        }
        else if ([[[connection host] name]isEqualToString:[service name]])
            return YES;

    }

    return NO;
}

- (void) connectToService:(NSNetService*) service {
    MIDINetworkHost* host = [MIDINetworkHost hostWithName:[service name] netService:service];
    MIDINetworkConnection* newConnection = [MIDINetworkConnection connectionWithHost:host];
    [[MIDINetworkSession defaultSession] addConnection:newConnection];
    NSLog(@"Connected to %@", [service name]);
}

- (void) toggleConnected:(NSNetService*) service {
    if ([self isConnected:service]) {
        for (MIDINetworkConnection* connection in [[MIDINetworkSession defaultSession] connections]) {
            NSLog(@"Name: %@ net service name: %@ service name: %@", [[connection host] name], [[connection host] netServiceName], [service name]);
            if ([[connection host] netServiceName] != nil) {
                if ([[[connection host] netServiceName] isEqualToString:[service name]]) {
                    [[MIDINetworkSession defaultSession] removeConnection:connection];
                    break;
                }
            }
            else {
                if ([[[connection host] name]isEqualToString:[service name]]) {
                    [[MIDINetworkSession defaultSession] removeConnection:connection];
                    break;
                }
            }
        }
    }
    else {
        if ([service hostName]) {
            // If it's already been resolved we can just add it
            [self connectToService:service];
        }
        else {
            // Otherwise resolve it
            [service setDelegate:self];
            [service resolveWithTimeout:10.0];
        }
    }
}


#pragma mark - NSNetServiceBrowserDelegate

- (void)startMIDINetworkBrowser
{
    self->midiNetworkBrowser = [[NSNetServiceBrowser alloc] init];
    self->midiNetworkBrowser.delegate = self;
    [self->midiNetworkBrowser searchForServicesOfType:MIDINetworkBonjourServiceType /* i.e. @"_apple-midi._udp"*/
                                             inDomain:@""];
}

- (void)stopMIDINetworkBrowser
{
    if (self->midiNetworkBrowser)
    {
        [self->midiNetworkBrowser stop];
        [self->midiNetworkBrowser release];
        self->midiNetworkBrowser = nil;
    }
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)aBrowser didFindService:(NSNetService *)aService moreComing:(BOOL)more {
    NSLog(@"Found service %@ on %@", [aService name], [aService hostName]);

    // Requires check for iOS vs. OSX
    // Filter out local services
    if (![[aService name] isEqualToString:[[UIDevice currentDevice] name]]) {
        [self->midiNetworkSessionServicesDict setValue:aService forKey:[aService name]];
    }
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)aBrowser didRemoveService:(NSNetService *)aService moreComing:(BOOL)more {
    NSLog(@"Removing service %@", [aService name]);
    [self->midiNetworkSessionServicesDict removeObjectForKey:[aService name]];
}

- (void) netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser {
    NSLog(@"Browser stopped.");
}

#pragma mark - NSNetServiceDelegate

-(void)netServiceDidResolveAddress:(NSNetService *)service {
    [service setDelegate:nil];
    NSLog(@"Resolved service name: %@ host name: %@", [service name], [service hostName]);
    [self connectToService:service];
}

-(void)netService:(NSNetService *)service didNotResolve:(NSDictionary *)errorDict {
    [service setDelegate:nil];
    NSLog(@"Could not resolve: %@", errorDict);
}

- (void)netServiceDidStop:(NSNetService *)service {
    [service setDelegate:nil];
    NSLog(@"Service stopped: %@", [service name]);
}


#pragma mark NOTE NAMES


- (void)buildNoteNamesArray
{
    NSMutableArray* tempNoteNamesArray;
    
    int i, octave, note;
    char* noteName[] = {
        "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
    };
    
    tempNoteNamesArray = [NSMutableArray arrayWithCapacity:128];
    
    for (i = 0; i < 128; i++) {
        octave = i / 12;
        note   = i % 12;
        
        [tempNoteNamesArray addObject:[NSString stringWithFormat:@"%s%d", noteName[note], octave-1]];
    }
    
    noteNamesArray = [[NSArray alloc] initWithArray:tempNoteNamesArray];
}


- (NSString*)nameOfNote:(Byte)note
{
    return [noteNamesArray objectAtIndex:note];
}






@end