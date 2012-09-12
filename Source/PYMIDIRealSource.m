/*
    This software is distributed under the terms of Pete's Public License version 1.0, a
    copy of which is included with this software in the file "License.html".  A copy can
    also be obtained from http://pete.yandell.com/software/license/ppl-1_0.html
    
    If you did not receive a copy of the license with this software, please notify the
    author by sending e-mail to pete@yandell.com
    
    The current version of this software can be found at http://pete.yandell.com/software
     
    Copyright (c) 2002-2004 Peter Yandell.  All Rights Reserved.
    
    $Id: PYMIDIRealSource.m,v 1.6 2004/01/10 14:13:51 pete Exp $
*/


#ifdef PYMIDI_FRAMEWORK
    #import <PYMIDI/PYMIDIRealSource.h>

    #import <PYMIDI/PYMIDIUtils.h>
    #import <PYMIDI/PYMIDIManager.h>
    #import <PYMIDI/PYMIDIEndpointDescriptor.h>
    #import <PYMIDI/PYMidiDefines.h>
#else
    #import "PYMIDIRealSource.h"

    #import "PYMIDIUtils.h"
    #import "PYMIDIManager.h"
    #import "PYMIDIEndpointDescriptor.h"
    #import "PYMidiDefines.h"
#endif


@implementation PYMIDIRealSource


static void midiReadProc (const MIDIPacketList* packetList, void* createRefCon, void* connectRefConn);


- (id)initWithCoder:(NSCoder*)coder
{
    PYMIDIManager*				manager = [PYMIDIManager sharedInstance];
    NSString*					newName;
    SInt32						newUniqueID;
    PYMIDIEndpointDescriptor*	descriptor;
    
    self = [super initWithCoder:coder];

    newName     = [coder decodeObjectForKey:@"name"];
    newUniqueID = [coder decodeInt32ForKey:@"uniqueID"];
    
    descriptor = [PYMIDIEndpointDescriptor descriptorWithName:newName uniqueID:newUniqueID];
    
    [self release];
    return (PYMIDIRealSource *)[[manager realSourceWithDescriptor:descriptor] retain];
}



- (void)syncWithMIDIEndpoint
{
    MIDIEndpointRef newEndpointRef;
    
    if (midiEndpointRef && PYMIDIDoesSourceStillExist (midiEndpointRef))
        newEndpointRef = midiEndpointRef;
    else
        newEndpointRef = NULL;

    if (newEndpointRef == NULL)  newEndpointRef = PYMIDIGetSourceByUniqueID (uniqueID);
    if (newEndpointRef == NULL)  newEndpointRef = PYMIDIGetSourceByName (name);

    if (midiEndpointRef != newEndpointRef) {
        [self stopIO];
        midiEndpointRef = newEndpointRef;
        if ([self isInUse]) [self startIO];
    }

    [self setPropertiesFromMIDIEndpoint];
}


- (void)startIO
{
    if (midiEndpointRef == nil || midiPortRef != nil) return;

    MIDIInputPortCreate (
        [[PYMIDIManager sharedInstance] midiClientRef], CFSTR(MIDI_INPUTPORT),
        midiReadProc, (void*)self, &midiPortRef
    );
    MIDIPortConnectSource (midiPortRef, midiEndpointRef, nil);
}


- (void)stopIO
{
    if (midiPortRef == nil) return;
    
    MIDIPortDisconnectSource (midiPortRef, midiEndpointRef);
    MIDIPortDispose (midiPortRef);
    midiPortRef = nil;
}


- (void)processMIDIPacketList:(const MIDIPacketList*)packetList sender:(id)sender
{
    // Don't do any alloc'ing of data in your processMIDIPacketList method, you will run into leaks and NSAutoreleasePools are expensive.
    // Also, if you plan on doing anything on the UI, you must run it on the main thread.
    [receivers enumerateObjectsUsingBlock:^(id receiver, BOOL *stop){
        [[receiver nonretainedObjectValue] processMIDIPacketList:packetList sender:self];
    } ];
}


static void
midiReadProc (const MIDIPacketList* packetList, void* createRefCon, void* connectRefConn)
{
    PYMIDIRealSource* source = (PYMIDIRealSource*)createRefCon;
    [source processMIDIPacketList:packetList sender:source];
}


@end
