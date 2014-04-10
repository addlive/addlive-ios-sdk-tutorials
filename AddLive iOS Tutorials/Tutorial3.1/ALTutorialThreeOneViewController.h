//
//  ALViewController.h
//  Tutorial3.1
//
//  Created by Juan Docal on 25.03.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddLive/AddLiveAPI.h>

@interface ALTutorialThreeOneViewController : UIViewController

@property (strong, nonatomic) IBOutlet ALVideoView *remoteVV;
@property (strong, nonatomic) IBOutlet UILabel *errorLbl;
@property (strong, nonatomic) IBOutlet UILabel *errorContentLbl;
@property (strong, nonatomic) IBOutlet UILabel *stateLbl;
@property (strong, nonatomic) IBOutlet UIButton *connectBtn;
@property (strong, nonatomic) IBOutlet UIButton *disconnectBtn;

@end
