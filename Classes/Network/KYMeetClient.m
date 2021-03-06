////
//  KYMeetClient.m
//  Kaya Meet
//
//  Copyright Kaya Labs, Inc. All rights reserved.
//

#import "kaya_meetAppDelegate.h"
#import "KYMeetClient.h"
#import "StringUtil.h"
#import "JSON.h"


@implementation KYMeetClient

@synthesize request;
@synthesize context;
@synthesize hasError;
@synthesize errorMessage;
@synthesize errorDetail;

NSString *KAYAMEET_SITE_NAME = @"http://www.kayameet.com" ;

//NSString *KAYAMEET_SITE_NAME = @"http:/0.0.0.0:3000" ;

- (id)initWithTarget:(id)aDelegate action:(SEL)anAction
{
    [super initWithDelegate:aDelegate];
    action = anAction;
    hasError = false;
    return self;
}

- (void)dealloc
{
    [errorMessage release];
    [errorDetail release];
    [super dealloc];
}

- (void)getUserMeets:(NSDictionary*)params withUserId:(uint32_t)userId
{
	needAuth      = true;
    NSString *url = [NSString stringWithFormat:@"%@/users/%ld/meets", KAYAMEET_SITE_NAME,userId];
	request = KAYAMEET_REQUEST_GET_USERMEETS;
	// can pass parameters through body if needed
    [super get:url param:params]; 
}


// get meet details by the meetId
- (void)getMeet:(NSDictionary*)params withMeetId:(uint32_t)meetId
{
	needAuth      = true;
    NSString *url = [NSString stringWithFormat:@"%@/meets/%ld", KAYAMEET_SITE_NAME,meetId];
	request = KAYAMEET_REQUEST_GET_MEET;
	// can pass parameters through body if needed
    [super get:url param:params];
}

// get posted meet update until the meetId show
- (void)getMeet:(NSDictionary*)params withPostId:(uint32_t)postId
{
	needAuth      = true;
    NSString *url = [NSString stringWithFormat:@"%@/mposts/%ld", KAYAMEET_SITE_NAME,postId];
	request = KAYAMEET_REQUEST_GET_MEET;
	// can pass parameters through body if needed
    [super get:url param:params];
}

// post meet 

- (void)postMeet:(NSDictionary*)params
{
    needAuth = true;
	request = KAYAMEET_REQUEST_POST_MEET;
    NSString* url = [NSString stringWithFormat:@"%@/mposts",KAYAMEET_SITE_NAME];
    NSString *postString = [KYConnection generateBodyString:nil params:params];
	
	//NSLog(@"%@ -d %@",url,postString);
    [self post:url body:postString];
}

// post Invitation
- (void)postInvite:(NSString*)invitee  byUserId:(uint32_t)userId byMeetId:(uint64_t)meetId custMessage:(NSString*)message
{
	needAuth = true;
	request = KAYAMEET_REQUEST_POST_INVITE;
	NSString* url = [NSString stringWithFormat:@"%@/meets/%ld/invitations",KAYAMEET_SITE_NAME, meetId];
	NSString* inviteString = [NSString stringWithFormat:@"invitee=%@&message=%@",invitee,message] ;
	[self post:url body:inviteString];
}


// post Message (including photo)
- (void)postMessage:(NSString*)message toMeetId:(uint64_t)meetId toChatId:(int)chatId photoData:(UIImage*)photo
{
	needAuth = true;
	request = KAYAMEET_REQUEST_POST_MEET;
	NSString* url = [NSString stringWithFormat:@"%@/meets/%ld/chatters",KAYAMEET_SITE_NAME,meetId];
	NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								message, @"content", nil];
	
	// [NSString stringWithFormat:@"%ld", meetId],  @"meet_id",
	
	/* photo
	if( photo != nil )
	{
		[self writeImageToTempFile:photo];
		NSString  *fname = [NSString stringWithFormat:@"@%@",[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/kayameetTempFile.jpg"]];
		NSLog(@"photo=%@",fname);
		[dic  setObject:[NSString stringWithFormat:@"%@",fname] forKey:@"photo"];
	}*/
	
	// reply to chat
	if(chatId > 0)
	{
		[dic setObject:[NSString stringWithFormat:@"%d",chatId] forKey:@"reply_chat_id"];
	}
	[dic setObject:[NSString stringWithFormat:@"test %ld",meetId] forKey:@"testid"];
	NSMutableData *data = [NSMutableData data];
	// When the server can support Data transfer
	NSString *param = [self nameValString:dic];
	NSString *footer = [NSString stringWithFormat:@"\r\n--%@--\r \n", KAYAMEET_FORM_BOUNDARY];
    [data appendData:[param dataUsingEncoding:NSUTF8StringEncoding]];
	
	
	if ( photo != nil ) {
		param = [NSString stringWithFormat:@"--%@", KAYAMEET_FORM_BOUNDARY];
		NSData *jpeg = UIImageJPEGRepresentation(photo, 0.5);
		param = [param stringByAppendingString:@"\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"a.jpeg\"\r \n\r\n"];
		param = [param stringByAppendingString:@"Content-Type: image/jpeg\r\n\r\n"];
		[data appendData:[param dataUsingEncoding:NSUTF8StringEncoding]];
		[data appendData:[NSData dataWithData:jpeg]];

	}	
	[data appendData:[footer dataUsingEncoding:NSUTF8StringEncoding]];
	
	[super post:url data:data] ;
}

// login
- (void)verify
{
    needAuth = false;
	NSString* url = [NSString stringWithFormat:@"%@/sessions", KAYAMEET_SITE_NAME ];
	NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:@"username"];
	NSString *password = [[NSUserDefaults standardUserDefaults] stringForKey:@"password"];					   
	NSString *body = [NSString stringWithFormat:@"&email=%@&password=%@",username,password] ;
	request = KAYAMEET_REQUEST_LOGIN;
    [super post:url body:body];
}

- (void)authError
{
    self.errorMessage = @"Authentication Failed";
    self.errorDetail  = @"Wrong username/Email and password combination.";    
    [delegate performSelector:action withObject:self withObject:nil];    
}

- (void)KYConnectionDidFailWithError:(NSError*)error
{
    hasError = true;
    if (error.code ==  NSURLErrorUserCancelledAuthentication) {
        statusCode = 401;
        [self authError];
    }
    else {
        self.errorMessage = @"Connection Failed";
        self.errorDetail  = [error localizedDescription];
        [delegate performSelector:action withObject:self withObject:nil];
    }
	[self autorelease];
}

-(void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if ([challenge previousFailureCount] == 0) {
        //NSLog(@"Authentication Challenge");
        NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:@"username"];
        NSString *password = [[NSUserDefaults standardUserDefaults] stringForKey:@"password"];
        NSURLCredential* cred = [NSURLCredential credentialWithUser:username password:password persistence:NSURLCredentialPersistenceNone];
        [[challenge sender] useCredential:cred forAuthenticationChallenge:challenge];
    } else {
        //NSLog(@"Failed auth (%d times)", [challenge previousFailureCount]);
        [[challenge sender] cancelAuthenticationChallenge:challenge];
    }
}

- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    hasError = true;
    [self authError];
    [self autorelease];
}

- (void)KYConnectionDidFinishLoading:(NSString*)content
{
    switch (statusCode) {
        case 401: // Not Authorized: either you need to provide authentication credentials, or the credentials provided aren't valid.
            hasError = true;
            [self authError];
            goto out;
            
        case 304: // Not Modified: there was no new data to return.
            [delegate performSelector:action withObject:self withObject:nil];
            goto out;
			
		case 200: // OK: everything went awesome.
        case 400: // Bad Request: your request is invalid, and we'll return an error message that tells you why. 
        case 403: // Forbidden: we understand your request, but are refusing to fulfill it.  An accompanying error message should explain why.
			break;
		case 500: // Internal Server Error: we did something wrong. 
        case 404: // Not Found: either you're requesting an invalid URI or the resource in question doesn't exist (ex: no such user). 
        case 502: // Bad Gateway: returned if  is down or being upgraded.
        case 503: // Service Unavailable: the  servers are up, but are overloaded with requests.  Try again later.
        default:
        {
            hasError = true;
            self.errorMessage = @"Server responded with an error";
            self.errorDetail  = [NSHTTPURLResponse localizedStringForStatusCode:statusCode];
            [delegate performSelector:action withObject:self withObject:nil];
            goto out;
        }
    }

    NSObject *obj = [content JSONValue];
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary* dic = (NSDictionary*)obj;
        NSString *msg = [dic objectForKey:@"error"];
        if (msg) {
            //NSLog(@"Server responded with an error: %@", msg);
            hasError = true;
            self.errorMessage = @" Server Error";
            self.errorDetail  = msg;
        }

    }
    
    [delegate performSelector:action withObject:self withObject:obj];
    
  out:
    [self autorelease];
}

- (void)KYConnectionDidReceieveResponse:(NSURLResponse *)aResponse
{
/*	NSHTTPURLResponse *resp = (NSHTTPURLResponse*)aResponse;
	if (request == KAYAMEET_REQUEST_LOGIN && resp.statusCode / 100 == 2 ) 
	{
		// store session token
		// NSLog(@"%@", resp.allHeaderFields);
		NSString *cookieString = [resp.allHeaderFields objectForKey:@"Set-Cookie"];
		if( cookieString != nil ) {
			NSString *sessionToken = [KYConnection getStringFromUrl:cookieString needle:@"remember_token="];
			if ( sessionToken == nil || sessionToken == @"" )
			{
				hasError = true ;
				self.errorMessage = @" Server Error" ;
				self.errorDetail  = @" Authentication error, missing session token" ;
				return;
			}
			[[NSUserDefaults standardUserDefaults] setObject:sessionToken forKey:@"KYsessionToken"];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
		else {
			hasError = true ;
			self.errorMessage = @" Server Error" ;
            self.errorDetail  = @" Authentication error, missing session token" ;
		}
	}
 */
}

- (void)alert
{
    [[kaya_meetAppDelegate getAppDelegate] alert:errorMessage message:errorDetail];
}

// 
- (void)writeImageToTempFile:(UIImage *)image
{
	// Create paths to output images
	// NSString  *pngPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/kayameetTempFile.png"];
	NSString  *jpgPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/kayameetTempFile.jpg"];
	
	// Write a UIImage to JPEG with minimum compression (best quality)
	// The value 'image' must be a UIImage object
	// The value '1.0' represents image compression quality as value from 0.0 to 1.0
	[UIImageJPEGRepresentation(image, 1.0) writeToFile:jpgPath atomically:YES];
	
	// Write image to PNG
	// [UIImagePNGRepresentation(image) writeToFile:pngPath atomically:YES];
	
	// Let's check to see if files were successfully written...
	
	// Create file manager
	//NSError *error;
	//NSFileManager *fileMgr = [NSFileManager defaultManager];
	
	// Point to Document directory
	//NSString *documentsDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
	
	// Write out the contents of home directory to console
	//NSLog(@"Documents directory: %@", [fileMgr contentsOfDirectoryAtPath:documentsDirectory error:&error]);
	//return [[NSString stringWithFormat:@"@%@",jpgPath] retain];
	return ;
	
}

@end
