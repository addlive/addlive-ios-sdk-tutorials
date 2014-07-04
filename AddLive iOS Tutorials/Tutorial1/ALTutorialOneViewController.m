//
//  ALTutorialOneViewController.m
//  Tutorial1
//
//  Created by Tadeusz Kozak on 8/26/13.
//  Copyright (c) 2013 AddLive. All rights reserved.
//

#import "ALTutorialOneViewController.h"

#define RED [UIColor colorWithRed:225 green:0 blue:0 alpha:1.0]
#define GREEN [UIColor colorWithRed:0 green:255 blue:0 alpha:1.0]

/**
 * Interface defining application constants. In our case it is just the 
 * Application id and API key.
 */
@interface Consts : NSObject

+ (NSNumber*) APP_ID;

+ (NSString*) API_KEY;

@end

@interface ALTutorialOneViewController ()

@end

@implementation ALTutorialOneViewController {
    ALService* _alService;
}

- (void)viewDidLoad
{
    NSLog(@"View Did Load");
    [super viewDidLoad];
    [self initAddLive];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/**
 * Initializes the AddLive SDK.
 */
- (void) initAddLive
{
    // 1. Allocate the ALService
    _alService = [ALService alloc];
    
    // 2. Prepare the responder
    ALResponder* responder =[[ALResponder alloc] initWithSelector:@selector(onPlatformReady:)
                                                       withObject:self];
    
    // 3. Prepare the init Options. Make sure to init the options.
    ALInitOptions* initOptions = [[ALInitOptions alloc] init];

    // Configure the application id
    initOptions.applicationId = Consts.APP_ID;
    
    // Set the apiKey to let the SDK automatically authenticate all connection requests.
    // Please note that such an approach reduces slightly the security. It is always a good idea
    // not to pass the API key to the client side and implement a server side component that
    // generates the signature when needed.
    initOptions.apiKey = Consts.API_KEY;
    
    // Property that enables logging of all application <> SDK interactions using NSLog.
    initOptions.logInteractions = YES;
    
    // 4. Request the platform to initialize itself. Once it's done, the onPlatformReady will be called.
    [_alService initPlatform:initOptions responder:responder];
}

/**
 * Called by platform when the initialization is complete.
 */
- (void) onPlatformReady:(ALError*) err
{
    NSLog(@"Got platform ready");
    if(err)
    {
        [self handleErrorMaybe:err where:@"platformInit"];
        return;
    }
    NSLog(@"Calling getVersion");
    [_alService getVersion:[[ALResponder alloc] initWithSelector:@selector(onVersion:version:) withObject:self]];
}

/**
 * Handles the result of the [ALService getVersion:version:] method.
 */
- (void) onVersion:(ALError*) err version:(NSString*) version
{
    NSLog(@"Got version");
    if(err)
    {
        [self handleErrorMaybe:err where:@"getVersion"];
        return;
    }
    self.versionLbl.text = version;
    self.versionLbl.textColor = GREEN;
    [self performSelector:@selector(disposePlatform) withObject:nil afterDelay:2.0];
}

/**
 * Releases the AddLive SDK.
 * Please note that the releasePlatform method CANNOT be called from within 
 * AddLive result handler or event handler.
 */
- (void) disposePlatform
{
    NSLog(@"Disposing platform");
    [_alService releasePlatform];
    self.versionLbl.text = @"Platform released";
    [self.versionLbl sizeToFit];
    self.versionLbl.center = self.view.center;
    self.versionLbl.textColor = GREEN;
}

/**
 * Handles the possible error coming from the sdk
 */
- (void) handleErrorMaybe:(ALError*)err where:(NSString*)where
{
    NSString* msg = [NSString stringWithFormat:@"Got an error with %@: %@ (%d)",
                     where, err.err_message, err.err_code];
    NSLog(@"%@", msg);
    self.versionLbl.text = @"Error";
    self.errorLbl.hidden = NO;
    self.errorContentLbl.text = msg;
    self.errorContentLbl.hidden = NO;
}

@end

@implementation Consts

+ (NSNumber*) APP_ID
{
    // TODO update this to use some real value
    return @1;
}

+ (NSString*) API_KEY
{
    // TODO update this to use some real value
    return @"";
}

@end

