//
//  ALTutorialSevenViewController.m
//  Tutorial7
//
//  Created by Juan Docal on 06.02.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import "ALTutorialSevenViewController.h"
#import <AVFoundation/AVFoundation.h>

#define kEventInfo @"eventInfo"

// iPad dimensions
#define kiPadRemoteVVWidth 728
#define kiPadRemoteVVHeight 584
#define kiPadRemoteVVLeft 20

// iPhone dimensions
#define kiPhoneRemoteVVWidth 300
#define kiPhoneRemoteVVHeight 225
#define kiPhoneRemoteVVLeft 10

/**
 * Interface defining application constants. In our case it is just the
 * Application id and API key.
 */

@interface Consts : NSObject

+ (NSNumber*) APP_ID;

+ (NSString*) API_KEY;

+ (NSString*) SCOPE_ID;

@end

@interface RemotePeer : NSObject

- (id)init;

- (void)applyDelta:(ALUserStateChangedEvent*)event;

- (void)toggleFromCurrentSink:(NSString*)sink;

@property(nonatomic)BOOL                isPublishingVideo;
@property(nonatomic, strong)NSString*   videoSinkId;
@property(nonatomic)BOOL                isPublishingScreen;
@property(nonatomic, strong)NSString*   screenSinkId;
@property(nonatomic, strong)NSString*   currentSinkId;

@end

@interface MyServiceListener : NSObject <ALServiceListener>

- (void) onVideoFrameSizeChanged:(ALVideoFrameSizeChangedEvent*) event;

- (void) onUserEvent:(ALUserStateChangedEvent *)event;

- (void) onConnectionLost:(ALConnectionLostEvent *)event;

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
    RemotePeer*               _remotePeer;
    BOOL                      _connecting;
    BOOL                      _micFunctional;
}
@end

@implementation ALTutorialSevenViewController

// Variables holding the Default max. ALVideoView frame dimensions
int _remoteVideoWidth, _remoteVideoHeight, _remoteVideoLeft;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _paused = NO;
    _settingCam = NO;
    _listener = [[MyServiceListener alloc] init];
    _remotePeer = [[RemotePeer alloc] init];
    [self initAddLive];
    _connecting = NO;
    
    // Defining values to set the VideoView size properly
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        _remoteVideoWidth = kiPadRemoteVVWidth;
        _remoteVideoHeight = kiPadRemoteVVHeight;
        _remoteVideoLeft = kiPadRemoteVVLeft;
    }
    else
    {
        _remoteVideoWidth = kiPhoneRemoteVVWidth;
        _remoteVideoHeight = kiPhoneRemoteVVHeight;
        _remoteVideoLeft = kiPhoneRemoteVVLeft;
    }
    
    NSDictionary* mapping = @{@"onUserEvent":[NSValue valueWithPointer:@selector(onUserEvent:)],
                              @"onMediaStreamEvent":[NSValue valueWithPointer:@selector(onMediaStreamEvent:)],
                              @"onVideoFrameSizeChanged":[NSValue valueWithPointer:@selector(onVideoFrameSizeChanged:)],
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
        [_remoteVV stop:nil];
    };
    [_alService disconnect:Consts.SCOPE_ID responder:[ALResponder responderWithBlock:onDisconn]];
}

/**
 * Button to toggle feed.
 */
- (IBAction)toggleFeed:(id)sender
{
    [_remotePeer toggleFromCurrentSink:_remotePeer.currentSinkId];
    
    ResultBlock onStopped = ^(ALError* err, id nothing){
        
        [_remoteVV setSinkId:_remotePeer.currentSinkId];
        [_remoteVV start:nil];
    };
    [_remoteVV stop:[ALResponder responderWithBlock:onStopped]];
    
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
    if([self handleErrorMaybe:err where:@"onPlatformReady:initResult:"])
    {
        return;
    }
    
    _micFunctional = initResult.micFunctional;
    
    _settingCam = YES;
    [_alService startLocalVideo:[[ALResponder alloc] initWithSelector:@selector(onLocalVideoStarted:withSinkId:)
                                                           withObject:self]];
    
    [_alService addServiceListener:_listener responder:nil];
    [_remoteVV setupWithService:_alService withSink:@""];
}

/**
 * Responder method called when the local video starts
 */
- (void) onLocalVideoStarted:(ALError*)err withSinkId:(NSString*) sinkId
{
    if([self handleErrorMaybe:err where:@"onLocalVideoStarted:withSinkId:"])
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
- (CGRect)fitDimensions:(int)srcW and:(int)srcH to:(int)targetW and:(int)targetH
{
    float _videoWidth = 0;
    float _videoHeight = 0;
    float _left = 0;
    
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
    return CGRectMake(_remoteVideoLeft + _left, _remoteVV.frame.origin.y, _videoWidth, _videoHeight);
}


/**
 * Receives the notification when a frame size event occurs
 */
- (void) onConnectionLost:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onVideoFrameSizeChanged defined in the ALServiceListener
    ALConnectionLostEvent* event = [userInfo objectForKey:kEventInfo];
    
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
    ALUserStateChangedEvent* event = [userInfo objectForKey:kEventInfo];
    
    // New user connected
    if(event.isConnected)
    {
        // Update remote peer info.
        [_remotePeer applyDelta:event];
        
        ResultBlock onStopped = ^(ALError* err, id nothing){
            
            [_remoteVV setSinkId:_remotePeer.currentSinkId];
            [_remoteVV start:nil];
        };
        [_remoteVV stop:[ALResponder responderWithBlock:onStopped]];
    }
    else
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
 * Receives the notification when a media event occurs
 */
- (void) onMediaStreamEvent:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onMediaStreamEvent defined in the ALServiceListener
    ALUserStateChangedEvent* event = [userInfo objectForKey:kEventInfo];
    
    // Update remote peer info.
    [_remotePeer applyDelta:event];
    
    ResultBlock onStopped = ^(ALError* err, id nothing){
        
        [_remoteVV setSinkId:_remotePeer.currentSinkId];
        [_remoteVV start:nil];
    };
    [_remoteVV stop:[ALResponder responderWithBlock:onStopped]];
    
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
    ALVideoFrameSizeChangedEvent* event = [userInfo objectForKey:kEventInfo];
    
    NSLog(@"Got video frame size changed. Sink id: %@, dims: %dx%d", event.sinkId,event.width,event.height);
    
    // If it's not local video feed.
    if(![event.sinkId isEqualToString:@"AddLiveRenderer1"]){
        
        // Get and set the correct dimensions
        _remoteVV.frame = [self fitDimensions:event.width and:event.height to:_remoteVideoWidth and:_remoteVideoHeight];
    }
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

@implementation RemotePeer

- (id)init
{
    self = [super init];
    if(!self) {
        return nil;
    }
    return self;
}

- (void)applyDelta:(ALUserStateChangedEvent*)event
{
    self.isPublishingVideo = event.videoPublished;
    self.isPublishingScreen = event.screenPublished;
    
    if(event.screenPublished){
        if(![event.screenSinkId isEqualToString:@""]){
            self.screenSinkId = event.screenSinkId;
        }
    }
    
    if(event.videoPublished){
        if(![event.videoSinkId isEqualToString:@""]){
            self.videoSinkId = event.videoSinkId;
        }
    }
    
    if(self.isPublishingVideo && self.isPublishingScreen){
        self.currentSinkId = self.screenSinkId;
    } else if(self.isPublishingVideo && !self.isPublishingScreen) {
        self.currentSinkId = self.videoSinkId;
    } else if (!self.isPublishingVideo && self.isPublishingScreen){
        self.currentSinkId = self.screenSinkId;
    } else {
        self.currentSinkId = @"";
    }
}

- (void)toggleFromCurrentSink:(NSString*)sink
{
    if([self.videoSinkId isEqualToString:sink]){
        self.currentSinkId = self.screenSinkId;
    } else {
        self.currentSinkId = self.videoSinkId;
    }
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
    [userInfo setValue:event forKey:kEventInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"onUserEvent" object:self userInfo:userInfo];
}

/**
 * Notifies about media streaming status change for given remote user.
 */
- (void) onMediaStreamEvent:(ALUserStateChangedEvent*) event
{
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setValue:event forKey:kEventInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"onMediaStreamEvent" object:self userInfo:userInfo];
}

/**
 * Event describing a change of a resolution in a video feed produced by given video sink.
 */
- (void) onVideoFrameSizeChanged:(ALVideoFrameSizeChangedEvent*) event
{
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setValue:event forKey:kEventInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"onVideoFrameSizeChanged" object:self userInfo:userInfo];
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
