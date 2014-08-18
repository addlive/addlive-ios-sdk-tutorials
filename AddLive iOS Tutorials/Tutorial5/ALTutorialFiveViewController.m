//
//  ALTutorialFiveViewController.m
//  Tutorial5
//
//  Created by Juan Docal on 05.02.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import "ALTutorialFiveViewController.h"
#import <AVFoundation/AVFoundation.h>

#define kEventInfo @"eventInfo"

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

@interface MyServiceListener : NSObject <ALServiceListener>

- (void) onUserEvent:(ALUserStateChangedEvent *)event;

- (void) onMediaStreamEvent:(ALUserStateChangedEvent *)event;

@end

@interface ALTutorialFiveViewController () <UIScrollViewDelegate>

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
    int                       _remoteVideoWidth;
    int                       _remoteVideoHeight;
    int                       _remoteVideoMargin;
    int                       _screenWidth;
    BOOL                      _micFunctional;
}
@end

@implementation ALTutorialFiveViewController

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
    _listener = [[MyServiceListener alloc] init];
    [self initAddLive];
    _connecting = NO;
    
    self.pageControl.numberOfPages = 0;
    self.pageControl.currentPage = 0;
    self.scrollView.delegate = self;
    
    NSDictionary* mapping = @{@"onUserJoined":[NSValue valueWithPointer:@selector(onUserJoined:)],
                              @"onUserDisjoined":[NSValue valueWithPointer:@selector(onUserDisjoined:)],
                              @"onMediaStreamEvent":[NSValue valueWithPointer:@selector(onMediaStreamEvent:)],
                              @"applicationPause":[NSValue valueWithPointer:@selector(applicationPause:)],
                              @"applicationResume":[NSValue valueWithPointer:@selector(applicationResume:)]};
    
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
        if([self handleErrorMaybe:err where:@"Connect"])
        {
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
    [_alService disconnect:Consts.SCOPE_ID responder:[ALResponder responderWithBlock:onDisconn]];
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
    if([self handleErrorMaybe:err where:@"onPlatformReady:withInitResult:"])
    {
        return;
    }
    
    _micFunctional = initResult.micFunctional;
    
    _settingCam = YES;
    [_alService startLocalVideo:[[ALResponder alloc] initWithSelector:@selector(onLocalVideoStarted:withSinkId:)
                                                           withObject:self]];
    [_alService addServiceListener:_listener responder:nil];
}

/**
 * Responder method called when the local video starts
 */
- (void) onLocalVideoStarted:(ALError*)err withSinkId:(NSString*)sinkId
{
    if([self handleErrorMaybe:err where:@"onLocalVideoStarted:withSinkId:"])
    {
        return;
    }
    NSLog(@"Got local video started. Will render using sink: %@",sinkId);
    [self.localPreviewVV setupWithService:_alService withSink:sinkId withMirror:YES];
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
 * Receives the notification when an user joins the room
 */
- (void) onUserJoined:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // 1. Details of the event sent by the event onUserEvent defined in the ALServiceListener
    ALUserStateChangedEvent* eventDetails = [userInfo objectForKey:kEventInfo];
    
    // 2. etting userId of the user joining the session from the ALUserStateChangedEvent
    NSNumber* userIdNumber = [NSNumber numberWithLongLong:eventDetails.userId];
    
    // 3. Initializing the ALVideoView and setting it's corresponding frame property inside the scrollview
    ALVideoView *videoView = [[ALVideoView alloc] initWithFrame:[self updateVideoFrame:[_alUserIdToVideoView count]]];
    videoView.backgroundColor = [UIColor grayColor];
    
    // 4. Setting up the ALVideoView with the service and the videoSinkId of the user joining
    [videoView setupWithService:_alService withSink:eventDetails.videoSinkId withMirror:NO];
    
    // 5. Starting the chat and setting the responder
    if (eventDetails.videoPublished || eventDetails.screenPublished) {
        [videoView start:[[ALResponder alloc] initWithSelector:@selector(onRemoteRenderStarted:)
                                                    withObject:self]];
    }
    
    // 6. Adding the ALVideoView we created to the scrollView object
    [self.scrollView addSubview: videoView];
    
    // 7. Saving that ALVideoView into a NSMutableDictionary for further processing (Disconnecting, etc)
    [_alUserIdToVideoView setObject:videoView forKey:userIdNumber];
    
    // 8. Setting up the new contentSize
    [self.scrollView setContentSize:CGSizeMake(MAX(1, [_alUserIdToVideoView count]) * self.scrollView.frame.size.width, self.scrollView.frame.size.height)];
    
    // 9. Moving to the joining user ALVideoView
    [self.scrollView setContentOffset:CGPointMake(_screenWidth * ([_alUserIdToVideoView count] - 1), 0) animated:YES];
    
    // 10. Setting the new number of pages
    self.pageControl.numberOfPages = [_alUserIdToVideoView count];
    
    // 11. Setting the new current page
    self.pageControl.currentPage = [_alUserIdToVideoView count] - 1;
}

/**
 * Receives the notification when an user leaves the room
 */
- (void) onUserDisjoined:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // 1. We get the details of the event sent by the event onUserEvent defined in the ALServiceListener
    ALUserStateChangedEvent* eventDetails = [userInfo objectForKey:kEventInfo];
    
    // 2. Getting userId of the user joining the session from the ALUserStateChangedEvent
    NSNumber* userIdNumber = [NSNumber numberWithLongLong:eventDetails.userId];
    
    // 3. Getting ALVideoView of the disconnected user
    ALVideoView* videoView = [_alUserIdToVideoView objectForKey:userIdNumber];
    
    // 4. Stopping the chat and setting the responder
    [videoView stop:[[ALResponder alloc] initWithSelector:@selector(onRemoteRenderStopped:)
                                               withObject:self]];
    
    // 5. Removing the object from it's view
    [videoView removeFromSuperview];
    
    // 6. Removing the object from the NSMutableDictionary
    [_alUserIdToVideoView removeObjectForKey:userIdNumber];
    
    // 7. Setting the new ALVideoView frames
    int idx = 0;
    for (ALVideoView* videoView in [_alUserIdToVideoView allValues])
    {
        [videoView setFrame:[self updateVideoFrame:idx]];
        idx++;
    }
    
    // 8. Moving to the joining user ALVideoView
    [self.scrollView setContentSize:CGSizeMake(MAX(1, [_alUserIdToVideoView count]) * self.scrollView.frame.size.width, self.scrollView.frame.size.height)];
    
    // 9. Setting the new number of pages
    self.pageControl.numberOfPages = [_alUserIdToVideoView count];
}


/**
 * Receives the notification when a media event occurs.
 */
- (void) onMediaStreamEvent:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // Details of the event sent by the event onMediaStreamEvent defined in the ALServiceListener.
    ALUserStateChangedEvent* event = [userInfo objectForKey:kEventInfo];
    
    NSLog(@"Got media stream event %lld videoPublished %d", event.userId, event.videoPublished);
    
    if([event.mediaType isEqualToString:ALMediaType.kVideo])
    {
        if(event.videoPublished)
        {
            // 1. Getting userId of the user joining the session from the ALUserStateChangedEvent
            NSNumber* userIdNumber = [NSNumber numberWithLongLong:event.userId];
            
            // 2. Getting ALVideoView of the disconnected user
            ALVideoView* videoView = [_alUserIdToVideoView objectForKey:userIdNumber];
            
            // 3. Setting up the ALVideoView with the service and the videoSinkId of the user joining
            [videoView setupWithService:_alService withSink:event.videoSinkId withMirror:NO];
            
            // 4. Starting the chat and setting the responder
            [videoView start:[[ALResponder alloc] initWithSelector:@selector(onRemoteRenderStarted:)
                                                        withObject:self]];
        }
        else
        {
            // 1. Getting userId of the user joining the session from the ALUserStateChangedEvent
            NSNumber* userIdNumber = [NSNumber numberWithLongLong:event.userId];
            
            // 2. Getting ALVideoView of the disconnected user
            ALVideoView* videoView = [_alUserIdToVideoView objectForKey:userIdNumber];
            
            // 3. Stopping the chat and setting the responder
            [videoView stop:[[ALResponder alloc] initWithSelector:@selector(onRemoteRenderStopped:)
                                                       withObject:self]];
        }
    }
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
    [_alService unpublish:Consts.SCOPE_ID
                     what:ALMediaType.kVideo
                responder:[ALResponder responderWithBlock:onUnpublishVideo]];
    
    [self.localPreviewVV stop:nil];
    [_alService stopLocalVideo:nil];
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
    [_alService publish:Consts.SCOPE_ID
                   what:ALMediaType.kVideo options:nil
              responder:[ALResponder responderWithBlock:onPublishVideo]];
    
    [_alService startLocalVideo:[[ALResponder alloc]
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

@implementation MyServiceListener

/**
 * Listener to capture an user event. (user joining media scope, user leaving media scope,
 * user publishing or stop publishing any of possible media streams.)
 */
- (void) onUserEvent:(ALUserStateChangedEvent *)event
{
    if(event.isConnected)
    {
        NSLog(@"Got user connected: %@", event);
        NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
        [userInfo setValue:event forKey:kEventInfo];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"onUserJoined" object:self userInfo:userInfo];
    }
    else
    {
        NSLog(@"Got user disconnected: %@", event);
        NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
        [userInfo setValue:event forKey:kEventInfo];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"onUserDisjoined" object:self userInfo:userInfo];
    }
}

/**
 * Notifies about media streaming status change for given remote user.
 */
- (void) onMediaStreamEvent:(ALUserStateChangedEvent *)event
{
    NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setValue:event forKey:kEventInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"onMediaStreamEvent" object:self userInfo:userInfo];
}

@end
