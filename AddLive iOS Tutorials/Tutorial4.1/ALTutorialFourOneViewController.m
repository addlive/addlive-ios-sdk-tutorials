//
//  ALViewController.m
//  Tutorial4.1
//
//  Created by Juan Docal on 21.03.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import "ALTutorialFourOneViewController.h"
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

@interface MyServiceListener : NSObject <ALServiceListener>

- (void) onVideoFrameSizeChanged:(ALVideoFrameSizeChangedEvent*) event;

- (void) onUserEvent:(ALUserStateChangedEvent *)event;

- (void) onSpeechActivity:(ALSpeechActivityEvent *)event;

- (void) onSessionReconnected:(ALSessionReconnectedEvent *)event;

@end

@interface ALTutorialFourOneViewController ()
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
}
@end

// TODO #review, this actually should be tutorial 3.2 not 4.1. It's not related to speakers activity API at all.
@implementation ALTutorialFourOneViewController

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
    
    // TODO #review maybe try to improve this by sth like:
    //    NSDictionary* mapping = @{@"onUserEvent":@selector(onUserEvent:)}
    //    [mapping enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    //        [[NSNotificationCenter defaultCenter] addObserver:self
    //                                                 selector:obj
    //                                                     name:key
    //                                                   object:nil];
    //    }];
    // use this pattern to avoid repetition here. It may be overkill for two, but with this struct the code is more
    // flexible for future changes - it's easier to add new listeners. And in tutorial 8 it definitely starts to make
    // sense.
    
    // TODO #review, also when dispatching the notification, use some constant instead of @"event" so it is checked
    // compile time not debugged in runtime :)

    
    // Notification triggered when an user join the session
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUserJoined:)
                                                 name:@"onUserJoined"
                                               object:nil];
    
    // Notification triggered when an user disjoin the session
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUserDisjoined:)
                                                 name:@"onUserDisjoined"
                                               object:nil];
}

/**
 * Receives the notification when an user joins the room
 */
- (void) onUserJoined:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onUserEvent defined in the ALServiceListener
    ALUserStateChangedEvent* event = [userInfo objectForKey:@"event"];
    
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
    ALUserStateChangedEvent* event = [userInfo objectForKey:@"event"];
    
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
    if(err) {
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
    if(err) {
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
    AVAudioSession *session = [AVAudioSession sharedInstance];
    if ([session respondsToSelector:@selector(requestRecordPermission:)]) {
        [session performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
            if (granted) {
                NSLog(@"Mic. is enabled.");
                descr.autopublishAudio = YES;
            }
            else {
                NSLog(@"Mic. is disabled.");
                descr.autopublishAudio = NO;
            }
        }];
    }
    
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
    
    // 4. Request the platform to initialize itself. Once it's done, the onPlatformReady will be called.
    [_alService initPlatform:initOptions
                   responder:responder];
    
    _stateLbl.text = @"Platform init";
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
    // TODO #review remove this, let's use platform default camera
    [_alService getVideoCaptureDeviceNames:[[ALResponder alloc]
                                            initWithSelector:@selector(onCams:devs:)
                                            withObject:self]];
    [_alService addServiceListener:_listener responder:nil];
    
    // Setting the service to the remote video views
    [_firstRemoteVV setupWithService:_alService withSink:@""];
    [_secondRemoteVV setupWithService:_alService withSink:@""];
}

/**
 * Responder method called when getting the devices
 */
- (void) onCams:(ALError*)err devs:(NSArray*)devs
{
    if (err)
    {
        NSLog(@"Got an error with getVideoCaptureDeviceNames: %@", err );
        return;
    }
    NSLog(@"Got camera devices");
    
    _cams = [devs copy];
    _selectedCam  = [NSNumber numberWithInt:1];
    ALDevice* dev =[_cams objectAtIndex:_selectedCam.unsignedIntValue];
    [_alService setVideoCaptureDevice:dev.id
                            responder:[[ALResponder alloc] initWithSelector:@selector(onCamSet:)
                                                                 withObject:self]];
}

/**
 * Responder method called when setting a cam
 */
- (void) onCamSet:(ALError*) err
{
    NSLog(@"Video device set");
    _settingCam = YES;
    [_alService startLocalVideo:[[ALResponder alloc] initWithSelector:@selector(onLocalVideoStarted:withSinkId:)
                                                           withObject:self]];
}

/**
 * Responder method called when the local video starts
 */
- (void) onLocalVideoStarted:(ALError*)err withSinkId:(NSString*) sinkId
{
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
    if(err)
    {
        NSLog(@"Failed to start the rendering due to: %@ (ERR_CODE:%d)",
              err.err_message, err.err_code);
    }
    else
    {
        NSLog(@"Rendering started");
        _localPreviewStarted = YES;
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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
    return @"AddLiveSuperSecret";
}

+ (NSString*) SCOPE_ID
{
    return @"ADL_iOS";
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
        [userInfo setValue:event forKey:@"event"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"onUserJoined" object:self userInfo:userInfo];
    }
    else
    {
        NSLog(@"Got user disconnected: %@", event);
        NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
        [userInfo setValue:event forKey:@"event"];
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
