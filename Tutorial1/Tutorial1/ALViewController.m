//
//  ALViewController.m
//  Tutorial1
//
//  Created by Tadeusz Kozak on 8/26/13.
//  Copyright (c) 2013 AddLive. All rights reserved.
//

#import "ALViewController.h"

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

@interface ALViewController ()

@end

@implementation ALViewController

- (void)viewDidLoad
{
    NSLog(@"View Did Load");
    [super viewDidLoad];
    [self initAddLive];
}


/**
 * Initializes the AddLive SDK.
 */
- (void) initAddLive
{
    // 1. Allocate the ALService
    self.alService = [ALService alloc];
    
    // 2. Prepare the responder
    ALResponder* responder =[[ALResponder alloc] initWithSelector:@selector(onPlatformReady:)
                                                       withObject:self];
    
    // 3. Prepare the init Options. Make sure to init the options.
    ALInitOptions* initOptions = [[ALInitOptions alloc] init];

    initOptions.applicationId = Consts.APP_ID;
    initOptions.apiKey = Consts.API_KEY;
    
    // 4. Request the platform to initialize itself. Once it's done, the onPlatformReady will be called.
    [self.alService initPlatform:initOptions
                       responder:responder];
}

/**
 * Called by platform when the initialization is complete.
 */
- (void) onPlatformReady:(ALError*) err
{
    NSLog(@"Got platform ready");
    if(err)
    {
        [self handleError:err where:@"platformInit"];
        return;
    }
    NSLog(@"Calling getVersion");
    [self.alService getVersion:[[ALResponder alloc] initWithSelector:@selector(onVersion:version:) withObject:self]];
}

/**
 * Handles the result of the [ALService getVersion:version:] method.
 */
- (void) onVersion:(ALError*) err version:(NSString*) version
{
    NSLog(@"Got version");
    if(err)
    {
        [self handleError:err where:@"getVersion"];
        return;
    }
    self.versionLbl.text = version;
    self.versionLbl.textColor = GREEN;

}

- (void) handleError:(ALError*)err where:(NSString*)where
{
    NSString* msg = [NSString stringWithFormat:@"Got an error with %@: %@ (%d)",
                     where, err.err_message, err.err_code];
    NSLog(@"%@", msg);
    self.versionLbl.text = @"Error";
    self.errorLbl.hidden = NO;
    self.errorContentLbl.text = msg;
    self.errorContentLbl.hidden = NO;
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

@implementation Consts

+ (NSNumber*) APP_ID {
    // TODO update this to use some real value
    return @1;
}

+ (NSString*) API_KEY {
    // TODO update this to use some real value
    return @"SomeApiKey";
}

@end

