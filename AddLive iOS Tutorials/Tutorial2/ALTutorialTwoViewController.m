//
//  ALTutorialTwoViewController.m
//  Tutorial2
//
//  Created by Tadeusz Kozak on 8/26/13.
//  Copyright (c) 2013 AddLive. All rights reserved.
//

#import "ALTutorialTwoViewController.h"

/**
 * Interface defining application constants. In our case it is just the
 * Application id and API key.
 */
@interface Consts : NSObject

+ (NSNumber*) APP_ID;

+ (NSString*) API_KEY;

@end

@interface LoggingALServiceListener:NSObject<ALServiceListener>

- (void) onVideoFrameSizeChanged:(ALVideoFrameSizeChangedEvent*) event;

@end

@interface ALTutorialTwoViewController ()
{
    ALService*                _alService;
    NSArray*                  _cams;
    NSNumber*                 _selectedCam;
    NSString*                 _localVideoSinkId;
    BOOL                      _paused;
    BOOL                      _settingCam;
    BOOL                      _localPreviewStarted;
    LoggingALServiceListener* _listener;
}
@end

@implementation ALTutorialTwoViewController

- (void)viewDidLoad
{
    _paused = NO;
    _settingCam = NO;
    [super viewDidLoad];
    _listener = [[LoggingALServiceListener alloc] init];
    [self initAddLive];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/**
 * Button action to toggle the cam.
 */
- (IBAction)onToggleCam:(id)sender
{
    NSLog(@"Got cam toggle");
    if(_settingCam)
    {
        return;
    }
    if (_cams.count > 0)
    {
        unsigned int nextIdx = (_selectedCam.unsignedIntValue + 1) % _cams.count;
        ALDevice* dev =[_cams objectAtIndex:nextIdx];
        _selectedCam = [NSNumber numberWithUnsignedInt:nextIdx];
        _settingCam = YES;
        [_alService setVideoCaptureDevice:dev.id
                                responder:[[ALResponder alloc] initWithSelector:@selector(onCameraToggled)
                                                                     withObject:self]];
    }
}

/**
 * Button action to toggle the video.
 */
- (IBAction)onToggleVideo:(id) sender
{
    if(_localPreviewStarted)
    {
        NSLog(@"Stopping local video");
        [_localPreviewVV stop:nil];
        [_alService stopLocalVideo:nil];
        _localPreviewStarted = NO;
    }
    else
    {
        NSLog(@"Starting local video");
        ResultBlock onVideoStarted = ^(ALError *err, id sinkId) {
            [_localPreviewVV setSinkId:sinkId];
            [_localPreviewVV start:nil];
            _localPreviewStarted = YES;
        };
        [_alService startLocalVideo:[ALResponder responderWithBlock:onVideoStarted]];
    }
}

- (void) onCameraToggled
{
    _settingCam = NO;
}

/**
 * Initializes the AddLive SDK.
 * For a more detailed explanation about the initialization please check Tutorial 1.
 */
- (void) initAddLive
{
    _alService = [ALService alloc];
    ALResponder* responder =[[ALResponder alloc] initWithSelector:@selector(onPlatformReady:)
                                                       withObject:self];
    
    ALInitOptions* initOptions = [[ALInitOptions alloc] init];
    initOptions.applicationId = Consts.APP_ID;
    initOptions.apiKey = Consts.API_KEY;
    initOptions.logInteractions = YES;
    [_alService initPlatform:initOptions
                       responder:responder];
}

/**
 * Called by platform when the initialization is complete.
 */
- (void) onPlatformReady:(ALError*) err
{
    NSLog(@"Got platform ready");
    if([self handleErrorMaybe:err where:@"platformInit"])
    {
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
    if ([self handleErrorMaybe:err where:@"onCams:devs:"])
    {
        return;
    }
    NSLog(@"Got camera devices");
    
    if (devs.count > 0)
    {
        _cams = [devs copy];
        _selectedCam  = [NSNumber numberWithInt:0];
        ALDevice* dev =[_cams objectAtIndex:_selectedCam.unsignedIntValue];
        [_alService setVideoCaptureDevice:dev.id
                                responder:[[ALResponder alloc] initWithSelector:@selector(onCamSet:)
                                                                     withObject:self]];
    }
}

/**
 * Responder method called when setting a cam
 */
- (void) onCamSet:(ALError*) err
{
    if ([self handleErrorMaybe:err where:@"onCamSet:"])
    {
        return;
    }
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
    if ([self handleErrorMaybe:err where:@"onLocalVideoStarted:withSinkId:"])
    {
        return;
    }
    NSLog(@"Got local video started. Will render using sink: %@", sinkId);
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
    if ([self handleErrorMaybe:err where:@"onRenderStarted:"])
    {
        return;
    }
    else
    {
        NSLog(@"Rendering started");
        _localPreviewStarted = YES;
    }
}

/**
 * Handles the possible error coming from the sdk
 */
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

@end


@implementation LoggingALServiceListener

/**
 * Listener for when the video frame change.
 */
- (void) onVideoFrameSizeChanged:(ALVideoFrameSizeChangedEvent*) event
{
    NSLog(@"Got video frame size changed. Sink id: %@, dims: %dx%d", event.sinkId,event.width,event.height);
}

@end


