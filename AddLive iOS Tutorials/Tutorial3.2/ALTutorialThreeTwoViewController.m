//
//  ALViewController.m
//  Tutorial4.1
//
//  Created by Juan Docal on 21.03.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import "ALTutorialThreeTwoViewController.h"
#import <AVFoundation/AVFoundation.h>

#define kEventInfo @"eventInfo"

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

- (void) onVideoFrameSizeChanged:(ALVideoFrameSizeChangedEvent*) event;

- (void) onUserEvent:(ALUserStateChangedEvent *)event;

- (void) onSpeechActivity:(ALSpeechActivityEvent *)event;

- (void) onSessionReconnected:(ALSessionReconnectedEvent *)event;

@end

@interface ALTutorialThreeTwoViewController ()
{
    ALService*                _alService;
    NSArray*                  _cams;
    NSNumber*                 _selectedCam;
    NSString*                 _localVideoSinkId;
    BOOL                      _paused;
    BOOL                      _settingCam;
    BOOL                      _localPreviewStarted;
    MyServiceListener*        _listener;
    BOOL                      _connecting;
    BOOL                      _isFirstOneFeeding;
    BOOL                      _isSecondOneFeeding;
    long long                 _firstUserId;
    long long                 _secondUserId;
    BOOL                      _micFunctional;
}
@end

@implementation ALTutorialThreeTwoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _paused = NO;
    _settingCam = NO;
    _isFirstOneFeeding = NO;
    _isSecondOneFeeding = NO;
    _listener = [[MyServiceListener alloc] init];
    [self initAddLive];
    _connecting = NO;
    
    NSDictionary* mapping = @{@"onUserJoined":[NSValue valueWithPointer:@selector(onUserJoined:)],
                              @"onUserDisjoined":[NSValue valueWithPointer:@selector(onUserDisjoined:)]};
    
    [mapping enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:[obj pointerValue]
                                                     name:key
                                                   object:nil];
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/**
 * Receives the notification when an user joins the room
 */
- (void) onUserJoined:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onUserEvent defined in the ALServiceListener
    ALUserStateChangedEvent* event = [userInfo objectForKey:kEventInfo];
    
    // If the first VideoView is not active.
    if(!_isFirstOneFeeding){
        
        // Set it's sinkId.
        [_firstRemoteVV setSinkId:event.videoSinkId];
        
        // Start the video.
        [_firstRemoteVV start:[[ALResponder alloc] initWithSelector:@selector(onRemoteRenderStarted:)
                                                         withObject:self]];
        
        // Update the flags.
        _isFirstOneFeeding = YES;
        _firstUserId = event.userId;
        
    } else if (!_isSecondOneFeeding) {
        
        // Set it's sinkId.
        [_secondRemoteVV setSinkId:event.videoSinkId];
        
        // Start the video.
        [_secondRemoteVV start:[[ALResponder alloc] initWithSelector:@selector(onRemoteRenderStarted:)
                                                          withObject:self]];
        
        // Update the flags.
        _isSecondOneFeeding = YES;
        _secondUserId = event.userId;
    }
}

/**
 * Receives the notification when an user leaves the room
 */
- (void) onUserDisjoined:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // We get the details of the event sent by the event onUserEvent defined in the ALServiceListener
    ALUserStateChangedEvent* event = [userInfo objectForKey:kEventInfo];
    
    // If the first one feeding is disconnected.
    if(event.userId == _firstUserId){
        
        // Stop the video.
        [_firstRemoteVV stop:[[ALResponder alloc] initWithSelector:@selector(onRemoteRenderStopped:)
                                                        withObject:self]];
        
        // Update the flag.
        _isFirstOneFeeding = NO;
    } else if (event.userId == _secondUserId) {
        
        // Stop the video.
        [_secondRemoteVV stop:[[ALResponder alloc] initWithSelector:@selector(onRemoteRenderStopped:)
                                                         withObject:self]];
        
        // Update the flag.
        _isSecondOneFeeding = NO;
    }
}

/**
 * Responder method called when the remote render starts
 */
- (void) onRemoteRenderStarted:(ALError*) err
{
    if([self handleErrorMaybe:err where:@"onRemoteRenderStarted:"]) {
        NSLog(@"Failed to start the rendering due to: %@ (ERR_CODE:%d)",
              err.err_message, err.err_code);
        return;
    } else {
        NSLog(@"Remote Rendering started");
    }
}

/**
 * Responder method called when the remote render stops
 */
- (void) onRemoteRenderStopped:(ALError*) err
{
    if([self handleErrorMaybe:err where:@"onRemoteRenderStopped:"]) {
        NSLog(@"Failed to stop the rendering due to: %@ (ERR_CODE:%d)",
              err.err_message, err.err_code);
        return;
    } else {
        NSLog(@"Remote Rendering stopped");
    }
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
        if([self handleErrorMaybe:err where:@"Connect"]) {
            return;
        }
        NSLog(@"Successfully connected");
        _stateLbl.text = @"Connected";
        _connectBtn.hidden = YES;
        _disconnectBtn.hidden = NO;
        [_alService monitorSpeechActivity:Consts.SCOPE_ID enable:YES responder:nil];
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
        [_firstRemoteVV stop:nil];
        [_secondRemoteVV stop:nil];
    };
    [_alService disconnect:Consts.SCOPE_ID responder:[ALResponder responderWithBlock:onDisconn]];
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
    
    _settingCam = YES;
    [_alService startLocalVideo:[[ALResponder alloc] initWithSelector:@selector(onLocalVideoStarted:withSinkId:)
                                                           withObject:self]];
    
    [_alService addServiceListener:_listener responder:nil];
    
    // Setting the service to the remote video views
    [_firstRemoteVV setupWithService:_alService withSink:@""];
    [_secondRemoteVV setupWithService:_alService withSink:@""];
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
    [self.localPreviewVV setupWithService:_alService withSink:sinkId withMirror:YES];
    [self.localPreviewVV start:[ALResponder responderWithSelector:@selector(onRenderStarted:) object:self]];
    
    // Enabling the button
    self.connectBtn.enabled = YES;
    
    _localVideoSinkId = [sinkId copy];
    _settingCam = NO;
}

/**
 * Responder method called when the render starts
 */
- (void) onRenderStarted:(ALError*) err
{
    if([self handleErrorMaybe:err where:@"onRenderStarted:"])
    {
        return;
    }
    NSLog(@"Rendering started");
    _localPreviewStarted = YES;
    _stateLbl.text = @"Platform Ready";
    _connectBtn.hidden = NO;
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

/**
 * Stops the render.
 */
- (void) pause
{
    NSLog(@"Application will pause");
    [self.localPreviewVV stop:nil];
    [_alService stopLocalVideo:nil];
    _paused = YES;
}

/**
 * Starts the render.
 */
- (void) resume
{
    if(!_paused)
    return;
    NSLog(@"Application will resume");
    [_alService startLocalVideo:[[ALResponder alloc]
                                 initWithSelector:@selector(onLocalVideoStarted:withSinkId:)
                                 withObject:self]];
    _paused = NO;
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
    return @"iOS";
}

@end


@implementation MyServiceListener

/**
 * Listener to capture an user event. (user joining media scope, user leaving media scope,
 * user publishing or stop publishing any of possible media streams.)
 */
- (void) onUserEvent:(ALUserStateChangedEvent *)event
{
    if(event.isConnected)
    {
        NSLog(@"Got user connected: %@", event);
        NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
        [userInfo setValue:event forKey:kEventInfo];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"onUserJoined" object:self userInfo:userInfo];
    }
    else
    {
        NSLog(@"Got user disconnected: %@", event);
        NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
        [userInfo setValue:event forKey:kEventInfo];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"onUserDisjoined" object:self userInfo:userInfo];
    }
}

/**
 * Event describing a change of a resolution in a video feed produced by given video sink.
 */
- (void) onVideoFrameSizeChanged:(ALVideoFrameSizeChangedEvent*) event
{
    NSLog(@"Got video frame size changed. Sink id: %@, dims: %dx%d", event.sinkId,event.width,event.height);
}

- (void) onSpeechActivity:(ALSpeechActivityEvent *)event
{
    // TODO select video depending on the active speaker.
    NSLog(@"Got speech activity event: %@", event);
}

- (void) onSessionReconnected:(ALSessionReconnectedEvent *)event {
    NSLog(@"On Session reconnected");
}

@end
