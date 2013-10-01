//
//  ALViewController.m
//  Tutorial2
//
//  Created by Tadeusz Kozak on 8/26/13.
//  Copyright (c) 2013 AddLive. All rights reserved.
//

#import "ALViewController.h"

/**
 * Class that passes the video sink configuration changes to all ALVideoViews rendering particular sink.
 */
@interface VideoFrameResizeCtrl:NSObject<ALServiceListener>

/**
 * VideoFrameSizeChanged event handler
 */
- (void) videoFrameSizeChanged:(ALVideoFrameSizeChangedEvent*) event;

/**
 * Defines mapping between sink and view rendering it.
 */
- (void) setMappingWithSinkId:(NSString*) sinkId andView:(ALVideoView*) view;
@end

@interface ALViewController ()

{
    ALService*            _alService;
    NSArray*              _cams;
    NSNumber*             _selectedCam;
    NSString*             _localVideoSinkId;
    VideoFrameResizeCtrl* _resizeCtr;
    BOOL                  _paused;
    BOOL                  _settingCam;
}
@end

@implementation ALViewController

- (void)viewDidLoad
{
    _paused = NO;
    _settingCam = NO;
    [super viewDidLoad];
    [self initAddLive];
}


- (IBAction)onToggleCam:(id)sender
{
    NSLog(@"Got cam toggle");
    if(_settingCam)
        return;
    unsigned int nextIdx = (_selectedCam.unsignedIntValue + 1) % _cams.count;
    ALDevice* dev =[_cams objectAtIndex:nextIdx];
    _selectedCam = [NSNumber numberWithUnsignedInt:nextIdx];
    _settingCam = YES;
    [_alService setVideoCaptureDevice:dev.id
                            responder:[[ALResponder alloc] initWithSelector:@selector(onCameraToggled)
                                                                 withObject:self]];
}

- (void) onCameraToggled
{
    _settingCam = NO;
}


- (void) initAddLive
{
    _alService = [ALService alloc];
    ALResponder* responder =[[ALResponder alloc] initWithSelector:@selector(onPlatformReady:)
                                                       withObject:self];
    ALInitOptions* initOptions = [[ALInitOptions alloc] init];
    [_alService initPlatform:initOptions
                       responder:responder];
}

- (void) onPlatformReady:(ALError*) err
{
    NSLog(@"Got platform ready");
    if(err)
    {
        [self handleError:err where:@"platformInit"];
        return;
    }
    self.localPreviewVV.service = _alService;
    self.localPreviewVV.mirror = YES;
    _resizeCtr = [[VideoFrameResizeCtrl alloc] init];
    [_alService addServiceListener:_resizeCtr
                         responder:[[ALResponder alloc]
                                    initWithSelector:@selector(onListenerAdded:)
                                    withObject:self]];
}


- (void) onListenerAdded:(ALError*) err
{
    [_alService getVideoCaptureDeviceNames:[[ALResponder alloc]
                                            initWithSelector:@selector(onCams:devs:)
                                            withObject:self]];
}
     
- (void) onCams:(ALError*)err devs:(NSArray*)devs
{
    NSLog(@"Got camera devices");
    _cams = [devs copy];
    _selectedCam  = [NSNumber numberWithInt:0];
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
    _localVideoSinkId = [sinkId copy];
    _settingCam = NO;
    [_resizeCtr setMappingWithSinkId:sinkId
                             andView:_localPreviewVV];
    ALError *renderErr  = [self.localPreviewVV attachToSink:sinkId];
    if(renderErr.err_code != kNoError)
    {
        [self handleError:renderErr where:@"attachToSink"];
    }
    renderErr = [self.localPreviewVV resume];
    if(renderErr.err_code != kNoError)
    {
        [self handleError:renderErr where:@"resume render"];
    }
}

     
- (void) handleError:(ALError*)err where:(NSString*)where
{
    NSString* msg = [NSString stringWithFormat:@"Got an error with %@: %@ (%d)",
                     where, err.err_message, err.err_code];
    NSLog(@"%@", msg);
    self.errorLbl.hidden = NO;
    self.errorContentLbl.text = msg;
    self.errorContentLbl.hidden = NO;
}


- (void) pause
{
    NSLog(@"Application will pause");
    [self.localPreviewVV pause];
    [_alService stopLocalVideo:nil];
    _paused = YES;
}
- (void) resume
{
    if(!_paused)
        return;
    NSLog(@"Application will resume");
    [self.localPreviewVV resume];
    [_alService startLocalVideo:[[ALResponder alloc]
                                 initWithSelector:@selector(onLocalVideoStarted:withSinkId:)
                                 withObject:self]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

/**
 * Please note that in one of the next releases, all the methods within the ALServiceListener 
 * protocol will be marked as optional. The warning about the missing methods can be ignored.
 */
@implementation VideoFrameResizeCtrl
{
    NSMutableDictionary* _mapping;
}

- (id) init
{
    _mapping = [[NSMutableDictionary alloc] init];
    return self;
}

- (void) videoFrameSizeChanged:(ALVideoFrameSizeChangedEvent*) event
{
    NSLog(@"Got video frame size changed: %@ -> %dx%d", event.sinkId, event.width, event.height);
    ALVideoView* view = [_mapping objectForKey:event.sinkId];
    if(view)
    {
        NSLog(@"Setting new resolution");
        [view resolutionChanged:event.width height:event.height];
    }
}

- (void) setMappingWithSinkId:(NSString*) sinkId andView:(ALVideoView*) view
{
    [_mapping setObject:view forKey:sinkId];
}

@end

