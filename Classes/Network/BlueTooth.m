
//
//  Bluetooth.m
//  Bluetooth
//

#import "kaya_meetAppDelegate.h"
#import "Bluetooth.h"

@interface NSObject (BluetoothConnectDelegate)
- (void)BluetoothDidUpdate  :(BluetoothConnect*)manager peer:(NSString*)peerID;
- (void)BluetoothDidFinished:(BluetoothConnect*)manager;
@end

#define BLUETOOTH_TIMEOUT	 5
#define BLUETOOTH_SERVER_TIMEOUT 3600
#define BLUETOOTH_MAX_FRIEND 3

@implementation BluetoothConnect

//@synthesize picker;
@synthesize session;
@synthesize devNames, peerList, mode;

- (int) numberOfPeers{
	return aNumber ;
}

// host mode start from meet detail view.

- (void) startHost:(NSString *)name withId:(uint64_t)meet_id
{
	User *user = [User userWithId:[[NSUserDefaults standardUserDefaults] integerForKey:@"KYUserId" ]];
    
	if (!session) {
		
        session = [[GKSession alloc] initWithSessionID:@"kaya_meet_app"
										   displayName:[NSString stringWithFormat:@"%@:%d:%@:%ld",user.name,user.userId,name,meet_id]
										   sessionMode:GKSessionModeServer];
        session.delegate = self;
        [session setDataReceiveHandler:self withContext:nil];
        session.available = YES;
		mode = BT_HOST ;
    }
	NSLog(@"start host mode : %@", [session displayNameForPeer:session.peerID]);
	timer = [NSTimer scheduledTimerWithTimeInterval:BLUETOOTH_SERVER_TIMEOUT
                                             target:self
                                           selector:@selector(bluetoothDidTimeout:userInfo:)
                                           userInfo:nil
                                            repeats:false];
}

// peer mode start from meet list view
- (void) startPeer
{
	User *user = [User userWithId:[[NSUserDefaults standardUserDefaults] integerForKey:@"KYUserId" ]];
    
	if (!session) {
        session = [[GKSession alloc] initWithSessionID:@"kaya_meet_app"
										displayName:[NSString stringWithFormat:@"%@:%d",user.name,user.userId]
										sessionMode:GKSessionModePeer];
        session.delegate = self;
        [session setDataReceiveHandler:self withContext:nil];
        session.available = YES;
		NSLog(@"start Peer  %@", [session displayNameForPeer:session.peerID]);
		mode = BT_PEER ;
    }
	timer = [NSTimer scheduledTimerWithTimeInterval:BLUETOOTH_TIMEOUT
                                             target:self
                                           selector:@selector(bluetoothDidTimeout:userInfo:)
                                           userInfo:nil
                                            repeats:false];
}

// start peer with meet_id from meet detail view
// name:time_id:id

- (void) startPeer:(uint64_t)meet_id
{
	time_t now;
	time(&now);
	User *user = [User userWithId:[[NSUserDefaults standardUserDefaults] integerForKey:@"KYUserId" ]];
    
	if (!session) {
        session = [[GKSession alloc] initWithSessionID:@"kaya_meet_app"
										   displayName:[NSString stringWithFormat:@"%@:%d_%d:%ld",user.name,now,user.userId,meet_id]
										   sessionMode:GKSessionModePeer];
        session.delegate = self;
        [session setDataReceiveHandler:self withContext:nil];
        session.available = YES;
		NSLog(@"start Peer %@", [session displayNameForPeer:session.peerID]);
		mode = BT_ADD ;
    }
	timer = [NSTimer scheduledTimerWithTimeInterval:BLUETOOTH_TIMEOUT
                                             target:self
                                           selector:@selector(bluetoothDidTimeout:userInfo:)
                                           userInfo:nil
                                            repeats:false];
}

-(void) bluetoothDidTimeout:(NSTimer*)aTimer userInfo:(id)userInfo
{
	timer = nil ;
	if ( mode != BT_HOST ) [delegate BluetoothDidFinished:self];
	[self stopPeer];
}

- (void) stopPeer
{
    // Set up the session for the next connection
    //
	NSLog(@"stop peer %@", [session displayNameForPeer:session.peerID]);
    [session disconnectFromAllPeers];
	session.available = NO;
	[session setDataReceiveHandler: nil withContext: nil];
	session.delegate = nil;
	mode=BT_FREE;
	//	[session release];
}

- (void) reset {
	if ( mode != BT_FREE ) [self stopPeer];
	aNumber = 0 ;
	session = nil;
	[peerList removeAllObjects]  ;
	[devNames removeAllObjects]  ;
}

- (id)initWithDelegate:(id)aDelegate {
	[super init];
	delegate = aDelegate;
	// allocate and setup the peer picker controller
	// not use the picker as for now
//	picker  = [[GKPeerPickerController alloc] init];
//	picker.delegate = self;
//	picker.connectionTypesMask = GKPeerPickerConnectionTypeNearby;
//	[picker show];
	peerList = [[NSMutableArray alloc] init];
	devNames = [[NSMutableArray alloc] init];
	aNumber = 0 ;
	mode = BT_FREE;
	session = nil;
	return self;
}


/*- (void)peerPickerController:(GKPeerPickerController *)picker didSelectConnectionType:(GKPeerPickerConnectionType)type {
//}

- (GKSession *) peerPickerController:(GKPeerPickerController *)picker
	sessionForConnectionType:(GKPeerPickerConnectionType)type {
	if ( session == nil ) {
		session = [[GKSession alloc] initWithSessionID:@"kaya_meet_app"  displayName:nil sessionMode:GKSessionModePeer];
		session.delegate = self;
		[session setDataReceiveHandler:self withContext:nil];
        session.available = YES;
	}
	return session;
}

- (void) loadPeerList
{
	if (peerList == nil ) 
		peerList = [[NSMutableArray alloc] initWithArray:[session peersWithConnectionState:GKPeerStateAvailable]];
}
*/
- (void)session:(GKSession *)aSession peer:(NSString *)peerID didChangeState:(GKPeerConnectionState)state {
	BOOL peerChanged = NO;
	if (mode == BT_HOST) {
		aNumber ++ ;
		return ;
	}
	switch (state) {
		case GKPeerStateAvailable:
                if (peerList) {
					//[peerList addObject:peerID];
					[peerList addObject:[aSession displayNameForPeer:peerID]];
					//	[session connectToPeer:peerID withTimeout:10];
					peerChanged = YES;
					aNumber ++ ;
                }
			if ([delegate respondsToSelector:@selector(BluetoothDidUpdate:peer:)]) {
				[delegate BluetoothDidUpdate:self peer:peerID];
			}
			break;

		case GKPeerStateUnavailable:
                if (peerList) {
             //         [peerList removeObject:peerID];
                        peerChanged = YES;
                }
                break;

		case GKPeerStateConnected:
			   [self.session setDataReceiveHandler :self withContext:nil];
			// [self mySendData]; start off by sending data upon connection
				break;
		case GKPeerStateDisconnected:
				break;
	}
	if ( aNumber == BLUETOOTH_MAX_FRIEND ){
		[timer invalidate];
		[delegate BluetoothDidFinished:self];
		[self stopPeer];
	}
}

- (void)session:(GKSession *)session didReceiveConnectionRequestFromPeer:(NSString *)peerID {
	NSError *error = nil;
	[self.session acceptConnectionFromPeer:peerID error:&error];
	if (error)
		NSLog(@"%@",error);
}

- (void)session:(GKSession *)session connectionWithPeerFailed:(NSString *)peerID withError:(NSError *)error {
	NSLog(@"%@",error);
}

- (void)peerPickerController:(GKPeerPickerController *)picker didConnectToPeer:(NSString *)peerID {
    NSLog(@"connection was successful! \n");
}


- (void)peerPickerControllerDidCancel:(GKPeerPickerController *)picker {
	NSLog(@"connection attempt was canceled\n");
}


- (void)mySendData {
	// allocate the NSData
	aNumber++;
	NSData *myData = [[NSData alloc] initWithBytes:&aNumber length:sizeof(int)];
	[session sendDataToAllPeers :myData withDataMode:GKSendDataReliable error:nil];
	[myData autorelease];
}


- (void) receiveData:(NSData *)data fromPeer:(NSString *)peer inSession: (GKSession *)session context:(void *)context
{
	// Read the bytes in data and perform an application-specific action, then free the NSData object
	[data getBytes:&aNumber length:sizeof(int)];
	NSLog(@"received data: %i from: %s\n", aNumber, [peer UTF8String]);
	[self mySendData];
}


- (void)dealloc
{
	if (timer)    [timer invalidate];
//	[picker release];
	if ( mode != BT_FREE ) [self stopPeer];
	[peerList release];
	[devNames release];
	[super dealloc];
}



// utility
// name:u_id
// name:u_id:host_name:meet_id
// name:u_id:meet_id
// name utility

- (NSString *)getDisplayName
{
	return [session displayNameForPeer:session.peerID];
}

- (NSString *)getPeerNameList
{
	NSMutableArray* pairs = [NSMutableArray array];
	for (int i = 0 ; i < aNumber ; i ++ ) {
		if ([self countField:[peerList objectAtIndex:i]] > 2) continue ;
		 NSRange end = [[peerList objectAtIndex:i] rangeOfString:@":"] ;
		[pairs addObject:[[peerList objectAtIndex:i] substringToIndex:end.location]];
	}
	if ( [pairs count] )
		return [pairs componentsJoinedByString:@","] ;
	return nil ;
}


- (NSString *)findHost {
	for ( int i = 0 ; i < aNumber ; i ++ ) 
	{
		if ( [self countField:[peerList objectAtIndex:i]] > 3 )
			return [peerList objectAtIndex:i] ;
	}
	return nil ;
}

- (NSString *)findMeet {
	for ( int i = 0 ; i < aNumber ; i ++ ) 
	{
		if ( [self countField:[peerList objectAtIndex:i]] == 3 )
			return [peerList objectAtIndex:i] ;
	}
	return nil ;
}

- (int) countField:(NSString *)str
{	int count = 1  ;
	int len = [str length];
	for (int i = 0 ; i < len ; i ++ ) 
		if ( [str characterAtIndex:i] == ':' ) count++;
	return count ;
}

- (void)getDisplayNames:(NSString *)str
{
	[devNames removeAllObjects];
	int start = 0;
	int len = [str length];
	NSCharacterSet* chs = [NSCharacterSet characterSetWithCharactersInString:@":"];
	
	while (start < len) {
		NSRange r = [str rangeOfCharacterFromSet:chs options:0 range:NSMakeRange(start, len-start)];
		if (r.location == NSNotFound) {
			[devNames addObject:[str substringFromIndex:start]];
			break;
		}
		if (start < r.location) {
			[devNames addObject:[str substringWithRange:NSMakeRange(start, r.location-start)]];
		}
		start = r.location + 1;
	}
}

@end
