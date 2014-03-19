//
//  ALViewController.m
//  Tutorial2.1
//
//  Created by Juan Docal on 19.03.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import "ALTutorialTwoOneViewController.h"

/**
 * Interface defining application constants. In our case it is just the
 * Application id and API key.
 */
@interface Consts : NSObject

+ (NSNumber*) APP_ID;

+ (NSString*) API_KEY;

@end

@interface ALTutorialTwoOneViewController ()
{
    ALService*                _alService;
    NSArray*                  _cams;
    NSNumber*                 _selectedCam;
    NSString*                 _localVideoSinkId;
}
@end

@implementation ALTutorialTwoOneViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self initAddLive];
}

- (IBAction)startRender:(id)sender
{
    /**
     * Responder method called when the render starts
     */
    ResultBlock onRenderStarted = ^(ALError* err, id nothing){
        if(err) {
            NSLog(@"Failed to start the rendering due to: %@ (ERR_CODE:%d)",
                  err.err_message, err.err_code);
            return;
        } else {
            NSLog(@"Rendering started");
        }
    };
    /* Sets up this instance of the ALVideoView to work with given service and to render
     * contents of given sink. Additionally, this method allows an application to specify 
     * whether the video feed should be mirrored or not. This is especially useful when 
     * rendering local preview video feed.
     */
    [self.localPreviewVV setupWithService:_alService withSink:_localVideoSinkId withMirror:YES];
    
    // Starting the render
    [self.localPreviewVV start:[ALResponder responderWithBlock:onRenderStarted]];
    self.startRenderBtn.hidden = YES;
    self.stopRenderBtn.hidden = NO;
}

- (IBAction)stopRender:(id)sender
{
    /**
     * Responder block called when the render stops
     */
    ResultBlock onRenderStopped = ^(ALError* err, id nothing){
        if(err) {
            NSLog(@"Failed to stop the rendering due to: %@ (ERR_CODE:%d)",
                  err.err_message, err.err_code);
            return;
        } else {
            NSLog(@"Rendering stopped");
        }
    };
    
    // Stopping the render
    [self.localPreviewVV stop:[ALResponder responderWithBlock:onRenderStopped]];
    self.startRenderBtn.hidden = NO;
    self.stopRenderBtn.hidden = YES;
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
    if(err)
    {
        NSLog(@"Failed to set the camera due to: %@ (ERR_CODE:%d)",
              err.err_message, err.err_code);
        return;
    }
    NSLog(@"Video device set");
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
    NSLog(@"Got local video started. When clicking will render using sink: %@",sinkId);
    
    // Enabling the button
    self.startRenderBtn.enabled = YES;
    
    // Copying value
    _localVideoSinkId = [sinkId copy];
}

/**
 * Handles the possible error coming from the sdk
 */
- (void) handleErrorMaybe:(ALError*)err where:(NSString*)where
{
    NSString* msg = [NSString stringWithFormat:@"Got an error with %@: %@ (%d)",
                     where, err.err_message, err.err_code];
    NSLog(@"%@", msg);
    self.errorLbl.hidden = NO;
    self.errorContentLbl.text = msg;
    self.errorContentLbl.hidden = NO;
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
