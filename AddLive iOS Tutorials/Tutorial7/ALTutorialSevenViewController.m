//
//  ALTutorialSevenViewController.m
//  Tutorial7
//
//  Created by Juan Docal on 06.02.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import "ALTutorialSevenViewController.h"
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

- (void) onConnectionLost:(ALConnectionLostEvent *)event;

- (void) onSessionReconnected:(ALSessionReconnectedEvent *)event;

@end

@interface ALTutorialSevenViewController ()
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
}
@end

@implementation ALTutorialSevenViewController

// Remote Video Sink Id
NSString *_remoteVideoSinkId;

// Remote Screen Sink Id
NSString *_remoteScreenSinkId;

// Current Sink Id feeding
NSString *_currentRemoteSinkId;

// Feeding video or screen
bool _videoFeed;

// Remote video width before setting properly the dimensions
int _remoteVideoWidth;

// Remote video height before setting properly the dimensions
int _remoteVideoHeight;

// Remote video left before setting properly the dimensions
int _remoteVideoLeft;

// Remote video width after setting properly the dimensions
float _videoWidth;

// Remote video height after setting properly the dimensions
float _videoHeight;

// Remote video left after setting properly the dimensions
float _left;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _paused = NO;
    _settingCam = NO;
    _listener = [[MyServiceListener alloc] init];
    [self initAddLive];
    _connecting = NO;
    
    // Defining values to set the VideoView size properly
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        _remoteVideoWidth = 728;
        _remoteVideoHeight = 584;
        _remoteVideoLeft = 20;
    }
    else
    {
        _remoteVideoWidth = 300;
        _remoteVideoHeight = 225;
        _remoteVideoLeft = 10;
    }
    
    // Notification triggered when an user event is triggered
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUserEvent:)
                                                 name:@"onUserEvent"
                                               object:nil];
    
    // Notification triggered when a media stream event is triggered
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onMediaStreamEvent:)
                                                 name:@"onMediaStreamEvent"
                                               object:nil];
    
    // Notification triggered when a frame size event is triggered
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onVideoFrameSizeChanged:)
                                                 name:@"onVideoFrameSizeChanged"
                                               object:nil];
    
    // Notification triggered when a frame size event is triggered
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onConnectionLost:)
                                                 name:@"onConnectionLost"
                                               object:nil];
}

/**
 * Receives the notification when a frame size event occurs
 */
- (void) onConnectionLost:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onVideoFrameSizeChanged defined in the ALServiceListener
    ALConnectionLostEvent* event = [userInfo objectForKey:@"event"];
    
    NSLog(@"Got connection lost. Error msg: %@, willReconnect: %hhd", event.errMessage, event.willReconnect);
    
    [_remoteVV stop:nil];
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
        // Getting the videoId
        if(event.videoPublished)
        {
            _currentRemoteSinkId = event.videoSinkId;
            _remoteVideoSinkId = _currentRemoteSinkId;
            _videoFeed = true;
        }
        
        // Getting the screenId. Giving priority to the
        // screen feed if both are available
        if(event.screenPublished)
        {
            _currentRemoteSinkId = event.screenSinkId;
            _remoteScreenSinkId = _currentRemoteSinkId;
            _videoFeed = false;
        }
        
        // Showing the toggle button
        if(event.screenPublished && event.videoPublished)
        {
            _toggleBtn.hidden = NO;
        }
        
        // Stop the previous one and start the new one
        ResultBlock onStopped = ^(ALError* err, id nothing){
            [_remoteVV setSinkId:_currentRemoteSinkId];
            [_remoteVV start:nil];
        };
        [_remoteVV stop:[ALResponder responderWithBlock:onStopped]];
    }
    else
    {
        [_remoteVV stop:nil];
    }
}

/**
 * Receives the notification when a media event occurs
 */
- (void) onMediaStreamEvent:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onMediaStreamEvent defined in the ALServiceListener
    ALUserStateChangedEvent* event = [userInfo objectForKey:@"event"];
    
    NSLog(@"Got media stream event %lld screenPublished %d videoPublished %d", event.userId, event.screenPublished, event.videoPublished);
    
    if([event.mediaType isEqualToString:@"video"])
    {
        // Updating the Id
        _remoteVideoSinkId = event.videoSinkId;
        
        // If I was feeding video but now it's disable and I have available screen
        if(_videoFeed && !event.videoPublished && event.screenPublished)
        {
            // Starting screen feed
            [_remoteVV stop:[ALResponder responderWithSelector:@selector(onRemoteStoppedVideo) object:self]];
        }
        else if(event.videoPublished)
        {
            // Stop the previous one and start the new one
            ResultBlock onStopped = ^(ALError* err, id nothing){
                
                // Updating current Id
                _currentRemoteSinkId = _remoteVideoSinkId;
                [_remoteVV setSinkId:_currentRemoteSinkId];
                [_remoteVV start:nil];
            };
            [_remoteVV stop:[ALResponder responderWithBlock:onStopped]];
        }
    }
    else if([event.mediaType isEqualToString:@"screen"])
    {
        // Updating the Id
        _remoteScreenSinkId = event.screenSinkId;
        
        // If I was feeding screen but now it's disable and I have available video
        if(!_videoFeed && !event.screenPublished && event.videoPublished)
        {
            // Starting video feed
            [_remoteVV stop:[ALResponder responderWithSelector:@selector(onRemoteStoppedScreen) object:self]];
        }
        else if(event.screenPublished)
        {
            // Stop the previous one and start the new one
            ResultBlock onStopped = ^(ALError* err, id nothing){
                
                // Updating current Id
                _currentRemoteSinkId = _remoteScreenSinkId;
                [_remoteVV setSinkId:_currentRemoteSinkId];
                [_remoteVV start:nil];
            };
            [_remoteVV stop:[ALResponder responderWithBlock:onStopped]];
        }
    }
    
    // Stop the feeding if there's none
    if(!event.screenPublished && !event.videoPublished)
    {
        [_remoteVV stop:nil];
    }
    
    // Setting the toggle button visibility
    if(event.screenPublished && event.videoPublished)
    {
        _toggleBtn.hidden = NO;
    }
    else if(event.screenPublished || event.videoPublished)
    {
        _toggleBtn.hidden = YES;
    }
}

/**
 * Receives the notification when a frame size event occurs
 */
- (void) onVideoFrameSizeChanged:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onVideoFrameSizeChanged defined in the ALServiceListener
    ALVideoFrameSizeChangedEvent* event = [userInfo objectForKey:@"event"];
    
    NSLog(@"Got video frame size changed. Sink id: %@, dims: %dx%d", event.sinkId,event.width,event.height);
    
    // If its the current sink feeding
    if([event.sinkId isEqualToString:_currentRemoteSinkId])
    {
        // Get and set the correct dimensions
        [self fitDimensions:event.width and:event.height to:_remoteVideoWidth and:_remoteVideoHeight];
        _remoteVV.frame = CGRectMake(_remoteVideoLeft + _left, _remoteVV.frame.origin.y, _videoWidth, _videoHeight);
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
    };
    [_alService disconnect:Consts.SCOPE_ID responder:[ALResponder responderWithBlock:onDisconn]];
}

/**
 * Button to toggle feed.
 */
- (IBAction)toggleFeed:(id)sender
{
    if(!_videoFeed)
    {
        // Starting video feed
        [_remoteVV stop:[ALResponder responderWithSelector:@selector(onRemoteStoppedScreen) object:self]];
    }
    else
    {
        // Starting screen feed
        [_remoteVV stop:[ALResponder responderWithSelector:@selector(onRemoteStoppedVideo) object:self]];
    }
}

/**
 * Toggle feed from video to screen.
 */
- (void) onRemoteStoppedVideo
{
    // Updating current Id
    _currentRemoteSinkId = _remoteScreenSinkId;
    
    [_remoteVV setSinkId:_remoteScreenSinkId];
    [_remoteVV start:nil];
    _videoFeed = false;
}

/**
 * Toggle feed from screen to video.
 */
- (void) onRemoteStoppedScreen
{
    // Updating current Id
    _currentRemoteSinkId = _remoteVideoSinkId;
    
    [_remoteVV setSinkId:_remoteVideoSinkId];
    [_remoteVV start:nil];
    _videoFeed = true;
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
    [_remoteVV setupWithService:_alService withSink:@""];
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
 * Method to get the current dimensions from the coming width and height onVideoFrameSizeChanged
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
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setValue:event forKey:@"event"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"onUserEvent" object:self userInfo:userInfo];
}

/**
 * Notifies about media streaming status change for given remote user.
 */
- (void) onMediaStreamEvent:(ALUserStateChangedEvent*) event
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
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setValue:event forKey:@"event"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"onConnectionLost" object:self userInfo:userInfo];
}

/**
 * Event describing a reconnection.
 */
- (void) onSessionReconnected:(ALSessionReconnectedEvent *)event
{
    NSLog(@"On Session reconnected");
}

@end
