//
//  ALTutorialSixViewController.m
//  Tutorial6
//
//  Created by Tadeusz Kozak on 8/26/13.
//  Copyright (c) 2013 AddLive. All rights reserved.
//

#import "ALTutorialSixViewController.h"
#import <AVFoundation/AVFoundation.h>

/**
 * Interface defining application constants. In our case it is just the
 * Application id and API key.
 */
@interface Consts : NSObject

+ (NSNumber*) APP_ID;

+ (NSString*) API_KEY;

+ (NSString*) SCOPE_ID;

@end

@interface PlaybackCompleteDelegate : NSObject<AVAudioPlayerDelegate>

@property ALService* service;

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag;

@end


@interface ALTutorialSixViewController ()

{
    ALService*                _alService;
    NSArray*                  _cams;
    NSNumber*                 _selectedCam;
    NSString*                 _localVideoSinkId;
    BOOL                      _paused;
    BOOL                      _settingCam;
    BOOL                      _localPreviewStarted;
    BOOL                      _connecting;

    
    AVAudioPlayer*            _player;
    PlaybackCompleteDelegate* _playbackCompleteDelegate;
}
@end

@implementation ALTutorialSixViewController

- (void)viewDidLoad
{
    
    _paused = NO;
    _settingCam = NO;
    [super viewDidLoad];
    [self initAddLive];
    _connecting = NO;
    
    _playbackCompleteDelegate = [[PlaybackCompleteDelegate alloc] init];
    NSURL *url;
    
    //where you are about to add sound
    NSString *path =[[NSBundle mainBundle] pathForResource:@"test" ofType:@"wav"];
    
    url = [NSURL fileURLWithPath:path];
    _player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:NULL];
    [_player setVolume:1.0];
    [_player prepareToPlay];
    [_player setDelegate:_playbackCompleteDelegate];

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
    descr.autopublishVideo = NO;
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
    };
    [_alService disconnect:Consts.SCOPE_ID
                 responder:[ALResponder responderWithBlock:onDisconn]];
}

- (IBAction) playSnd:(id)sender {
    NSLog(@"Playing sound");
    ResultBlock onUnpublished = ^(ALError* err, id nothing) {
        // Change the AVAudioSession configuration to allow sound playback.
        // After the playback is complete, it will be restored by
        // the PlaybackCompleteDelegate
        AVAudioSession* session = [AVAudioSession sharedInstance];
        [session setMode:AVAudioSessionModeDefault error:nil];
        [session setCategory:AVAudioSessionCategorySoloAmbient error:nil];
        
        [_player play];
    };
    [_alService unpublish:Consts.SCOPE_ID
                     what:ALMediaType.kAudio
                responder:[ALResponder responderWithBlock:onUnpublished]];
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
    _connectBtn.hidden = NO;
    _playbackCompleteDelegate.service = _alService;
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
    return @"AddLiveSuperSecret";
}

+ (NSString*) SCOPE_ID {
    return @"ADL_iOS";
}

@end

@implementation PlaybackCompleteDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    AVAudioSession* session = [AVAudioSession sharedInstance];
    
    // Restore the session configuration
    [session setMode:AVAudioSessionModeVoiceChat error:nil];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [_service setAudioOutputDevice:ALAudioOutputDevice.kLoudSpeaker responder:nil];
    [_service publish:Consts.SCOPE_ID what:ALMediaType.kAudio options:nil responder:nil];
}

@end

