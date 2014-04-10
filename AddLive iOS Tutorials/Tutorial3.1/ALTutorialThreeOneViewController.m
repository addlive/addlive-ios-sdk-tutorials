//
//  ALViewController.m
//  Tutorial3.1
//
//  Created by Juan Docal on 25.03.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import "ALTutorialThreeOneViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "ALCamera.h"

/**
 * Interface defining application constants. In our case it is just the
 * Application id and API key.
 */
@interface Consts : NSObject

+ (NSNumber*) APP_ID;

+ (NSString*) API_KEY;

+ (NSString*) SCOPE_ID;

@end

@interface MyServiceListener : NSObject <ALServiceListener>

- (id) initWithRemoteVideoView:(ALVideoView*) view;

- (void) userEvent:(ALUserStateChangedEvent *)event;

- (void) onConnectionLost:(ALConnectionLostEvent *)event;

- (void) onSessionReconnected:(ALSessionReconnectedEvent *)event;

@end

@interface ALTutorialThreeOneViewController ()
{
    ALService*                _alService;
    NSArray*                  _cams;
    NSNumber*                 _selectedCam;
    NSString*                 _localVideoSinkId;
    BOOL                      _settingCam;
    MyServiceListener*        _listener;
    ALVideoView*              _localPreviewVV;
    BOOL                      _connecting;
    BOOL                      _micFunctional;
}

@property(nonatomic,retain) ALCamera* externalCamera;

@end

@implementation ALTutorialThreeOneViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _listener = [[MyServiceListener alloc] initWithRemoteVideoView:_remoteVV];
    [self initAddLive];
    _settingCam = NO;
    _connecting = NO;
}

/**
 * Button action to start the connection.
 */
- (IBAction)connect:(id)sender
{
    if(_connecting)
    {
        return;
    }
    // External camera.
    self.externalCamera = [[ALCamera alloc] initWithService:_alService];
    [self.externalCamera start];
    
    _connecting = YES;
    _stateLbl.text = @"Connecting...";
    ALConnectionDescriptor* descr = [[ALConnectionDescriptor alloc] init];
    descr.scopeId = Consts.SCOPE_ID;
    
    // Setting the audio according to the mic access.
    descr.autopublishAudio = _micFunctional;
    
    descr.autopublishVideo = YES;
    descr.authDetails.userId = rand() % 1000;
    descr.authDetails.expires = time(0) + (60 * 60);
    descr.authDetails.salt = @"Super random string";
    
    ResultBlock onConn = ^(ALError* err, id nothing) {
        _connecting = NO;
        if([self handleErrorMaybe:err where:@"Connect"])
        {
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
        if([self handleErrorMaybe:err where:@"onDisconn"])
        {
            return;
        }
        NSLog(@"Successfully disconnected");
        _stateLbl.text = @"Disconnected";
        _connectBtn.hidden = NO;
        _disconnectBtn.hidden = YES;
        [self.externalCamera stop];
        [_remoteVV stop:nil];
    };
    [_alService disconnect:Consts.SCOPE_ID responder:[ALResponder responderWithBlock:onDisconn]];
}

/**
 * Initializes the AddLive SDK.
 */
- (void) initAddLive
{
    // 1. Allocate the ALService
    _alService = [ALService alloc];
    
    // 2. Prepare the responder
    ALResponder* responder =[[ALResponder alloc] initWithSelector:@selector(onPlatformReady:withInitResult:)
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
    
    // Flag to enable/disable external video input.
    initOptions.externalVideoInput = YES;
    
    // Property that enables logging of all application <> SDK interactions using NSLog.
    initOptions.logInteractions = YES;
    
    // Allowing one to skip the devices initialisation phase. By default, the platform will try
    // to setup the devices to sane default values. With this flag set to NO, the devices init phase
    // is aborted. It’s especially useful for applications not using camera device on OSX, as this
    // will not make the camera active when the user does not expect it. Or in a case when it is not
    // expected by the user to see camera as active during the platform initialisation.
    initOptions.initDevices = NO;
    
    // 4. Request the platform to initialize itself. Once it's done, the onPlatformReady will be called.
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
    _stateLbl.text = @"Platform Ready";
    _connectBtn.hidden = NO;
    
    _micFunctional = initResult.micFunctional;
    
    [_alService getVideoCaptureDeviceNames:[[ALResponder alloc]
                                            initWithSelector:@selector(onCams:devs:)
                                            withObject:self]];
    
    [_alService addServiceListener:_listener responder:nil];
    [_remoteVV setupWithService:_alService withSink:@""];
}

/**
 * Responder method called when getting the devices
 */
- (void) onCams:(ALError*)err devs:(NSArray*)devs
{
    if ([self handleErrorMaybe:err where:@"onCams:devs:"])
    {
        return;
    }
    NSLog(@"Got camera devices");
    
    _cams = [devs copy];
    _selectedCam  = [NSNumber numberWithInt:0];
    ALDevice* dev =[_cams objectAtIndex:_selectedCam.unsignedIntValue];
    
    // Block called when setting a cam
    ResultBlock onCamSet = ^(ALError* err, id nothing)
    {
        NSLog(@"Video device set");
        _settingCam = YES;
        [_alService startLocalVideo:[[ALResponder alloc] initWithSelector:@selector(onLocalVideoStarted:withSinkId:)
                                                               withObject:self]];
    };
    
    [_alService setVideoCaptureDevice:dev.id
                            responder:[ALResponder responderWithBlock:onCamSet]];
}

/**
 * Responder method called when the local video starts
 */
- (void) onLocalVideoStarted:(ALError*)err withSinkId:(NSString*) sinkId
{
    if([self handleErrorMaybe:err where:@"onLocalVideoStarted:withSinkId:"])
    {
        return;
    }
    NSLog(@"Got local video started. Will render using sink: %@",sinkId);
    [_localPreviewVV setupWithService:_alService withSink:sinkId withMirror:YES];
    [_localPreviewVV start:[ALResponder responderWithSelector:@selector(onRenderStarted:) object:self]];
    _localVideoSinkId = [sinkId copy];
    _settingCam = NO;
}

/**
 * Responder method called when the render starts
 */
- (void) onRenderStarted:(ALError*) err
{
    if(err)
    {
        NSLog(@"Failed to start the rendering due to: %@ (ERR_CODE:%d)",
              err.err_message, err.err_code);
        return;
    }
    else
    {
        NSLog(@"Rendering started");
        _stateLbl.text = @"Platform Ready";
        _connectBtn.hidden = NO;
    }
}

/**
 * Handles the possible error coming from the sdk
 */
- (BOOL) handleErrorMaybe:(ALError*)err where:(NSString*)where
{
    if(!err)
    {
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

+ (NSString*) SCOPE_ID
{
    // TODO
    return @"iOS";
}

@end


@implementation MyServiceListener
{
    ALVideoView* _videoView;
}

/**
 * Method to init the remote view within it's view.
 */
- (id) initWithRemoteVideoView:(ALVideoView*) view
{
    self = [super init];
    if(self) {
        _videoView = view;
    }
    return self;
}

/**
 * Listener to capture an user event. (user joining media scope, user leaving media scope,
 * user publishing or stop publishing any of possible media streams.)
 */
- (void) userEvent:(ALUserStateChangedEvent *)event
{
    NSLog(@"Got an user event: %@", event);
    if(event.isConnected)
    {
        ResultBlock onStopped = ^(ALError* err, id nothing){
            [_videoView setSinkId:event.videoSinkId];
            [_videoView start:nil];
        };
        [_videoView stop:[ALResponder responderWithBlock:onStopped]];
    }
    else
    {
        [_videoView stop:nil];
    }
}

/**
 * Event describing a lost connection.
 */
- (void) onConnectionLost:(ALConnectionLostEvent *)event
{
    NSLog(@"Got connection lost");
}

/**
 * Event describing a reconnection.
 */
- (void) onSessionReconnected:(ALSessionReconnectedEvent *)event
{
    NSLog(@"On Session reconnected");
}

@end
