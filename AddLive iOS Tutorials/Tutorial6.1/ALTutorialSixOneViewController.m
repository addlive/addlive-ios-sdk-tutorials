//
//  ALViewController.m
//  Tutorial6.1
//
//  Created by Juan Docal on 17.03.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import "ALTutorialSixOneViewController.h"
#import <AVFoundation/AVFoundation.h>

/**
 * Interface defining application constants. In our case it is just the
 * Application id and API key.
 */
@interface Consts : NSObject

+ (NSNumber*) APP_ID;

+ (NSString*) API_KEY;

+ (NSString*) SCOPE_ID;

@end

@interface ALTutorialSixOneViewController ()
{
    ALService*                _alService;
    NSArray*                  _cams;
    NSNumber*                 _selectedCam;
    NSString*                 _localVideoSinkId;
    BOOL                      _paused;
    BOOL                      _settingCam;
    BOOL                      _localPreviewStarted;
    BOOL                      _connecting;
    BOOL                      _outputState;
    BOOL                      _micFunctional;
}
@end

@implementation ALTutorialSixOneViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _paused = NO;
    _settingCam = NO;
    [super viewDidLoad];
    [self initAddLive];
    _connecting = NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/**
 * Button action to start the connection.
 */
- (IBAction)connect:(id)sender
{
    if(_connecting) {
        return;
    }
    _connecting = YES;
    _stateLbl.text = @"Connecting...";
    ALConnectionDescriptor* descr = [[ALConnectionDescriptor alloc] init];
    descr.scopeId = Consts.SCOPE_ID;
    
    // Setting the audio according to the mic access.
    if(_micFunctional) {
        NSLog(@"Mic. is enabled.");
        descr.autopublishAudio = YES;
    } else {
        NSLog(@"Mic. is disabled.");
        descr.autopublishAudio = NO;
    }
    
    descr.autopublishVideo = NO;
    descr.authDetails.userId = rand() % 1000;
    descr.authDetails.expires = time(0) + (60 * 60);
    descr.authDetails.salt = @"Super random string";
    
    ResultBlock onConn = ^(ALError* err, id nothing) {
        _connecting = NO;
        if([self handleErrorMaybe:err where:@"Connect"]) {
            return;
        }
        NSLog(@"Successfully connected");
        _stateLbl.text = @"Connected";
        _connectBtn.hidden = YES;
        _disconnectBtn.hidden = NO;
    };
    [_alService connect:descr responder:[ALResponder responderWithBlock:onConn]];
}

/**
 * Button action to start disconnecting.
 */
- (IBAction)disconnect:(id)sender
{
    ResultBlock onDisconn = ^(ALError* err, id nothing) {
        if([self handleErrorMaybe:err where:@"onDisconn:"])
        {
            return;
        }
        NSLog(@"Successfully disconnected");
        _stateLbl.text = @"Disconnected";
        _connectBtn.hidden = NO;
        _disconnectBtn.hidden = YES;
    };
    [_alService disconnect:Consts.SCOPE_ID
                 responder:[ALResponder responderWithBlock:onDisconn]];
}

/**
 * Button action to toggle the output.
 */
- (IBAction)toggle:(id)sender
{
    if(_outputState){
        [_alService setAudioOutputDevice:ALAudioOutputDevice.kLoudSpeaker responder:nil];
        _outputState = false;
    } else {
        [_alService setAudioOutputDevice:ALAudioOutputDevice.kFrontSpeaker responder:nil];
        _outputState = true;
    }
}

/**
 * Initializes the AddLive SDK.
 * For a more detailed explanation about the initialization please check Tutorial 1.
 */
- (void) initAddLive
{
    _alService = [ALService alloc];
    ALResponder* responder =[[ALResponder alloc] initWithSelector:@selector(onPlatformReady:withInitResult:)
                                                       withObject:self];
    
    ALInitOptions* initOptions = [[ALInitOptions alloc] init];
    initOptions.applicationId = Consts.APP_ID;
    initOptions.apiKey = Consts.API_KEY;
    initOptions.logInteractions = YES;
    [_alService initPlatform:initOptions
                   responder:responder];
    
    _stateLbl.text = @"Platform init";
}

/**
 * Called by platform when the initialization is complete.
 */
- (void) onPlatformReady:(ALError*) err withInitResult:(ALInitResult*)initResult
{
    NSLog(@"Got platform ready");
    if([self handleErrorMaybe:err where:@"onPlatformReady:withInitResult:"])
    {
        return;
    }
    
    _micFunctional = initResult.micFunctional;
    
    _connectBtn.hidden = NO;
}

/**
 * Handles the possible error coming from the sdk
 */
- (BOOL) handleErrorMaybe:(ALError*)err where:(NSString*)where
{
    if(!err) {
        return NO;
    }
    NSString* msg = [NSString stringWithFormat:@"Got an error with %@: %@ (%d)",
                     where, err.err_message, err.err_code];
    NSLog(@"%@", msg);
    self.errorLbl.hidden = NO;
    self.errorContentLbl.text = msg;
    self.errorContentLbl.hidden = NO;
    return YES;
}

@end

@implementation Consts

+ (NSNumber*) APP_ID {
    // TODO update this to use some real value
    return @1;
}

+ (NSString*) API_KEY {
    // TODO update this to use some real value
    return @"";
}

+ (NSString*) SCOPE_ID {
    return @"iOS";
}

@end
