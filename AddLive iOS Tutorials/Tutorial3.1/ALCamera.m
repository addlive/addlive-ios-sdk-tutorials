//
//  ALCamera.m
//  AddLive iOS Tutorials
//
//  Created by Juan Docal on 25.03.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import "ALCamera.h"
#import <AVFoundation/AVFoundation.h>

@interface ALCamera ()

@property (nonatomic,retain) ALService* service;
@property (nonatomic,retain) AVCaptureSession* session;
@property (nonatomic,retain) ALVideoFrame* videoFrame;

- (void) configure;

@end // Camera

@implementation ALCamera

- (id) initWithService:(ALService*) service
{
    self = [super init];
    if (self)
    {
        self.service = service;
        self.session = nil;
        self.videoFrame = [[ALVideoFrame alloc] init];

        [self configure];
    }
    return self;
}

- (void) dealloc
{
    self.service = nil;
    self.session = nil;
    self.videoFrame = nil;
}

- (void) configure
{
    self.session = [[AVCaptureSession alloc] init];
    
    [self.session beginConfiguration];
    
    self.session.sessionPreset = AVCaptureSessionPreset640x480;
    
    AVCaptureDevice* device =
    [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]
     objectAtIndex:0];
    
    AVCaptureDeviceInput* input =
    [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    
    AVCaptureVideoDataOutput* output = [[AVCaptureVideoDataOutput alloc] init];
    [output setAlwaysDiscardsLateVideoFrames:YES];
    output.videoSettings =
    [NSDictionary dictionaryWithObject:
     [NSNumber numberWithInt:
      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    dispatch_queue_t queue = dispatch_queue_create("com.addlive.externalCamQ", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    
    [self.session addInput:input];
    [self.session addOutput:output];
    
    AVCaptureConnection* conn =
    [output connectionWithMediaType:AVMediaTypeVideo];
    if (conn.supportsVideoMinFrameDuration){
        conn.videoMinFrameDuration = CMTimeMake(1, 15);
    }
    if (conn.supportsVideoMaxFrameDuration){
        conn.videoMaxFrameDuration = CMTimeMake(1, 15);
    }
    conn.videoMirrored = NO;
    conn.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    [self.session commitConfiguration];
}

- (void) start
{
    [self.session startRunning];
}

- (void) stop
{
    [self.session stopRunning];
}

- (void) captureOutput:(AVCaptureOutput*) captureOutput
 didOutputSampleBuffer:(CMSampleBufferRef) sampleBuffer
        fromConnection:(AVCaptureConnection*) connection
{
    self.videoFrame.frameBuffer = sampleBuffer;
    
    // IMPORTANT: injectFrame expects a 420YpCbCr8BiPlanarFullRange and frame
    //            gets timestamped inside the service.
    
    [self.service injectFrame:self.videoFrame];
}

@end // Camera
