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

@property(nonatomic, strong) ALVideoView *localPreviewVV;

@end

@implementation ALTutorialTwoOneViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self initAddLive];
}

- (IBAction)startRender:(id)sende
{
    CGRect frame;
    
    // Defining values to set the VideoView size properly
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        // setting frame.
        frame = CGRectMake(164.0, 112.0, 441.0, 582.0);
    }
    else
    {
        // setting frame.
        frame = CGRectMake(40.0, 82.0, 239.0, 320.0);
    }
    
    // ALVideoView alloc.
    _localPreviewVV = [[ALVideoView alloc] initWithFrame:frame];
    
    // Adding it to it's parent.
    [self.view addSubview:_localPreviewVV];
    
    /**
     * Responder method called when the render starts
     */
    ResultBlock onRenderStarted = ^(ALError* err, id nothing) {
        if ([self handleErrorMaybe:err where:@"onRenderStarted:"]) {
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
    [_localPreviewVV setupWithService:_alService withSink:_localVideoSinkId withMirror:YES];
    
    // Starting the render
    [_localPreviewVV start:[ALResponder responderWithBlock:onRenderStarted]];
    self.startRenderBtn.hidden = YES;
    self.stopRenderBtn.hidden = NO;
}

- (IBAction)stopRender:(id)sender
{
    /**
     * Responder block called when the render stops
     */
    ResultBlock onRenderStopped = ^(ALError* err, id nothing){
        if ([self handleErrorMaybe:err where:@"onRenderStopped:"]) {
            return;
        } else {
            NSLog(@"Rendering stopped");
            
            // Remove it from it's parent
            [_localPreviewVV removeFromSuperview];
            
            _localPreviewVV = nil;
            
            self.startRenderBtn.hidden = NO;
            self.stopRenderBtn.hidden = YES;
        }
    };
    
    // Stopping the render
    [_localPreviewVV stop:[ALResponder responderWithBlock:onRenderStopped]];
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
    if ([self handleErrorMaybe:err where:@"onPlatformReady:"])
    {
        return;
    }
    
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
    NSLog(@"Got local video started. When clicking will render using sink: %@",sinkId);
    
    // Enabling the button
    self.startRenderBtn.enabled = YES;
    
    // Copying value
    _localVideoSinkId = [sinkId copy];
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
