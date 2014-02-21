//
//  ALTutorialEightViewController.h
//  Tutorial8
//
//  Created by Juan Docal on 08.02.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddLive/AddLiveAPI.h>

@interface ALTutorialEightViewController : UIViewController

@property (weak, nonatomic) IBOutlet ALVideoView *localPreviewVV;
@property (weak, nonatomic) IBOutlet UILabel *errorLbl;
@property (weak, nonatomic) IBOutlet UILabel *errorContentLbl;
@property (weak, nonatomic) IBOutlet UILabel *stateLbl;
@property (weak, nonatomic) IBOutlet UIButton *connectBtn;
@property (weak, nonatomic) IBOutlet UIButton *disconnectBtn;

- (IBAction)connect:(id)sender;
- (IBAction)disconnect:(id)sender;

@end
