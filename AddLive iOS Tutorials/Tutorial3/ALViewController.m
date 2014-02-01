//
//  ALViewController.m
//  Tutorial2
//
//  Created by Tadeusz Kozak on 8/26/13.
//  Copyright (c) 2013 AddLive. All rights reserved.
//

#import "ALViewController.h"

/**
 * Interface defining application constants. In our case it is just the
 * Application id and API key.
 */
@interface Consts : NSObject

+ (NSNumber*) APP_ID;

+ (NSString*) API_KEY;

+ (NSString*) SCOPE_ID;

@end

@interface MyServiceListener:NSObject<ALServiceListener>

- (id) initWithRemoteVideoView:(ALVideoView*) view;

- (void) onVideoFrameSizeChanged:(ALVideoFrameSizeChangedEvent*) event;

- (void) onUserEvent:(ALUserStateChangedEvent *)event;

- (void) onConnectionLost:(ALConnectionLostEvent *)event;

- (void) onSessionReconnected:(ALSessionReconnectedEvent *)event;

@end

@interface ALViewController ()

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

@implementation ALViewController

- (void)viewDidLoad
{
    
    _paused = NO;
    _settingCam = NO;
    [super viewDidLoad];
    _listener = [[MyServiceListener alloc] initWithRemoteVideoView:_remoteVV];
    [self initAddLive];
    _connecting = NO;
}

- (IBAction)connect:(id)sender {
    if(_connecting) {
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

- (IBAction)disconnect:(id)sender {
    ResultBlock onDisconn = ^(ALError* err, id nothing) {
        NSLog(@"Successfully disconnected");
        _stateLbl.text = @"Disconnected";
        _connectBtn.hidden = NO;
        _disconnectBtn.hidden = YES;
        [_remoteVV stop:nil];
    };
    [_alService disconnect:Consts.SCOPE_ID responder:[ALResponder responderWithBlock:onDisconn]];
}




- (void) initAddLive
{
    _alService = [ALService alloc];
    ALResponder* responder =[[ALResponder alloc] initWithSelector:@selector(onPlatformReady:)
                                                       withObject:self];
    ALInitOptions* initOptions = [[ALInitOptions alloc] init];
    initOptions.applicationId = Consts.APP_ID;
    initOptions.apiKey = Consts.API_KEY;
    [_alService initPlatform:initOptions
                       responder:responder];
    _stateLbl.text = @"Platform init";
}

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

- (void) onCams:(ALError*)err devs:(NSArray*)devs
{
    if (err) {
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

- (void) onCamSet:(ALError*) err
{
    NSLog(@"Video device set");
    _settingCam = YES;
    [_alService startLocalVideo:[[ALResponder alloc] initWithSelector:@selector(onLocalVideoStarted:withSinkId:)
                                                           withObject:self]];
}

- (void) onLocalVideoStarted:(ALError*)err
                  withSinkId:(NSString*) sinkId
{
    NSLog(@"Got local video started. Will render using sink: %@",sinkId);
    [self.localPreviewVV setupWithService:_alService withSink:sinkId withMirror:YES];
    [self.localPreviewVV start:[ALResponder responderWithSelector:@selector(onRenderStarted:) object:self]];
    _localVideoSinkId = [sinkId copy];
    _settingCam = NO;
}

- (void) onRenderStarted:(ALError*) err {
    if(err) {
        NSLog(@"Failed to start the rendering due to: %@ (ERR_CODE:%d)",
              err.err_message, err.err_code);
    } else {
        NSLog(@"Rendering started");
        _localPreviewStarted = YES;
        _stateLbl.text = @"Platform Ready";
        _connectBtn.hidden = NO;
    }
}
      
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


- (void) pause
{
    NSLog(@"Application will pause");
    [self.localPreviewVV stop:nil];
    [_alService stopLocalVideo:nil];
    _paused = YES;
}
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


@implementation MyServiceListener {
    ALVideoView* _videoView;
}

- (id) initWithRemoteVideoView:(ALVideoView*) view {
    self = [super init];
    if(self) {
        _videoView = view;
    }
    return self;
}

- (void) onUserEvent:(ALUserStateChangedEvent *)event {
    NSLog(@"Got user event: %@", event);
    if(event.isConnected) {
        ResultBlock onStopped = ^(ALError* err, id nothing){
            [_videoView setSinkId:event.videoSinkId];
            [_videoView start:nil];
        };
        [_videoView stop:[ALResponder responderWithBlock:onStopped]];
    } else {
        [_videoView stop:nil];
    }
}

- (void) onVideoFrameSizeChanged:(ALVideoFrameSizeChangedEvent*) event {
    NSLog(@"Got video frame size changed. Sink id: %@, dims: %dx%d", event.sinkId,event.width,event.height);
}

- (void) onConnectionLost:(ALConnectionLostEvent *)event {
    NSLog(@"Got connection lost");
}

- (void) onSessionReconnected:(ALSessionReconnectedEvent *)event {
    NSLog(@"On Session reconnected");
}

@end


