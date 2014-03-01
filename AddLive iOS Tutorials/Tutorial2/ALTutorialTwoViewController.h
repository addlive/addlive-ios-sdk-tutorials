//
//  ALTutorialTwoViewController.h
//  Tutorial2
//
//  Created by Tadeusz Kozak on 8/26/13.
//  Copyright (c) 2013 AddLive. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddLive/AddLiveAPI.h>

@interface ALTutorialTwoViewController : UIViewController
@property (weak, nonatomic) IBOutlet ALVideoView *localPreviewVV;
@property (weak, nonatomic) IBOutlet UILabel *errorLbl;
@property (weak, nonatomic) IBOutlet UILabel *errorContentLbl;



- (void) pause;
- (void) resume;
- (IBAction)onToggleCam:(id)sender;
- (IBAction)onToggleVideo:(id)sender;

@end
