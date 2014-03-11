//
//  ALTutorialSevenViewController.m
//  Tutorial7
//
//  Created by Juan Docal on 06.02.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import "ALTutorialSevenViewController.h"

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
    UIView*                   _container;
	NSMutableDictionary*      _alUserIdToVideoView;
}
@end

@implementation ALTutorialSevenViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _paused = NO;
    _settingCam = NO;
    // TODO [tk_review] 2nd call to viewDidLoad
    [super viewDidLoad];
    _listener = [[MyServiceListener alloc] initWithRemoteVideoView:_remoteVV];
    [self initAddLive];
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
{
    // Remote video object
    ALVideoView*    _videoView;
    
    // New event flag
    BOOL            _newScreen;
    
    // Remote video width before setting properly the dimensions
    int             _remoteVideoWidth;
    
    // Remote video height before setting properly the dimensions
    int             _remoteVideoHeight;
    
    // Remote video left before setting properly the dimensions
    int             _remoteVideoLeft;
    
    // Remote video width after setting properly the dimensions
    float           _videoWidth;
    
    // Remote video height after setting properly the dimensions
    float           _videoHeight;
    
    // Remote video left after setting properly the dimensions
    float           _left;
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

- (void) onUserEvent:(ALUserStateChangedEvent *)event
{
    NSLog(@"Got user event: %@", event);
    
    // TODO [tk_review] This is actually wrong. If the isConnected is false, the value for the screenPublished is "undefined".
    // The onUserEvent is dispatched only in context of remote peer joining/leaving the session, so if you have this event
    // with isConnected false, it does not make sense to check if the screenPublished is true, as the remote user is already gone...
    // I think that in general, it would be best to have here a button that allows user to toggle between the screen and video.
    // If the remote peer publishes both screen and video - the button is active and toggles (stop render, setSink, start render).
    // If user publishes only single feed - there is no button and the feed published should be rendered. I'll stop the review to allow \
    // you to modify this first as the onMediaStreamEvent also needs to be updated.
    
    
    // If the coming event is screen sharing or video
    if(event.isConnected || event.screenPublished)
    {
        NSString *sinkId;
        
        // Get the correct sinkId for each case
        if(event.screenPublished){
            sinkId = event.screenSinkId;
        }
        else{
            sinkId = event.videoSinkId;
        }
        
        // Stop the previous one and start the new one
        ResultBlock onStopped = ^(ALError* err, id nothing){
            [_videoView setSinkId:sinkId];
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
 * Notifies about media streaming status change for given remote user.
 */
- (void) onMediaStreamEvent:(ALUserStateChangedEvent*) event
{
    NSLog(@"Got media stream event %lld screenPublished %d videoPublished %d", event.userId, event.screenPublished, event.videoPublished);
    
    // If the coming event is either video or screensharing
    if(event.screenPublished || event.videoPublished){
        
        // Set to yes the new event flag
        _newScreen = YES;
    }
    
    /**
     * Defining values to set the scrollview content size properly
     */
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
}

/**
 * Event describing a change of a resolution in a video feed produced by given video sink.
 */
- (void) onVideoFrameSizeChanged:(ALVideoFrameSizeChangedEvent*) event
{
    NSLog(@"Got video frame size changed. Sink id: %@, dims: %dx%d", event.sinkId,event.width,event.height);
    
    // TODO [tk_review] This one is wrong. The size of the screen sharing feed can change in any time -
    // e.g. someone is sharing a window and simply resizes it. The app needs to handle every
    // videoFrameSizeChanged if it is related to the screen sharing sink. You should store the id of screen sharing sink
    // and check if this event is related to that sink, and if so - fix the AR
    
    // If it is a new event
    if(_newScreen)
    {
        // Get and set the correct dimensions
        [self fitDimensions:event.width and:event.height to:_remoteVideoWidth and:_remoteVideoHeight];
        _videoView.frame = CGRectMake(_remoteVideoLeft + _left, _videoView.frame.origin.y, _videoWidth, _videoHeight);
        
        // Stop the previous one and start the new one
        ResultBlock onStopped = ^(ALError* err, id nothing){
            [_videoView setSinkId:event.sinkId];
            [_videoView start:nil];
        };
        [_videoView stop:[ALResponder responderWithBlock:onStopped]];
        
        // Set to no the new event flag
        _newScreen = NO;
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

@end
