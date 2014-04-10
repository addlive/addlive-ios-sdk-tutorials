//
//  ALTutorialFourViewController.h
//  Tutorial2
//
//  TODO [tk_review] Please change "Created by" to some real value. Do  :)
//  Created by Tadeusz Kozak on 8/26/13.
//  Copyright (c) 2013 AddLive. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddLive/AddLiveAPI.h>

@interface ALTutorialFourViewController : UIViewController

@property (weak, nonatomic) IBOutlet ALVideoView *localPreviewVV;
@property (weak, nonatomic) IBOutlet ALVideoView *remoteVV;
@property (weak, nonatomic) IBOutlet UILabel *errorLbl;
@property (weak, nonatomic) IBOutlet UILabel *errorContentLbl;
@property (weak, nonatomic) IBOutlet UILabel *stateLbl;
@property (weak, nonatomic) IBOutlet UIButton *connectBtn;
@property (weak, nonatomic) IBOutlet UIButton *disconnectBtn;

- (IBAction)connect:(id)sender;
- (IBAction)disconnect:(id)sender;

@end
