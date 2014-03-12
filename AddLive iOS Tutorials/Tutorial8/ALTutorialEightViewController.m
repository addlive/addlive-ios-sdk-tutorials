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
    // TODO [tk_review] Sinker? what is "Sinker" ? :)
    NSString*                 _currentVideoSinkerId;
    
    // TODO [tk_review] Why string as user id? o_O it all should be long long or NSNumber
    NSString*                 _currentVideoUserId;
    BOOL                      _paused;
    BOOL                      _settingCam;
    BOOL                      _localPreviewStarted;
    MyServiceListener*        _listener;
    BOOL                      _connecting;
    ALVideoView*              _remoteVideoView;
    NSMutableDictionary*      _videoSinkIdDictionary;
    NSMutableDictionary*      _speechActivityDictionary;
    NSMutableDictionary*      _speechUserIdDictionary;
    NSThread*                 _checkConnectionThread;
    int                       _remoteVideoWidth;
    int                       _remoteVideoHeight;
    int                       _remoteVideoMarginX;
    int                       _remoteVideoMarginY;
}
@end

@implementation ALTutorialEightViewController

- (void)viewDidLoad
{
    _paused = NO;
    _settingCam = NO;
    [super viewDidLoad];
    
    /**
     * Defining values to set the scrollview content size properly.
     */
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        _remoteVideoWidth = 480;
        _remoteVideoHeight = 640;
        _remoteVideoMarginX = 205;
        _remoteVideoMarginY = 86;
    }
    else
    {
        _remoteVideoWidth = 239;
        _remoteVideoHeight = 320;
        _remoteVideoMarginX = 73;
        _remoteVideoMarginY = 107;
    }
    
    _listener = [[MyServiceListener alloc] init];
    [self initAddLive];
    _connecting = NO;
    
    // Setting the frame for the remoteVideoView (iPad or iPhone).
    CGRect frame;
    frame.origin.x = _remoteVideoMarginX;
    frame.origin.y = _remoteVideoMarginY;
    frame.size.width = _remoteVideoWidth;
    frame.size.height = _remoteVideoHeight;
    
    // Initializing the remoteVideoView.
    _remoteVideoView = [[ALVideoView alloc] initWithFrame:frame];
    _remoteVideoView.backgroundColor = [UIColor lightGrayColor];
    
    [self.view addSubview:_remoteVideoView];
    
    // TODO [tk_review] Same as with the tutorial 5 - please use nice strategy design pattern

    // TODO [tk_review] Why are you not handling the user disconnected? In this case, rendering should be terminated
    
    
    // Notification triggered when an user join the session.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveNotification:)
                                                 name:@"onUserJoined"
                                               object:nil];
    
    // Notification triggering the speech activity.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveNotification:)
                                                 name:@"onSpeechActivity"
                                               object:nil];
    
    // Notification triggering the media stream event.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveNotification:)
                                                 name:@"onMediaStreamEvent"
                                               object:nil];
}

/**
 * Receives the onUserEvent notifications.
 */
- (void) receiveNotification:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // When user joined.
    if ([[notification name] isEqualToString:@"onUserJoined"])
    {
        // Details of the event sent by the event onUserEvent defined in the ALServiceListener.
        ALUserStateChangedEvent* eventDetails = [userInfo objectForKey:@"event"];
      
        // Add the new user videoSinkId to the historical so we can set it up as a video feeder when speaking.
        [_videoSinkIdDictionary setObject:eventDetails.videoSinkId forKey:[NSString stringWithFormat:@"%lld", eventDetails.userId]];
        
        // If it's the first time.
        if(!_currentVideoSinkerId)
        {
            
            // TODO [tk_review] again why stringWithFormat instead of copying?
            // Set the values.
            _currentVideoSinkerId = [NSString stringWithFormat:@"%@", eventDetails.videoSinkId];
            _currentVideoUserId = [NSString stringWithFormat:@"%lld", eventDetails.userId];
            
            
            // TODO [tk_review] that's actually wrong, the withMirror:YES is kind of reserved for the local preview
            // remote video feeds should not be mirrored.
            // The reason for the mirror is that it is more natural for a user to see self
            
            // Start the video.
            [_remoteVideoView setupWithService:_alService withSink:_currentVideoSinkerId withMirror:YES];
            [_remoteVideoView start:[ALResponder responderWithSelector:@selector(onRemoteRenderStarted:) object:self]];
        }
    }
    else if([[notification name] isEqualToString:@"onSpeechActivity"])
    {
        // Details of the event sent by the event onSpeechActivity defined in the ALServiceListener.
        ALSpeechActivityEvent* event = [userInfo objectForKey:@"event"];
        
        // Getting the values for each user.
        for(int index = 0; index < [[event.speechActivity valueForKey:@"activity"] count]; index++)
        {
            // If it's not myself.
            if([[event.speechActivity valueForKey:@"userId"][index] integerValue] != -1)
            {
                // Get the current activity value.
                int activityValue = [[event.speechActivity valueForKey:@"activity"][index] integerValue];
                
                // Get the previous activity value.
                int prevActivityValue = [[_speechActivityDictionary objectForKey:[event.speechActivity valueForKey:@"userId"][index]] integerValue];
                
                // TODO [tk_review] Actually I think it does make sense to change this a bit. Currently you will elect the loudest guy,
                // what we would like instead is the most active one - the one that talks most of the time during the 2 sec window.
                // I think that it will be a better idea, to count events where particular user was present in the activeSpeakers array.
                // The thread that toggles speakers should check if currently active speaker have counter bigger than N (constant pulled on top)
                // If yes - do not change the speaker. If not, elect a new one, the one that have biggest counter value
                
                // Accumulate the activity to set the video of the user with more activity (this is restart it each 2 seconds).
                activityValue = activityValue + prevActivityValue;
                
                // Save the values.
                [_speechActivityDictionary setObject:[NSNumber numberWithInt:activityValue] forKey:[event.speechActivity valueForKey:@"userId"][index]];
                [_speechUserIdDictionary setObject:[event.speechActivity valueForKey:@"userId"][index] forKey:[NSString stringWithFormat:@"%d", activityValue]];
            }
        }
    }
    else if([[notification name] isEqualToString:@"onMediaStreamEvent"])
    {
        // Details of the event sent by the event onMediaStreamEvent defined in the ALServiceListener.
        ALUserStateChangedEvent* event = [userInfo objectForKey:@"event"];
        
        // Update the user video sink id
        [_videoSinkIdDictionary setObject:event.videoSinkId forKey:[NSString stringWithFormat:@"%lld", event.userId]];
        
        // If the media event ocurres is video
        if([event.mediaType isEqualToString:@"video"]){
            
            // If the user disabled his video
            if(event.videoPublished == NO){

                // If it's the current user feeding video
                if([[NSString stringWithFormat:@"%lld", event.userId] isEqualToString:_currentVideoUserId]){
                
                    _currentVideoSinkerId = @"";
                    
                    // Change video feed calling the method in the main thread.
                    [self updateAllowedSenders];
                    [self startVideoWithTheCurrentSpeaker];
                }
                
            } else{
                
                // If it's the current user feeding video
                if([[NSString stringWithFormat:@"%lld", event.userId] isEqualToString:_currentVideoUserId]){
                    
                    _currentVideoUserId = [NSString stringWithFormat:@"%lld", event.userId];
                    _currentVideoSinkerId = [NSString stringWithFormat:@"%@", [_videoSinkIdDictionary objectForKey:[NSString stringWithFormat:@"%@", _currentVideoUserId]]];
                
                    // Change video feed calling the method in the main thread.
                    [self updateAllowedSenders];
                    [self startVideoWithTheCurrentSpeaker];
                }
            }
        }
    }
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
    NSNumber *speakingUserId = [NSNumber numberWithInt:[_currentVideoUserId intValue]];
    
    // TODO [tk_review] why not to use here the @[] literal?
    NSArray *userIds = [[NSArray alloc] initWithObjects:speakingUserId, nil];
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
        [_remoteVideoView setSinkId:_currentVideoSinkerId];
        
        // We start the video with the new sink previously setted.
        [_remoteVideoView start:[ALResponder responderWithSelector:@selector(onRemoteRenderStarted:) object:self]];
    };
    // We stop the current video playing and called the responder onStopped when finishing stopping.
    [_remoteVideoView stop:[ALResponder responderWithBlock:onStopped]];
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
        _speechActivityDictionary = [[NSMutableDictionary alloc] init];
        _speechUserIdDictionary = [[NSMutableDictionary alloc] init];
        _currentVideoSinkerId = nil;
        _remoteVideoView.hidden = NO;
      
        ResultBlock onMonitorSpeech = ^(ALError* err, id nothing){
          if(err)
          {
            NSLog(@"Failed to onMonitorSpeech due to: %@ (ERR_CODE:%d)",
                err.err_message, err.err_code);
            return;
          }
        };
      
        [_alService monitorSpeechActivity:Consts.SCOPE_ID enable:true responder:[ALResponder responderWithBlock:onMonitorSpeech]];
      
        // TODO [tk_review] Don't like, see more around this method.
        _checkConnectionThread = [[NSThread alloc] initWithTarget:self
                                                         selector:@selector(checkActivity)
                                                           object:nil];
        [_checkConnectionThread start];
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
        [_remoteVideoView stop:nil];
        _remoteVideoView.hidden = YES;
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
 * Responder method called when getting the devices
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
        _localPreviewStarted = YES;
        _stateLbl.text = @"Platform Ready";
        _connectBtn.hidden = NO;
    }
}

/**
 * Responder method called when the remote render starts
 */
- (void) onRemoteRenderStarted:(ALError*) err
{
    if(err)
    {
        NSLog(@"Failed to start the rendering due to: %@ (ERR_CODE:%d)",
              err.err_message, err.err_code);
        return;
    }
    else
    {
        NSLog(@"Remote Rendering started");
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
    {
        return;
    }
    NSLog(@"Application will resume");
    [_alService startLocalVideo:[[ALResponder alloc]
                                 initWithSelector:@selector(onLocalVideoStarted:withSinkId:)
                                 withObject:self]];
    _paused = NO;
    
    
    _checkConnectionThread = [[NSThread alloc] initWithTarget:self
                                                     selector:@selector(checkActivity)
                                                       object:nil];
    [_checkConnectionThread start];
}

// TODO [tk_review] I really, really don't like this thread. It's totally not needed. The execution happens only
// every 2 secs and it needs to perform certain tasks on main thread. Why to create a thread instead of repeatedly
// submit a task using if(shouldRun) [self performSelectorOnMainThread:]
// or actually check at the beginning of the method - if (!shouldRun) return; so the check is done before not
// after the execution

/**
 * Thread to select the current speaking user (each 2 seconds).
 */
#pragma mark - Reconnection Thread
- (void)checkActivity
{
    // TODO [tk_review] don't like. Using view's properties to maintain application state is IMO rape on MVC
    while (_connectBtn.hidden)
    {
        
        // TODO [tk_review] please udpate this method as per previous long comment - about how the election should work
        [NSThread sleepForTimeInterval:2.0];
        
        // If there is some activity.
        if([_speechActivityDictionary count] > 0)
        {
            // Getting the max activity during those 2 seconds.
            NSString *maxString = [[_speechActivityDictionary allValues] valueForKeyPath:@"@max.intValue"];
            
            // TODO [tk_review] why userId is string here?
            // TODO [tk_review] And btw this is a serious fuck up - string to int to string - why so many conversions?
            // Getting the user with that max activity.
            NSString *userId = [_speechUserIdDictionary objectForKey:[NSString stringWithFormat:@"%d", [maxString intValue]]];
            
            // Restarting the dictionary saving those activities values.
            _speechActivityDictionary = [[NSMutableDictionary alloc] init];
            
            // If it's a different user as the one feeding video right now.
            if(![_currentVideoUserId isEqualToString:[NSString stringWithFormat:@"%@", userId]] && [maxString intValue] > 0)
            {
                // Get his userId.
                _currentVideoUserId = [NSString stringWithFormat:@"%@", userId];
                
                // Get his sinkerId.
                _currentVideoSinkerId = [NSString stringWithFormat:@"%@", [_videoSinkIdDictionary objectForKey:[NSString stringWithFormat:@"%@", userId]]];
                
                // Change video feed calling the method in the main thread.
                dispatch_block_t methodToStartVideoInMain = ^{
                    [self updateAllowedSenders];
                    [self startVideoWithTheCurrentSpeaker];
                };
                
                if ([NSThread isMainThread])
                {
                    methodToStartVideoInMain();
                }
                else
                {
                    dispatch_sync(dispatch_get_main_queue(), methodToStartVideoInMain);
                }
            }
        }
        // If there is none activity.
        else
        {
            _currentVideoSinkerId = nil;
            _currentVideoUserId = nil;
        }
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
    return @"";
}

@end


@implementation MyServiceListener

/**
 * Listener to capture an user event. (user joining media scope, user leaving media scope,
 * user publishing or stop publishing any of possible media streams.)
 */
- (void) onUserEvent:(ALUserStateChangedEvent *)event
{
    NSLog(@"Got user event: %@", event);
    if(event.isConnected)
    {
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
        [userInfo setObject:event forKey:@"event"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"onUserJoined" object:self userInfo:userInfo];
    }
}

/**
 * Method will be called to report the speech activivity within a particular session.
 */
- (void) onSpeechActivity:(ALSpeechActivityEvent *)event
{
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:event forKey:@"event"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"onSpeechActivity" object:self userInfo:userInfo];
}

/**
 * Notifies about media streaming status change for given remote user.
 */
- (void) onMediaStreamEvent:(ALUserStateChangedEvent *)event
{
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:event forKey:@"event"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"onMediaStreamEvent" object:self userInfo:userInfo];
}

/**
 * Event describing a change of a resolution in a video feed produced by given video sink.
 */
- (void) onVideoFrameSizeChanged:(ALVideoFrameSizeChangedEvent*) event
{
    NSLog(@"Got video frame size changed.  Sink id: %@, dims: %dx%d", event.sinkId,event.width,event.height);
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
