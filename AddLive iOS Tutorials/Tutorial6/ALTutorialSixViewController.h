//
//  ALTutorialSixViewController.h
//  Tutorial6
//
//  Created by Tadeusz Kozak on 8/26/13.
//  Copyright (c) 2013 AddLive. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddLive/AddLiveAPI.h>

@interface ALTutorialSixViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel *errorLbl;
@property (weak, nonatomic) IBOutlet UILabel *errorContentLbl;
@property (weak, nonatomic) IBOutlet UILabel *stateLbl;
@property (weak, nonatomic) IBOutlet UIButton *connectBtn;
@property (weak, nonatomic) IBOutlet UIButton *disconnectBtn;
@property (strong, nonatomic) IBOutlet UIButton *playSndBtn;


- (IBAction) connect:(id)sender;
- (IBAction) disconnect:(id)sender;
- (IBAction) playSnd:(id)sender;

@end
