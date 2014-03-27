//
//  ALCamera.h
//  AddLive iOS Tutorials
//
//  Created by Juan Docal on 25.03.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import "AddLive/AddLiveAPI.h"

@interface ALCamera : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

- (ALCamera*) initWithService:(ALService*) service;
- (void) start;
- (void) stop;

@end
