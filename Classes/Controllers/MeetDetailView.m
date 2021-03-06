//
//  MeetDetailView.m
//  kaya_meet
//
//  Created by Jun Li on 12/25/10.
//
#import <QuartzCore/QuartzCore.h>
#import "MeetDetailView.h"
#import "FriendViewCell.h"
#import "meetDisplayMap.h"
#import "UACellBackgroundView.h"
#import "kaya_meetAppDelegate.h"
#import "StringUtil.h"

@implementation MeetDetailView

@synthesize currentMeet;

@synthesize friendsView, mapView, messageView;

@synthesize soundFileURLRef, soundFileObject; 

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithMeet:(KYMeet *)meet {
    if (self) {
        // Custom initialization.
		currentMeet = meet ;
		loadCell  = [[LoadCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"FriendLoadCell"];
		[loadCell setType:1];
    }
    return self;
}



// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	// set title
	static NSDateFormatter *dateFormatter = nil;
	if (dateFormatter == nil) {
		dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setDateStyle:NSDateFormatterShortStyle];
		[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	}
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:currentMeet.timeAt];        
	self.navigationItem.title = [NSString stringWithFormat:@"@ %@", [dateFormatter stringFromDate:date]];
	
	// right button
	
	UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"77-ekg.png"]
																	  style:UIBarButtonItemStylePlain 
																	 target:self 
																	 action:@selector(addMeet)];
	[self.navigationItem setRightBarButtonItem:rightBarButton animated:NO] ;
	[rightBarButton release];
	
	if(  currentMeet.userCount == 1 ) {
		friendsView.hidden = true ;
		mapView = [[UIImageView alloc] initWithFrame:CGRectMake(16,25,288,90)] ;
		//mapView.frame = CGRectMake(16,25,288,90) ;

	} else {
		hostButton.hidden = true ;
		messageView.frame = CGRectMake(15,132,290,210);
		mapView = [[UIImageView alloc] initWithFrame:CGRectMake(16,25,110,90)];
		//mapView.frame = CGRectMake(16,25,110,90) ;
		friendsView.frame = CGRectMake(128,25, 175,90);
	}
	[self.view addSubview:mapView];
	CALayer *ly = [mapView layer];
	[ly setMasksToBounds:YES];
	[ly setCornerRadius:5.0];
	[mapView release];
	
	// textView
	messageView.layer.cornerRadius = 5.0;
	messageView.font = [UIFont systemFontOfSize:13];
	messageView.text = @"";
	// actionButtons
	
	// set friendsView 
	[friendsView setDelegate:self];
	[friendsView setDataSource:self];
	friendsView.layer.cornerRadius = 5.0;
	friendsView.backgroundColor = [UIColor clearColor];
	friendsView.separatorColor = [UIColor clearColor];
	[friendsView setAlwaysBounceVertical:YES];
	
	// BT
	bt = [[BluetoothConnect alloc] initWithDelegate:self];
	
	// sound

    NSURL *tapSound   = [[NSBundle mainBundle] URLForResource: @"tap"
                                                withExtension: @"aif"];
	
    // Store the URL as a CFURLRef instance
    self.soundFileURLRef = (CFURLRef) [tapSound retain];
	
    // Create a system sound object representing the sound file.
    AudioServicesCreateSystemSoundID (
									  soundFileURLRef,
									  &soundFileObject
									  );
	
	[self getMeetDetails];
}


- (void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	if (meetDetailClient != nil ) {
		[meetDetailClient cancel];
		[meetDetailClient release];
		meetDetailClient = nil;
	}
	if ( bt.mode != BT_FREE ) [bt stopPeer] ;
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {

    [super viewDidUnload];
	
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [loadCell release] ;
    if ( [ currentMeet.meetUsers count ] )
    {
	 [currentMeet.meetUsers removeAllObjects];
    }
	[bt release];
	AudioServicesDisposeSystemSoundID (soundFileObject);
    CFRelease (soundFileURLRef);
    [super dealloc];
}

// load meet details

- (void)getMeetDetails
{
    if (meetDetailClient) return;
	meetDetailClient = [[KYMeetClient alloc] initWithTarget:self action:@selector(detailsDidReceive:obj:)];
    NSMutableDictionary *param = [NSMutableDictionary dictionary];
	// get meets from server
    [meetDetailClient getMeet:param withMeetId:currentMeet.meetId];
}

- (void)detailsDidReceive:(KYMeetClient*)sender obj:(NSObject*)obj
{
	meetDetailClient = nil;    
	[loadCell.spinner stopAnimating];
    if (sender.hasError) {
        if (sender.statusCode == 401) { // authentication fail
            kaya_meetAppDelegate *appDelegate = (kaya_meetAppDelegate*)[UIApplication sharedApplication].delegate;
            [appDelegate openLoginView];
        }
        [sender alert];
    }
	
    if (obj == nil || ! [obj isKindOfClass:[NSDictionary class]] )  {
		// didn't get any meet from server
        return;
    }
	NSDictionary *dic = (NSDictionary*)obj ;
	dic = [dic objectForKey:@"meet"] ;
	if (![dic isKindOfClass:[NSDictionary class]]) {
		return;
	}
	[currentMeet updateWithJsonDictionary:dic] ;
	[self updateFriendList];
 
}

- (void) updateFriendList
{
	int numInsert = [currentMeet.meetUsers count];
	if (numInsert != 0) {
		[self.friendsView beginUpdates];
		NSMutableArray *insertion = [[[NSMutableArray alloc] init] autorelease];
		for (int i = 0; i < numInsert; ++i) {
			[insertion addObject:[NSIndexPath indexPathForRow:i inSection:0]];
		}
		[self.friendsView insertRowsAtIndexPaths:insertion withRowAnimation:UITableViewRowAnimationNone];
		[self.friendsView endUpdates];
	}
	
	if (currentMeet.latestChat == nil) 
		self.messageView.text = [NSString stringWithFormat:@"@ %@",currentMeet.place] ;
	else {
		self.messageView.text = [NSString stringWithFormat:@"%@",currentMeet.latestChat] ;
	}
	// set MayImageView
	NSString *headmapurl0 = @"http://maps.google.com/maps/api/staticmap?zoom=11&size=110x90&maptype=roadmap&format=png32&markers=color:green|size:small";
	NSString *headmapurl1 = @"http://maps.google.com/maps/api/staticmap?zoom=11&size=290x90&maptype=roadmap&format=png32&markers=color:green|size:small";
	NSString *mapurl = [NSString stringWithFormat:@"%@|%lf,%lf&sensor=false",currentMeet.userCount > 1 ?headmapurl0:headmapurl1,currentMeet.latitude,currentMeet.longitude];
	mapurl = [mapurl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSURL *url = [NSURL URLWithString:mapurl] ;
	NSData *mapdata = [[NSData alloc] initWithContentsOfURL:url];
	UIImage *uimap = [[UIImage alloc] initWithData:mapdata];
	mapView.image = uimap; 
	[mapdata release];
	[uimap release];
//	[url release];

}

// Friend view list

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection: (NSInteger)section
{
    //return @"People you met with";
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	return nil;
}

- (User *) userAtIndex:(int)index 
{
	return [currentMeet.meetUsers objectAtIndex:index] ;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (currentMeet.meetUsers == nil) return 0 ;
    else return [currentMeet.meetUsers count]  ;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return  currentMeet.userCount > 1 ? 45 : 90;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.backgroundColor = [UIColor clearColor];
	if ( [currentMeet.meetUsers count] < 2 ) return ;
	if ( indexPath.row == 0 ) {
		[(UACellBackgroundView *)cell.backgroundView setPosition:UACellBackgroundViewPositionTop];
	} else if ( indexPath.row == [currentMeet.meetUsers count]-1 ){
		[(UACellBackgroundView *)cell.backgroundView setPosition:UACellBackgroundViewPositionBottom];
	} else {
		[(UACellBackgroundView *)cell.backgroundView setPosition:UACellBackgroundViewPositionMiddle];
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	User* u = [self userAtIndex:indexPath.row];
    if (u == nil) return loadCell;
    
    FriendViewCell* cell = (FriendViewCell*)[friendsView dequeueReusableCellWithIdentifier:@"FriendCell"];
    if (!cell) {
        cell = [[[FriendViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"FriendCell" ] autorelease];
    }
	
	cell.nameLabel.text   = u.name  ;
	
	NSString *picURL = u.profileImageUrl ;
	if ((picURL != (NSString *) [NSNull null]) && (picURL.length !=0)) {
		NSURL  *url = [NSURL URLWithString:picURL] ;
		NSData *imgData = [NSData dataWithContentsOfURL:url];
		UIImage *aImage = [[UIImage alloc] initWithData:imgData];
		CGSize itemSize  = CGSizeMake(40,40);
		UIGraphicsBeginImageContext(itemSize);
		CGRect imageRect = CGRectMake(0.0,0.0,itemSize.width, itemSize.height);
		[aImage drawInRect:imageRect];
		cell.friendImageView.image = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		[aImage release];
	} else {
		cell.friendImageView.image = nil;
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:TRUE];   
}

/* mapView 

-(MKAnnotationView *)mapView:(MKMapView *)mV viewForAnnotation:(id <MKAnnotation>)annotation {
	MKPinAnnotationView *pinView = nil; 
	if ([annotation isKindOfClass:[MKUserLocation class]])
        return nil;
	if([annotation isKindOfClass:[meetDisplayMap class]])
	{
		static NSString *defaultPinID = @"com.kayameet.detailPin";
		pinView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:defaultPinID];
		if ( pinView == nil ) pinView = [[[MKPinAnnotationView alloc]
										  initWithAnnotation:annotation reuseIdentifier:defaultPinID] autorelease];
		pinView.pinColor = MKPinAnnotationColorPurple; 
		pinView.canShowCallout = NO;
		pinView.animatesDrop = NO;
		pinView.annotation = annotation ;
	} 
//	else {
//		[mapView.userLocation setTitle:@"you are here"];
//	}
	return pinView;
}
 */

// IBActions 

- (IBAction) postMessage:(id) sender 
{
	kaya_meetAppDelegate *appDelegate = (kaya_meetAppDelegate*)[UIApplication sharedApplication].delegate;
	MessageViewController *mV = appDelegate.messageView ;
	
	[mV postTo:currentMeet];
}

- (IBAction) inviteFriend:(id) sender 
{
	kaya_meetAppDelegate *appDelegate = (kaya_meetAppDelegate*)[UIApplication sharedApplication].delegate;
	MessageViewController *mV = appDelegate.messageView ;
	
	[mV inviteTo:currentMeet];
}

- (IBAction) hostMeet:(id) sender
{
	UIButton* button = (UIButton*)sender;
	button.selected = !button.selected;
	if ( button.selected ) { // selected, start host
		//NSLog(@"selected");
		[bt   reset ] ;
		AudioServicesPlaySystemSound (soundFileObject);
		self.navigationItem.rightBarButtonItem.enabled = false;
		[self hostDialog];
	}
	else { // unselected, close host if any open
		if ( bt.mode == BT_HOST ) [bt stopPeer];
		self.navigationItem.rightBarButtonItem.enabled = true;
	}
}

- (void) addMeet
{
	//NSLog(@"add meet");
	self.navigationItem.rightBarButtonItem.enabled = false;
	AudioServicesPlaySystemSound (soundFileObject);
	// BT device connection
	[bt   reset ] ;
	HUD = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
	HUD.labelText = @"adding friend..";
	HUD.detailsLabelText = [NSString stringWithFormat:@".. %d", [bt numberOfPeers]] ;
	[bt startPeer:currentMeet.meetId] ;
}

// when add friend got list 
- (void) BluetoothDidFinished:(BluetoothConnect *)Bluetooth {
	[MBProgressHUD hideHUDForView:self.navigationController.view animated:YES];
	self.navigationItem.rightBarButtonItem.enabled = true ;
	
	if ([ Bluetooth numberOfPeers ] == 0 ) return ;
	
	NSString *names = [Bluetooth getPeerNameList] ;
	
	if ( names == nil || names == @"" ) return ;
	[self dialog:[NSString stringWithFormat:@"Add %@", names]  
		 message:[NSString stringWithFormat:@"to your meet ?"] ] ;
}

- (void) BluetoothDidUpdate:(BluetoothConnect *)Bluetooth peer:(NSString *)peerID{
	HUD.detailsLabelText = [NSString stringWithFormat:@".. %d", [Bluetooth numberOfPeers]] ;
}


- (void)addJoin:(NSMutableDictionary*)param
{
    if (meetDetailClient) return;
	meetDetailClient = [[KYMeetClient alloc] initWithTarget:self action:@selector(JoinDidPost:obj:)];	
	// meet date
	time_t now;
	time(&now);
	[param setObject:[NSString dateString:now] forKey:@"time"];
	[meetDetailClient postMeet:param];
}

- (void) postAdd:(BOOL)collision
{
	NSMutableDictionary *param = [NSMutableDictionary dictionary];
	[param setObject:[bt getDisplayName] forKey:@"host_id"];
	[param setObject:[NSString stringWithFormat:@"%@",[bt.peerList componentsJoinedByString:@","]] forKey:@"devs"];
	[param setObject:[bt getDisplayName] forKey:@"user_dev"];
	[param setObject:@"3" forKey:@"host_mode"];
	if( collision == true ) {
		[param setObject:@"1" forKey:@"collision"];
	} else {
		[param setObject:@"0" forKey:@"collision"];
	}
	kaya_meetAppDelegate *appDelegate = (kaya_meetAppDelegate*)[UIApplication sharedApplication].delegate;
	MeetViewController *mc = [appDelegate getAppMeetViewController];
	MeetViewDataSource *md = [mc meetDataSource] ;
	[md addMeet:param] ;
	//[self addJoin:param];
}

- (void)JoinDidPost:(KYMeetClient*)sender obj:(NSObject*)obj
{
	meetDetailClient = nil;

    if (sender.hasError) {
        
        if (sender.statusCode == 401) { // authentication fail
            kaya_meetAppDelegate *appDelegate = (kaya_meetAppDelegate*)[UIApplication sharedApplication].delegate;
            [appDelegate openLoginView];
        }
        [sender alert];
    }
	NSDictionary *dic = (NSDictionary*)obj ;
	if ([dic isKindOfClass:[NSDictionary class]])
		dic = [dic objectForKey:@"mpost"] ;
    if ([dic isKindOfClass:[NSDictionary class]]) {
		// remove post array
		//[self removeLastMeet] ;
		//[DBConnection beginTransaction];
		// KYMeet* sts = [KYMeet meetWithJsonDictionary:dic type:KYMEET_TYPE_SENT];
		//[sts insertDB];
		//[self insertSentMeet:sts atIndex:insertPosition];
		//[DBConnection commitTransaction];
		NSString *collision = [dic objectForKey:@"collision"] ;
		kaya_meetAppDelegate *appDelegate = (kaya_meetAppDelegate*)[UIApplication sharedApplication].delegate;
		if ( collision != nil || collision != @"" ) [appDelegate alert: @"Post Join Success !"   message:nil]; 
		else										[appDelegate alert: @"Post Join Collision !" message:nil];
		//[self getUserMeets];
	}
    else {
		// didn't get meet back from response
		return;
    }
	//if ([controller respondsToSelector:@selector(meetsDidUpdate:count:insertAt:)]) {
    //    [controller meetsDidUpdate:self count:1 insertAt:insertPosition];
	//}
}

- (void) acceptAdd 
{
	[self postAdd:false ];
}

- (void) collisionAdd
{
	[self postAdd:true ];	
}

// pop up
// alterview button 
#define HOST_MODE_NAMEFIELD			01010101
#define HOST_MODE_PASSWORDFIELD		01010102

#define HOST_MODE_ALERT		000100010001
#define ADD_MODE_ALERT		000200020002

static UIAlertView *sAlert = nil ;

- (void)hostDialog
{
	if (sAlert) return;
    sAlert = [[UIAlertView alloc] initWithTitle:@"Host meet"
									   message :@"\n\n"
									   delegate:self
							  cancelButtonTitle:@"Cancel"
							  otherButtonTitles:@"Start", nil];
	sAlert.tag = HOST_MODE_ALERT;
	
	UITextField *nameField = [[UITextField alloc] initWithFrame:CGRectMake(20.0, 50.0, 240.0, 25.0)];
	
	[nameField setBackgroundColor:[UIColor whiteColor]];
	[nameField setPlaceholder:@"meet name"];
	 nameField.tag = HOST_MODE_NAMEFIELD;
	CALayer *ly = [nameField layer];
	[ly setMasksToBounds:YES];
	[ly setCornerRadius:5.0];
	[sAlert addSubview:nameField];
	
	/* UITextField *pwField = [[UITextField alloc] initWithFrame:CGRectMake(20.0, 85.0, 240.0, 25.0)];
	[pwField setBackgroundColor:[UIColor whiteColor]];
	[pwField setPlaceholder:@"password"];
	 pwField.tag = HOST_MODE_PASSWORDFIELD;
	[pwField setSecureTextEntry:YES];
	 ly = [pwField layer];
	[ly setMasksToBounds:YES];
	[ly setCornerRadius:5.0];
	[sAlert addSubview:pwField]; */
	
	[sAlert show];
	[nameField release];
	// [pwField release];
	[sAlert release];
	[nameField becomeFirstResponder];
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	//NSLog(@"click %d",buttonIndex);
	if (alertView.tag == HOST_MODE_ALERT ) {
		if ( buttonIndex == 1 )
		{
			UITextField *nameField = (UITextField *)[alertView viewWithTag:HOST_MODE_NAMEFIELD];
		//	UITextField *pwField = (UITextField *)[alertView viewWithTag:HOST_MODE_PASSWORDFIELD];
			NSLog(@"start host: %@",nameField.text);
			[bt startHost:nameField.text withId:currentMeet.meetId] ;
		}
		else {
			[self hostMeet:hostButton];
		}
	}
	else if ( alertView.tag == ADD_MODE_ALERT ) {
		if ( buttonIndex == 0  )
		{
			[self acceptAdd] ;
		}
		else if ( buttonIndex == 1 ){
			[self collisionAdd] ;
		}
	}

	sAlert = nil ; 
}

- (void)dialog:(NSString*)title message:(NSString*)message
{
	if (sAlert) return;
	sAlert = [[UIAlertView alloc] initWithTitle:title
										message:message
									   delegate:self
							  cancelButtonTitle:@"Accept"
							  otherButtonTitles:@"Cancel", nil];
	sAlert.tag = ADD_MODE_ALERT;
	[sAlert show];
	[sAlert release];
}

@end
