//
//  ALViewController.h
//  Tutorial4.1
//
//  Created by Juan Docal on 21.03.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddLive/AddLiveAPI.h>

@interface ALTutorialThreeTwoViewController : UIViewController

@property (strong, nonatomic) IBOutlet ALVideoView *localPreviewVV;
@property (strong, nonatomic) IBOutlet ALVideoView *firstRemoteVV;
@property (strong, nonatomic) IBOutlet ALVideoView *secondRemoteVV;
@property (strong, nonatomic) IBOutlet UILabel *errorContentLbl;
@property (strong, nonatomic) IBOutlet UILabel *errorLbl;
@property (strong, nonatomic) IBOutlet UILabel *stateLbl;
@property (strong, nonatomic) IBOutlet UIButton *connectBtn;
@property (strong, nonatomic) IBOutlet UIButton *disconnectBtn;

@end
