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

@end


@interface ALViewController ()

{
    ALService*            _alService;
    NSArray*              _cams;
    NSNumber*             _selectedCam;
    NSString*             _localVideoSinkId;
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
    initOptions.applicationId = Consts.APP_ID;
    initOptions.apiKey = Consts.API_KEY;

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
    [_alService getVideoCaptureDeviceNames:[[ALResponder alloc]
                                            initWithSelector:@selector(onCams:devs:)
                                            withObject:self]];

}

- (void) onCams:(ALError*)err devs:(NSArray*)devs
{
    if (err) {
        NSLog(@"Got an error with getVideoCaptureDeviceNames: %@", err );
        return;
    }
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
    return @"SomeApiKey";
}

@end


