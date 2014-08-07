//
//  ALTutorialFiveTwoViewController.m
//  Tutorial5.2
//
//  Created by Juan Docal on 08.07.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import "ALTutorialFiveThreeViewController.h"
#import <AVFoundation/AVFoundation.h>

#define kEventInfo @"event"

// iPad dimensions
#define kiPadRemoteVVWidth 480
#define kiPadRemoteVVHeight 512
#define kiPadRemoteVVLeft 144
#define kiPadScreenWidth 768

// iPhone dimensions
#define kiPhoneRemoteVVWidth 227
#define kiPhoneRemoteVVHeight 261
#define kiPhoneRemoteVVLeft 46
#define kiPhoneScreenWidth 320

/**
 * Interface defining application constants. In our case it is just the
 * Application id and API key.
 */

@interface Consts : NSObject

+ (NSNumber*) APP_ID;

+ (NSString*) API_KEY;

+ (NSString*) SCOPE_ID;

@end

@interface ALTutorialFiveThreeViewController () <UIScrollViewDelegate>

{
    NSArray*                  _cams;
    NSNumber*                 _selectedCam;
    NSString*                 _localVideoSinkId;
    BOOL                      _paused;
    BOOL                      _settingCam;
    BOOL                      _localPreviewStarted;
    BOOL                      _connecting;
    UIView*                   _container;
	NSMutableDictionary*      _alUserIdToVideoView;
    int                       _remoteVideoWidth;
    int                       _remoteVideoHeight;
    int                       _remoteVideoMargin;
    int                       _screenWidth;
    BOOL                      _micFunctional;
    NSNotificationCenter*     _notificationCenter;
}
@end

@implementation ALTutorialFiveThreeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    /**
     * Defining values to set the scrollview content size properly
     */
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        _remoteVideoWidth = kiPadRemoteVVWidth;
        _remoteVideoHeight = kiPadRemoteVVHeight;
        _remoteVideoMargin = kiPadRemoteVVLeft;
        _screenWidth = kiPadScreenWidth;
    }
    else
    {
        _remoteVideoWidth = kiPhoneRemoteVVWidth;
        _remoteVideoHeight = kiPhoneRemoteVVHeight;
        _remoteVideoMargin = kiPhoneRemoteVVLeft;
        _screenWidth = kiPhoneScreenWidth;
    }
    
	_alUserIdToVideoView = [[NSMutableDictionary alloc] init];
    
    _paused = NO;
    _settingCam = NO;
    _connecting = NO;
    
    self.pageControl.numberOfPages = 0;
    self.pageControl.currentPage = 0;
    self.scrollView.delegate = self;
    
    // Defining the NSNotificationCenter to use when receiving the events.
    _notificationCenter = [NSNotificationCenter defaultCenter];
    
    [self initAddLive];
    
    NSDictionary* mapping = @{@"onUserEvent":[NSValue valueWithPointer:@selector(onUserEvent:)],
                              @"onMediaStreamEvent":[NSValue valueWithPointer:@selector(onMediaStreamEvent:)],
                              @"onVideoFrameSizeChanged":[NSValue valueWithPointer:@selector(onVideoFrameSizeChanged:)],
                              @"applicationPause":[NSValue valueWithPointer:@selector(applicationPause:)],
                              @"applicationResume":[NSValue valueWithPointer:@selector(applicationResume:)]};
    
    [mapping enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [_notificationCenter addObserver:self
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
        if([self handleErrorMaybe:err where:@"Connect"])
        {
            return;
        }
        NSLog(@"Successfully connected");
        _stateLbl.text = @"Connected";
        _connectBtn.hidden = YES;
        _disconnectBtn.hidden = NO;
    };
    [[ALService sharedInstance] connect:descr responder:[ALResponder responderWithBlock:onConn]];
}

/**
 * Button action to start the deferred disconnection.
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
        _cancelDisconnectBtn.hidden = YES;
        self.pageControl.numberOfPages = 0;
        self.pageControl.currentPage = 0;
        for (ALVideoView* videoView in [_alUserIdToVideoView allValues])
		{
			[videoView stop:[[ALResponder alloc] initWithSelector:@selector(onRemoteRenderStopped:)
                                                       withObject:self]];
			[videoView removeFromSuperview];
		}
        [_alUserIdToVideoView removeAllObjects];
        [self.scrollView setContentSize:self.scrollView.bounds.size];
    };
    // Perform the disconnection after a two seconds delay.
    [[ALService sharedInstance] deferredDisconnect:Consts.SCOPE_ID milliseconds:@2000 responder:[ALResponder responderWithBlock:onDisconn]];
    _cancelDisconnectBtn.hidden = NO;
}

/**
 * Button action to cancel the deferred disconnection.
 */
- (IBAction)cancelDisconnect:(id)sender
{
    ResultBlock onCancelDisconn = ^(ALError* err, id nothing) {
        if([self handleErrorMaybe:err where:@"onCancelDisconn:"])
        {
            return;
        }
        NSLog(@"Successfully cancelled the disconnection");
        _connectBtn.hidden = YES;
        _disconnectBtn.hidden = NO;
        _cancelDisconnectBtn.hidden = YES;
    };
    [[ALService sharedInstance] cancelDeferredDisconnect:Consts.SCOPE_ID responder:[ALResponder responderWithBlock:onCancelDisconn]];
}

/**
 * Initializes the AddLive SDK.
 * For a more detailed explanation about the initialization please check Tutorial 1.
 */
- (void) initAddLive
{
    ALResponder* responder =[[ALResponder alloc] initWithSelector:@selector(onPlatformReady:withInitResult:)
                                                       withObject:self];
    
    ALInitOptions* initOptions = [[ALInitOptions alloc] init];
    initOptions.applicationId = Consts.APP_ID;
    initOptions.apiKey = Consts.API_KEY;
    initOptions.logInteractions = YES;
    
    // Specifying the notification center to use when dispatching events.
    initOptions.notificationCenter = _notificationCenter;
    
    [ALService initPlatform:initOptions responder:responder];
    
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
    [[ALService sharedInstance] startLocalVideo:[[ALResponder alloc] initWithSelector:@selector(onLocalVideoStarted:withSinkId:)
                                                                           withObject:self]];
}

/**
 * Responder method called when the local video starts
 */
- (void) onLocalVideoStarted:(ALError*)err withSinkId:(NSString*) sinkId
{
    if([self handleErrorMaybe:err where:@"onLocalVideoStarted:withSinkId:"])
    {
        return;
    }
    NSLog(@"Got local video started. Will render using sink: %@",sinkId);
    [self.localPreviewVV setupWithService:[ALService sharedInstance] withSink:sinkId withMirror:YES];
    [self.localPreviewVV start:[ALResponder responderWithSelector:@selector(onRenderStarted:) object:self]];
    _localVideoSinkId = [sinkId copy];
    _settingCam = NO;
}

/**
 * Responder method called when the local render starts
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
        if(!_paused){
            _connectBtn.hidden = NO;
        } else {
            _paused = NO;
        }
    }
}

/**
 * Responder method called when the remote render stops
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
 * Responder method called when the remote render stops
 */
- (void) onRemoteRenderStopped:(ALError*) err
{
    if([self handleErrorMaybe:err where:@"onRemoteRenderStopped:"])
    {
        return;
    }
    else
    {
        NSLog(@"Remote Rendering stopped");
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
 * Sets the current page when scrolling
 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat pageWidth = self.scrollView.frame.size.width;
    float fractionalPage = self.scrollView.contentOffset.x / pageWidth;
    NSInteger page = lround(fractionalPage);
    self.pageControl.currentPage = page;
}

/**
 * Receives the notification about a change in connectivity status of a remote participant.
 */
- (void) onUserEvent:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onUserEvent.
    ALUserStateChangedEvent* eventDetails = [userInfo objectForKey:kEventInfo];
    
    // Check if the user is joining or leaving the session
    if (eventDetails.isConnected) {
        [self onUserJoined:eventDetails];
    } else {
        [self onUserDisjoined:eventDetails];
    }
}

/**
 * Receives the notification when an user joins the room
 */
- (void) onUserJoined:(ALUserStateChangedEvent *)eventDetails
{
    
    // setting userId of the user joining the session from the ALUserStateChangedEvent.
    NSNumber* userIdNumber = [NSNumber numberWithLongLong:eventDetails.userId];
    
    // Initializing the ALVideoView and setting it's corresponding frame property inside the scrollview.
    ALVideoView *videoView = [[ALVideoView alloc] initWithFrame:[self updateVideoFrame:[_alUserIdToVideoView count]]];
    videoView.backgroundColor = [UIColor grayColor];
    
    // Setting up the ALVideoView with the service and the videoSinkId of the user joining.
    [videoView setupWithService:[ALService sharedInstance] withSink:eventDetails.videoSinkId withMirror:NO];
    
    // Starting the chat and setting the responder
    [videoView start:[[ALResponder alloc] initWithSelector:@selector(onRemoteRenderStarted:)
                                                withObject:self]];
    
    // Adding the ALVideoView we created to the scrollView object.
    [self.scrollView addSubview: videoView];
    
    // Saving that ALVideoView into a NSMutableDictionary for further processing (Disconnecting, etc).
    [_alUserIdToVideoView setObject:videoView forKey:userIdNumber];
    
    // Setting up the new contentSize.
    [self.scrollView setContentSize:CGSizeMake(MAX(1, [_alUserIdToVideoView count]) * self.scrollView.frame.size.width, self.scrollView.frame.size.height)];
    
    // Moving to the joining user ALVideoView.
    [self.scrollView setContentOffset:CGPointMake(_screenWidth * ([_alUserIdToVideoView count] - 1), 0) animated:YES];
    
    // Setting the new number of pages.
    self.pageControl.numberOfPages = [_alUserIdToVideoView count];
    
    // Setting the new current page.
    self.pageControl.currentPage = [_alUserIdToVideoView count] - 1;
}

/**
 * Receives the notification when an user leaves the room.
 */
- (void) onUserDisjoined:(ALUserStateChangedEvent *)eventDetails
{
    
    // Getting userId of the user joining the session from the ALUserStateChangedEvent.
    NSNumber* userIdNumber = [NSNumber numberWithLongLong:eventDetails.userId];
    
    // Getting ALVideoView of the disconnected user.
    ALVideoView* videoView = [_alUserIdToVideoView objectForKey:userIdNumber];
    
    // Stopping the chat and setting the responder.
    [videoView stop:[[ALResponder alloc] initWithSelector:@selector(onRemoteRenderStopped:)
                                               withObject:self]];
    
    // Removing the object from it's view.
    [videoView removeFromSuperview];
    
    // Removing the object from the NSMutableDictionary.
    [_alUserIdToVideoView removeObjectForKey:userIdNumber];
    
    // Setting the new ALVideoView frames.
    int idx = 0;
    for (ALVideoView* videoView in [_alUserIdToVideoView allValues])
    {
        [videoView setFrame:[self updateVideoFrame:idx]];
        idx++;
    }
    
    // Moving to the joining user ALVideoView.
    [self.scrollView setContentSize:CGSizeMake(MAX(1, [_alUserIdToVideoView count]) * self.scrollView.frame.size.width, self.scrollView.frame.size.height)];
    
    // Setting the new number of pages.
    self.pageControl.numberOfPages = [_alUserIdToVideoView count];
}

/**
 * Receives the notification when a media event occurs.
 */
- (void) onMediaStreamEvent:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onMediaStreamEvent.
    ALUserStateChangedEvent* event = [userInfo objectForKey:kEventInfo];
    
    NSLog(@"Got media stream event %lld videoPublished %d", event.userId, event.videoPublished);
    
    if([event.mediaType isEqualToString:ALMediaType.kVideo])
    {
        if(event.videoPublished)
        {
            // 1. Getting userId of the user joining the session from the ALUserStateChangedEvent.
            NSNumber* userIdNumber = [NSNumber numberWithLongLong:event.userId];
            
            // 2. Getting ALVideoView of the disconnected user.
            ALVideoView* videoView = [_alUserIdToVideoView objectForKey:userIdNumber];
            
            // 3. Setting up the ALVideoView with the service and the videoSinkId of the user joining.
            [videoView setupWithService:[ALService sharedInstance] withSink:event.videoSinkId withMirror:NO];
            
            // 4. Starting the chat and setting the responder.
            [videoView start:[[ALResponder alloc] initWithSelector:@selector(onRemoteRenderStarted:)
                                                        withObject:self]];
        }
        else
        {
            // 1. Getting userId of the user joining the session from the ALUserStateChangedEvent.
            NSNumber* userIdNumber = [NSNumber numberWithLongLong:event.userId];
            
            // 2. Getting ALVideoView of the disconnected user.
            ALVideoView* videoView = [_alUserIdToVideoView objectForKey:userIdNumber];
            
            // 3. Stopping the chat and setting the responder.
            [videoView stop:[[ALResponder alloc] initWithSelector:@selector(onRemoteRenderStopped:)
                                                       withObject:self]];
        }
    }
}

/**
 * Receives the notification when a media event occurs.
 */
- (void) onVideoFrameSizeChanged:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onMediaStreamEvent.
    ALVideoFrameSizeChangedEvent* event = [userInfo objectForKey:kEventInfo];
    
    NSLog(@"onVideoFrameSizeChanged event received with params: %@", event);
}

/**
 * Receives the notification the application will resign to be active
 */
- (void) applicationPause:(NSNotification *)notification
{
    NSLog(@"Application will pause");
    
    ResultBlock onUnpublishVideo = ^(ALError* err, id nothing){
        if([self handleErrorMaybe:err where:@"onUnpublishVideo:"]) {
            return;
        }
    };
    [[ALService sharedInstance] unpublish:Consts.SCOPE_ID
                                     what:ALMediaType.kVideo
                                responder:[ALResponder responderWithBlock:onUnpublishVideo]];
    
    [self.localPreviewVV stop:nil];
    [[ALService sharedInstance] stopLocalVideo:nil];
    _paused = YES;
    
    for (ALVideoView* videoView in [_alUserIdToVideoView allValues]){
        [videoView stop:[[ALResponder alloc] initWithSelector:@selector(onRemoteRenderStopped:)
                                                   withObject:self]];
    }
}

/**
 * Receives the notification the app will enter foreground
 */
- (void) applicationResume:(NSNotification *)notification
{
    
    if(!_paused)
    {
        return;
    }
    NSLog(@"Application will resume");
    
    ResultBlock onPublishVideo = ^(ALError* err, id nothing){
        if([self handleErrorMaybe:err where:@"onPublishVideo:"]) {
            return;
        }
    };
    [[ALService sharedInstance] publish:Consts.SCOPE_ID
                                   what:ALMediaType.kVideo options:nil
                              responder:[ALResponder responderWithBlock:onPublishVideo]];
    
    [[ALService sharedInstance] startLocalVideo:[[ALResponder alloc]
                                                 initWithSelector:@selector(onLocalVideoStarted:withSinkId:)
                                                 withObject:self]];
    
    for (ALVideoView* videoView in [_alUserIdToVideoView allValues]){
        if(![videoView.sinkId isEqualToString:@""]){
            [videoView start:[[ALResponder alloc] initWithSelector:@selector(onRemoteRenderStarted:)
                                                        withObject:self]];
        }
    }
}

/**
 * Setting the ALVideoViews frame according to the device
 */
- (CGRect)updateVideoFrame:(int)idx
{
    CGRect frame;
    frame.origin.x = (_screenWidth * idx) + _remoteVideoMargin;
    frame.origin.y = 0;
    frame.size.width = _remoteVideoWidth;
    frame.size.height = _remoteVideoHeight;
    return frame;
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
