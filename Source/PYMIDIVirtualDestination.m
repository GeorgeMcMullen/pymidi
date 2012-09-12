/*
    This software is distributed under the terms of Pete's Public License version 1.0, a
    copy of which is included with this software in the file "License.html".  A copy can
    also be obtained from http://pete.yandell.com/software/license/ppl-1_0.html
    
    If you did not receive a copy of the license with this software, please notify the
    author by sending e-mail to pete@yandell.com
    
    The current version of this software can be found at http://pete.yandell.com/software
     
    Copyright (c) 2002-2004 Peter Yandell.  All Rights Reserved.
    
    $Id: PYMIDIVirtualDestination.m,v 1.6 2004/01/10 13:58:32 pete Exp $
*/


#ifdef PYMIDI_FRAMEWORK
    #import <PYMIDI/PYMIDIVirtualDestination.h>

    #import <PYMIDI/PYMIDIUtils.h>
    #import <PYMIDI/PYMIDIManager.h>
    #import <PYMIDI/PYMidiDefines.h>
#else
    #import "PYMIDIVirtualDestination.h"

    #import "PYMIDIUtils.h"
    #import "PYMIDIManager.h"
    #import "PYMidiDefines.h"
#endif


@implementation PYMIDIVirtualDestination


static void midiReadProc (const MIDIPacketList* packetList, void* createRefCon, void* connectRefConn);


- (id)initWithName:(NSString*)newName
{
    PYMIDIManager*	manager = [PYMIDIManager sharedInstance];
    MIDIEndpointRef newEndpoint;
    OSStatus		error;
    SInt32			newUniqueID;
    
    // This makes sure that we don't get notified about this endpoint until after
    // we're done creating it.
    [manager disableNotifications];
    
    MIDIDestinationCreate ([manager midiClientRef], (CFStringRef)newName, midiReadProc, self, &newEndpoint);
    
    // This code works around a bug in OS X 10.1 that causes
    // new sources/destinations to be created without unique IDs.
    error = MIDIObjectGetIntegerProperty (newEndpoint, kMIDIPropertyUniqueID, &newUniqueID);
    if (error == kMIDIUnknownProperty) {
        newUniqueID = PYMIDIAllocateUniqueID();
        MIDIObjectSetIntegerProperty (newEndpoint, kMIDIPropertyUniqueID, newUniqueID);
    }
    
    MIDIObjectSetIntegerProperty (newEndpoint, CFSTR(MIDI_PID), [[NSProcessInfo processInfo] processIdentifier]);

    [manager enableNotifications];
    
    self = [super initWithMIDIEndpointRef:newEndpoint];

    ioIsRunning = NO;
    
    return self;
}


- (void)processMIDIPacketList:(const MIDIPacketList*)packetList sender:(id)sender
{
    if (!ioIsRunning) return;

    // Don't do any alloc'ing of data in your processMIDIPacketList method, you will run into leaks and NSAutoreleasePools are expensive.
    // Also, if you plan on doing anything on the UI, you must run it on the main thread.
    [receivers enumerateObjectsUsingBlock:^(id receiver, BOOL *stop){
        [[receiver nonretainedObjectValue] processMIDIPacketList:packetList sender:self];
    } ];
}


static void
midiReadProc (const MIDIPacketList* packetList, void* createRefCon, void* connectRefConn)
{
    PYMIDIVirtualDestination* destination = (PYMIDIVirtualDestination*)createRefCon;
    [destination processMIDIPacketList:packetList sender:destination];
}


@end
