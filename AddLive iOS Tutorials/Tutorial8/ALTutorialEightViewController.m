//
//  ALTutorialEightViewController.m
//  Tutorial8
//
//  Created by Juan Docal on 08.02.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import "ALTutorialEightViewController.h"
#import <AVFoundation/AVFoundation.h>

#define kEventInfo @"eventInfo"
#define kCheckActivity 15

// iPad dimensions
#define kiPadRemoteVVWidth 480
#define kiPadRemoteVVHeight 640
#define kiPadRemoteVVLeft 205
#define kiPadRemoteVVTop 86

// iPhone dimensions
#define kiPhoneRemoteVVWidth 239
#define kiPhoneRemoteVVHeight 320
#define kiPhoneRemoteVVLeft 73
#define kiPhoneRemoteVVTop 107

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

- (void) onUserEvent:(ALUserStateChangedEvent *)event;

- (void) onSpeechActivity:(ALSpeechActivityEvent *)event;

- (void) onConnectionLost:(ALConnectionLostEvent *)event;

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
    BOOL                      _micFunctional;
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
        _remoteVideoWidth = kiPadRemoteVVWidth;
        _remoteVideoHeight = kiPadRemoteVVHeight;
        _remoteVideoLeft = kiPadRemoteVVLeft;
        _remoteVideoTop = kiPadRemoteVVTop;
    }
    else
    {
        _remoteVideoWidth = kiPhoneRemoteVVWidth;
        _remoteVideoHeight = kiPhoneRemoteVVHeight;
        _remoteVideoLeft = kiPhoneRemoteVVLeft;
        _remoteVideoTop = kiPhoneRemoteVVTop;
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
    
    NSDictionary* mapping = @{@"onUserEvent":[NSValue valueWithPointer:@selector(onUserEvent:)],
                              @"onSpeechActivity":[NSValue valueWithPointer:@selector(onSpeechActivity:)],
                              @"onMediaStreamEvent":[NSValue valueWithPointer:@selector(onMediaStreamEvent:)],
                              @"onConnectionLost":[NSValue valueWithPointer:@selector(onConnectionLost:)]};
    
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
    [_alService setAllowedSenders:Consts.SCOPE_ID mediaType:ALMediaType.kVideo userIds:userIds responder:[ALResponder responderWithBlock:onAllowedSenders]];
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
    
    // Setting the audio according to the mic access.
    if(_micFunctional) {
        NSLog(@"Mic. is enabled.");
        descr.autopublishAudio = YES;
    } else {
        NSLog(@"Mic. is disabled.");
        descr.autopublishAudio = NO;
    }
    
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
}

/**
 * Responder method called when the local video starts.
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
    _localVideoSinkId = [sinkId copy];
    _settingCam = NO;
}

/**
 * Responder method called when the render starts.
 */
- (void) onRenderStarted:(ALError*) err
{
    if([self handleErrorMaybe:err where:@"onRenderStarted:"])
    {
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
    if([self handleErrorMaybe:err where:@"onRemoteRenderStarted:"])
    {
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
 * Receives the notification when an user event occurs
 */
- (void) onUserEvent:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onUserEvent defined in the ALServiceListener
    ALUserStateChangedEvent* event = [userInfo objectForKey:kEventInfo];
    
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
- (void) onSpeechActivity:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onSpeechActivity defined in the ALServiceListener.
    ALSpeechActivityEvent* event = [userInfo objectForKey:kEventInfo];
    
    // Getting the values for each user.
    for(id user in event.activeSpeakers)
    {
        if([user longLongValue] != -1)
        {
            // Get the previous activity value.
            int activityValue = [[_speakersActivityDictionary objectForKey:user] integerValue];
            
            // Accumulate the activity to set the video of the user with more activity (restarted it each 2 seconds).
            activityValue++;
            
            // Save the values.
            [_speakersActivityDictionary setObject:[NSNumber numberWithInt:activityValue] forKey:user];
            [_speechUserIdDictionary setObject:user forKey:[NSString stringWithFormat:@"%d", activityValue]];
        }
    }
    
    _checkTimer++;
    
    // If there is some activity.
    if(_checkTimer >= kCheckActivity && [_speakersActivityDictionary count] > 0)
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
    ALUserStateChangedEvent* event = [userInfo objectForKey:kEventInfo];
    
    NSLog(@"Got media stream event %lld screenPublished %d videoPublished %d", event.userId, event.screenPublished, event.videoPublished);
    
    if([event.mediaType isEqualToString:ALMediaType.kVideo])
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
 * Receives the notification when a connection lost occurs.
 */
- (void) onConnectionLost:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onConnectionLost defined in the ALServiceListener.
    ALConnectionLostEvent* event = [userInfo objectForKey:kEventInfo];
    
    NSLog(@"Got connection lost. Error msg: %@, willReconnect: %hhd", event.errMessage, event.willReconnect);
    
    [_remoteVV stop:nil];
}

@end

@implementation Consts

+ (NSNumber*) APP_ID
{
    // TODO update this to use some real value.
    return @1;
}

+ (NSString*) API_KEY
{
    // TODO update this to use some real value.
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
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:event forKey:kEventInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"onUserEvent" object:self userInfo:userInfo];
}

/**
 * Method will be called to report the speech activivity within a particular session.
 */
- (void) onSpeechActivity:(ALSpeechActivityEvent *)event
{
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setValue:event forKey:kEventInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"onSpeechActivity" object:self userInfo:userInfo];
}

/**
 * Notifies about media streaming status change for given remote user.
 */
- (void) onMediaStreamEvent:(ALUserStateChangedEvent *)event
{
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setValue:event forKey:kEventInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"onMediaStreamEvent" object:self userInfo:userInfo];
}

/**
 * Event describing a lost connection.
 */
- (void) onConnectionLost:(ALConnectionLostEvent *)event
{
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setValue:event forKey:kEventInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"onConnectionLost" object:self userInfo:userInfo];
}

@end
