//
//  ALTutorialFiveViewController.m
//  Tutorial5
//
//  Created by Juan Docal on 05.02.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import "ALTutorialFiveViewController.h"

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

- (void) onVideoFrameSizeChanged:(ALVideoFrameSizeChangedEvent*) event;

- (void) onUserEvent:(ALUserStateChangedEvent *)event;

- (void) onConnectionLost:(ALConnectionLostEvent *)event;

- (void) onSessionReconnected:(ALSessionReconnectedEvent *)event;

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
        _remoteVideoWidth = 480;
        _remoteVideoHeight = 512;
        _remoteVideoMargin = 144;
        _screenWidth = 768;
    }
    else
    {
        _remoteVideoWidth = 227;
        _remoteVideoHeight = 261;
        _remoteVideoMargin = 46;
        _screenWidth = 320;
    }
    
	_alUserIdToVideoView = [[NSMutableDictionary alloc] init];
    
    _paused = NO;
    _settingCam = NO;
    [super viewDidLoad];
    _listener = [[MyServiceListener alloc] init];
    [self initAddLive];
    _connecting = NO;
    
    self.pageControl.numberOfPages = 0;
    self.pageControl.currentPage = 0;
    self.scrollView.delegate = self;
    
    // Notification triggered when an user join the session
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUserJoined:)
                                                 name:@"onUserJoined"
                                               object:nil];
    
    // Notification triggered when an user disjoin the session
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUserDisjoined:)
                                                 name:@"onUserDisjoined"
                                               object:nil];
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
    ALUserStateChangedEvent* eventDetails = [userInfo objectForKey:@"event"];
    
    // 2. etting userId of the user joining the session from the ALUserStateChangedEvent
    NSNumber* userIdNumber = [NSNumber numberWithLongLong:eventDetails.userId];
    
    // 3. Initializing the ALVideoView and setting it's corresponding frame property inside the scrollview
    ALVideoView *videoView = [[ALVideoView alloc] initWithFrame:[self updateVideoFrame:[_alUserIdToVideoView count]]];
    videoView.backgroundColor = [UIColor grayColor];
    
    // 4. Setting up the ALVideoView with the service and the videoSinkId of the user joining
    [videoView setupWithService:_alService withSink:eventDetails.videoSinkId withMirror:YES];
    
    // 5. Block called when the remote render starts
    ResultBlock onRemoteRenderStarted = ^(ALError* err, id nothing) {
        if(err)
        {
            NSLog(@"Failed to start the rendering due to: %@ (ERR_CODE:%d)",
                  err.err_message, err.err_code);
            return;
        }
        else
        {
            NSLog(@"Remote Rendering started");
        }
    };
    
    // 6. Starting the chat and setting the responder
    [videoView start:[ALResponder responderWithBlock:onRemoteRenderStarted]];
    
    // 7. Adding the ALVideoView we created to the scrollView object
    [self.scrollView addSubview: videoView];
    
    // 8. Saving that ALVideoView into a NSMutableDictionary for further processing (Disconnecting, etc)
    [_alUserIdToVideoView setObject:videoView forKey:userIdNumber];
    
    // 9. Setting up the new contentSize
    [self.scrollView setContentSize:CGSizeMake(MAX(1, [_alUserIdToVideoView count]) * self.scrollView.frame.size.width, self.scrollView.frame.size.height)];
    
    // 10. Moving to the joining user ALVideoView
    [self.scrollView setContentOffset:CGPointMake(_screenWidth * ([_alUserIdToVideoView count] - 1), 0) animated:YES];
    
    // 11. Setting the new number of pages
    self.pageControl.numberOfPages = [_alUserIdToVideoView count];
    
    // 12. Setting the new current page
    self.pageControl.currentPage = [_alUserIdToVideoView count] - 1;
}

/**
 * Receives the notification when an user leaves the room
 */
- (void) onUserDisjoined:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    
    // 1. We get the details of the event sent by the event onUserEvent defined in the ALServiceListener
    ALUserStateChangedEvent* eventDetails = [userInfo objectForKey:@"event"];
    
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
    
    // Block called when setting a cam
    ResultBlock onCamSet = ^(ALError* err, id nothing)
    {
        NSLog(@"Video device set");
        _settingCam = YES;
        [_alService startLocalVideo:[[ALResponder alloc] initWithSelector:@selector(onLocalVideoStarted:withSinkId:)
                                                               withObject:self]];
    };
    
    [_alService setVideoCaptureDevice:dev.id
                            responder:[ALResponder responderWithBlock:onCamSet]];
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
 * Responder method called when the local render starts
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
 * Responder method called when the remote render stops
 */
- (void) onRemoteRenderStopped:(ALError*) err
{
    if(err)
    {
        NSLog(@"Failed to start the rendering due to: %@ (ERR_CODE:%d)",
              err.err_message, err.err_code);
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
    return @"AddLiveSuperSecret";
}

+ (NSString*) SCOPE_ID
{
    return @"ADL_iOS";
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
        [userInfo setValue:event forKey:@"event"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"onUserJoined" object:self userInfo:userInfo];
    }
    else
    {
        NSLog(@"Got user disconnected: %@", event);
        NSDictionary *userInfo = [[NSMutableDictionary alloc] init];
        [userInfo setValue:event forKey:@"event"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"onUserDisjoined" object:self userInfo:userInfo];
    }
}

/**
 * Event describing a change of a resolution in a video feed produced by given video sink.
 */
- (void) onVideoFrameSizeChanged:(ALVideoFrameSizeChangedEvent*) event
{
    NSLog(@"Got video frame size changed. Sink id: %@, dims: %dx%d", event.sinkId,event.width,event.height);
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

@end
