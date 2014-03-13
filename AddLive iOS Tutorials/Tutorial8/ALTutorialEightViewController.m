//
//  ALTutorialEightViewController.m
//  Tutorial8
//
//  Created by Juan Docal on 08.02.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import "ALTutorialEightViewController.h"

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

- (void) onConnectionLost:(ALConnectionLostEvent *)event;

- (void) onSessionReconnected:(ALSessionReconnectedEvent *)event;

@end

@interface ALTutorialEightViewController ()

{
    ALService*                _alService;
    NSArray*                  _cams;
    NSNumber*                 _selectedCam;
    NSString*                 _localVideoSinkId;
    NSString*                 _currentVideoSinkId;
    long long                 _currentVideoUserId;
    BOOL                      _paused;
    BOOL                      _settingCam;
    BOOL                      _localPreviewStarted;
    BOOL                      _connecting;
    MyServiceListener*        _listener;
    ALVideoView*              _remoteVV;
    NSMutableDictionary*      _videoSinkIdDictionary;
    NSMutableDictionary*      _speakersActivityDictionary;
    NSMutableDictionary*      _speechUserIdDictionary;
    int                       _checkTimer;
    float                     _remoteVideoWidth;
    float                     _remoteVideoHeight;
    float                     _remoteVideoLeft;
    float                     _remoteVideoTop;
    float                     _videoWidth;
    float                     _videoHeight;
    float                     _left;
}
@end

@implementation ALTutorialEightViewController

- (void)viewDidLoad
{
    _paused = NO;
    _settingCam = NO;
    [super viewDidLoad];
    
    // Defining values to set the VideoView size properly
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        _remoteVideoWidth = 480;
        _remoteVideoHeight = 640;
        _remoteVideoLeft = 205;
        _remoteVideoTop = 86;
    }
    else
    {
        _remoteVideoWidth = 239;
        _remoteVideoHeight = 320;
        _remoteVideoLeft = 73;
        _remoteVideoTop = 107;
    }
    
    _listener = [[MyServiceListener alloc] init];
    [self initAddLive];
    _connecting = NO;
    
    // Setting the frame for the remoteVideoView (iPad or iPhone).
    CGRect frame;
    frame.origin.x = _remoteVideoLeft;
    frame.origin.y = _remoteVideoTop;
    frame.size.width = _remoteVideoWidth;
    frame.size.height = _remoteVideoHeight;
    
    // Initializing the remoteVideoView.
    _remoteVV = [[ALVideoView alloc] initWithFrame:frame];
    _remoteVV.backgroundColor = [UIColor lightGrayColor];
    
    [self.view addSubview:_remoteVV];
    
    // Notification triggered when an user join the session.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUserEvent:)
                                                 name:@"onUserEvent"
                                               object:nil];
    
    // Notification triggering the speech activity.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onSpeechActivity:)
                                                 name:@"onSpeechActivity"
                                               object:nil];
    
    // Notification triggered when a frame size event is triggered
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onVideoFrameSizeChanged:)
                                                 name:@"onVideoFrameSizeChanged"
                                               object:nil];
    
    // Notification triggering the media stream event.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onMediaStreamEvent:)
                                                 name:@"onMediaStreamEvent"
                                               object:nil];
    
    // Notification triggered when a frame size event is triggered
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onConnectionLost:)
                                                 name:@"onConnectionLost"
                                               object:nil];
}

/**
 * Receives the notification when an user event occurs
 */
- (void) onUserEvent:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onUserEvent defined in the ALServiceListener
    ALUserStateChangedEvent* event = [userInfo objectForKey:@"event"];
    
    NSLog(@"Got user event: %@", event);
    
    // New user connected
    if(event.isConnected)
    {
        // Add the new user videoSinkId to the historical so we can set it up as a video feeder when speaking.
        [_videoSinkIdDictionary setObject:event.videoSinkId forKey:[NSString stringWithFormat:@"%lld", event.userId]];
        
        // If it's the first time.
        if(!_currentVideoUserId)
        {
            // Getting the videoId.
            if(event.videoPublished)
            {
                _currentVideoSinkId = event.videoSinkId;
            }
            
            // Getting the userId.
            _currentVideoUserId = event.userId;
            
            // Start the video.
            [_remoteVV setupWithService:_alService withSink:_currentVideoSinkId];
            [_remoteVV start:[ALResponder responderWithSelector:@selector(onRemoteRenderStarted:) object:self]];
        }
    }
    else
    {
        // If the user disconnected was the one feeding.
        if(_currentVideoUserId == event.userId)
        {
            _currentVideoSinkId = @"";
            [self updateAllowedSenders];
            [self startVideoWithTheCurrentSpeaker];
        }
    }
}

/**
 * Receives the notification when a frame size event occurs.
 */
- (void) onVideoFrameSizeChanged:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onVideoFrameSizeChanged defined in the ALServiceListener.
    ALVideoFrameSizeChangedEvent* event = [userInfo objectForKey:@"event"];
    
    NSLog(@"Got video frame size changed. Sink id: %@, dims: %dx%d", event.sinkId,event.width,event.height);
    
    // If its the current sink feeding.
    if([event.sinkId isEqualToString:_currentVideoSinkId])
    {
        // Get and set the correct dimensions.
        [self fitDimensions:event.width and:event.height to:_remoteVideoWidth and:_remoteVideoHeight];
        _remoteVV.frame = CGRectMake(_remoteVideoLeft + _left, _remoteVV.frame.origin.y, _videoWidth, _videoHeight);
    }
}


/**
 * Receives the notification when a frame size event occurs.
 */
- (void) onSpeechActivity:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onSpeechActivity defined in the ALServiceListener.
    ALSpeechActivityEvent* event = [userInfo objectForKey:@"event"];
    
    // Getting the values for each user.
    for(int index = 0; index < [event.activeSpeakers count]; index++)
    {
        // If it's not myself.
        if([event.activeSpeakers[index] integerValue] != -1)
        {
            // Get the previous activity value.
            int activityValue = [[_speakersActivityDictionary objectForKey:event.activeSpeakers[index]] integerValue];
            
            // Accumulate the activity to set the video of the user with more activity (restarted it each 2 seconds).
            activityValue++;
            
            // Save the values.
            [_speakersActivityDictionary setObject:[NSNumber numberWithInt:activityValue] forKey:event.activeSpeakers[index]];
            [_speechUserIdDictionary setObject:event.activeSpeakers[index] forKey:[NSString stringWithFormat:@"%d", activityValue]];
        }
    }
    
    _checkTimer++;
    
    // If there is some activity.
    if(_checkTimer >= 15 && [_speakersActivityDictionary count] > 0)
    {
        [self performSelectorOnMainThread:@selector(checkActivity) withObject:nil waitUntilDone:NO];
    }
}


/**
 * Receives the notification when a media event occurs.
 */
- (void) onMediaStreamEvent:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onMediaStreamEvent defined in the ALServiceListener.
    ALUserStateChangedEvent* event = [userInfo objectForKey:@"event"];
    
    NSLog(@"Got media stream event %lld screenPublished %d videoPublished %d", event.userId, event.screenPublished, event.videoPublished);
    
    if([event.mediaType isEqualToString:@"video"])
    {
        // Update the user video sink id.
        [_videoSinkIdDictionary setObject:event.videoSinkId forKey:[NSString stringWithFormat:@"%lld", event.userId]];
        
        if(event.videoPublished)
        {
            // If it's the current user feeding video.
            if(_currentVideoUserId == event.userId)
            {
                // Update the current sink Id
                _currentVideoSinkId = [_videoSinkIdDictionary objectForKey:[NSString stringWithFormat:@"%lld", _currentVideoUserId]];
                
                // Change video feed calling the method in the main thread.
                [self updateAllowedSenders];
                [self startVideoWithTheCurrentSpeaker];
            }
        }
        else
        {
            // If it's the current user feeding video.
            if(_currentVideoUserId == event.userId)
            {
                _currentVideoSinkId = @"";
                
                // Change video feed calling the method in the main thread.
                [self updateAllowedSenders];
                [self startVideoWithTheCurrentSpeaker];
            }
        }
    }
}

/**
 * Receives the notification when a frame size event occurs.
 */
- (void) onConnectionLost:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onVideoFrameSizeChanged defined in the ALServiceListener.
    ALConnectionLostEvent* event = [userInfo objectForKey:@"event"];
    
    NSLog(@"Got connection lost. Error msg: %@, willReconnect: %hhd", event.errMessage, event.willReconnect);
    
    [_remoteVV stop:nil];
}

/**
 * Method to update the allowed user sending video (in this case just the one feeding the remoteVideoView).
 */
- (void)updateAllowedSenders
{
    ResultBlock onAllowedSenders = ^(ALError* err, id nothing){
        if (err)
        {
            NSLog(@"Got an error with updateAllowedSenders onAllowedSenders due to: %@ (ERR_CODE:%d)",
                  err.err_message, err.err_code);
            return;
        }
    };
    
    // We need to send the Array of userIds of those users sending video (in this case just the one feeding the remoteVideoView).
    NSArray *userIds = @[[NSNumber numberWithLongLong:_currentVideoUserId]];
    [_alService setAllowedSenders:Consts.SCOPE_ID mediaType:@"video" userIds:userIds responder:[ALResponder responderWithBlock:onAllowedSenders]];
}

/**
 * Method to update the remoteVideoView with user speaking.
 */
- (void)startVideoWithTheCurrentSpeaker
{
    ResultBlock onStopped = ^(ALError* err, id nothing){
        if (err)
        {
            NSLog(@"Got an error with startVideoWithTheCurrentSpeaker onStopped due to: %@ (ERR_CODE:%d)",
                  err.err_message, err.err_code);
            return;
        }
        // We change the sinkId to the one of the user speaking.
        [_remoteVV setSinkId:_currentVideoSinkId];
        
        // We start the video with the new sink previously setted.
        [_remoteVV start:[ALResponder responderWithSelector:@selector(onRemoteRenderStarted:) object:self]];
    };
    // We stop the current video playing and called the responder onStopped when finishing stopping.
    [_remoteVV stop:[ALResponder responderWithBlock:onStopped]];
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
    descr.autopublishAudio = YES;
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
        
        _videoSinkIdDictionary = [[NSMutableDictionary alloc] init];
        _speakersActivityDictionary = [[NSMutableDictionary alloc] init];
        _speechUserIdDictionary = [[NSMutableDictionary alloc] init];
        _currentVideoSinkId = nil;
        _remoteVV.hidden = NO;
      
        ResultBlock onMonitorSpeech = ^(ALError* err, id nothing){
          if(err)
          {
            NSLog(@"Failed to onMonitorSpeech due to: %@ (ERR_CODE:%d)",
                err.err_message, err.err_code);
            return;
          }
        };
      
        [_alService monitorSpeechActivity:Consts.SCOPE_ID enable:true responder:[ALResponder responderWithBlock:onMonitorSpeech]];
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
        [_remoteVV stop:nil];
        _remoteVV.hidden = YES;
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
    [_alService getVideoCaptureDeviceNames:[[ALResponder alloc]
                                            initWithSelector:@selector(onCams:devs:)
                                            withObject:self]];
    [_alService addServiceListener:_listener responder:nil];
}

/**
 * Responder method called when getting the devices.
 */
- (void) onCams:(ALError*)err devs:(NSArray*)devs
{
    if (err)
    {
        NSLog(@"Got an error with getVideoCaptureDeviceNames due to: %@ (ERR_CODE:%d)",
              err.err_message, err.err_code);
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
 * Responder method called when setting a cam.
 */
- (void) onCamSet:(ALError*) err
{
    NSLog(@"Video device set");
    _settingCam = YES;
    [_alService startLocalVideo:[[ALResponder alloc] initWithSelector:@selector(onLocalVideoStarted:withSinkId:)
                                                           withObject:self]];
}

/**
 * Responder method called when the local video starts.
 */
- (void) onLocalVideoStarted:(ALError*)err withSinkId:(NSString*) sinkId
{
    if(err)
    {
        NSLog(@"Failed to start the local video due to: %@ (ERR_CODE:%d)",
              err.err_message, err.err_code);
        return;
    }
    NSLog(@"Got local video started. Will render using sink: %@",sinkId);
    [self.localPreviewVV setupWithService:_alService withSink:sinkId withMirror:YES];
    [self.localPreviewVV start:[ALResponder responderWithSelector:@selector(onRenderStarted:) object:self]];
    _localVideoSinkId = [sinkId copy];
    _settingCam = NO;
}

/**
 * Responder method called when the render starts.
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
        _localPreviewStarted = YES;
        _stateLbl.text = @"Platform Ready";
        _connectBtn.hidden = NO;
    }
}

/**
 * Responder method called when the remote render starts.
 */
- (void) onRemoteRenderStarted:(ALError*) err
{
    if(err)
    {
        NSLog(@"Failed to start the remote rendering due to: %@ (ERR_CODE:%d)",
              err.err_message, err.err_code);
        return;
    }
    else
    {
        NSLog(@"Remote Rendering started");
    }
}

/**
 * Handles the possible error coming from the sdk.
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
    {
        return;
    }
    NSLog(@"Application will resume");
    [_alService startLocalVideo:[[ALResponder alloc]
                                 initWithSelector:@selector(onLocalVideoStarted:withSinkId:)
                                 withObject:self]];
    _paused = NO;
}

/**
 * Method to select the current speaking user (each 2 seconds).
 */
- (void)checkActivity
{
    // Restart the timer.
    _checkTimer = 0;
    
    // Getting the max activity during those 2 seconds.
    int max = [[[_speakersActivityDictionary allValues] valueForKeyPath:@"@max.intValue"] intValue];
            
    // Getting the user with that max activity.
    long long userId = [[_speechUserIdDictionary objectForKey:[NSString stringWithFormat:@"%d", max]] longLongValue];
            
    // Restarting the dictionary saving those activities values.
    _speakersActivityDictionary = [[NSMutableDictionary alloc] init];
            
    // If it's a different user as the one feeding video right now.
    if(_currentVideoUserId != userId && max > 0)
    {
        // Get his userId.
        _currentVideoUserId = userId;
                
        // Get his sinkerId.
        _currentVideoSinkId = [_videoSinkIdDictionary objectForKey:[NSString stringWithFormat:@"%lld", userId]];
                
        // Change video feed.
        [self updateAllowedSenders];
        [self startVideoWithTheCurrentSpeaker];
    }
}

/**
 * Method to get the current dimensions from the coming width and height onVideoFrameSizeChanged.
 */
- (void)fitDimensions:(int)srcW and:(int)srcH to:(int)targetW and:(int)targetH
{
    float srcAR = srcW / srcH;
    float targetAR = targetW / targetH;
    float width = 0.0;
    
    if (srcW < targetW && srcH < targetH) {
        _videoWidth = srcW;
        _videoHeight = srcH;
        _left = (targetW - srcW) / 2;
    }
    if (srcAR < targetAR) {
        // match height
        _videoWidth = srcW * targetH / srcH;
        _videoHeight = targetH;
        _left = (targetW - width) / 4;
    } else {
        // match width
        _videoWidth = targetW;
        _videoHeight = targetW * srcH / srcW;
        _left = 0;
    }
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
    // TODO update this to use some real value.
    return @486;
}

+ (NSString*) API_KEY
{
    // TODO update this to use some real value.
    return @"ADL_M0QLrBEfSMR4w3cb2kwZtKgPumKGkbozk2k4SaHgqaOabexm8OmZ5uM";
}

+ (NSString*) SCOPE_ID
{
    return @"MOmJ";
}

@end


@implementation MyServiceListener

/**
 * Listener to capture an user event. (user joining media scope, user leaving media scope,
 * user publishing or stop publishing any of possible media streams.)
 */
- (void) onUserEvent:(ALUserStateChangedEvent *)event
{
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:event forKey:@"event"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"onUserEvent" object:self userInfo:userInfo];
}

/**
 * Method will be called to report the speech activivity within a particular session.
 */
- (void) onSpeechActivity:(ALSpeechActivityEvent *)event
{
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setValue:event forKey:@"event"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"onSpeechActivity" object:self userInfo:userInfo];
}

/**
 * Notifies about media streaming status change for given remote user.
 */
- (void) onMediaStreamEvent:(ALUserStateChangedEvent *)event
{
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setValue:event forKey:@"event"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"onMediaStreamEvent" object:self userInfo:userInfo];
}

/**
 * Event describing a change of a resolution in a video feed produced by given video sink.
 */
- (void) onVideoFrameSizeChanged:(ALVideoFrameSizeChangedEvent*) event
{
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setValue:event forKey:@"event"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"onVideoFrameSizeChanged" object:self userInfo:userInfo];
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
