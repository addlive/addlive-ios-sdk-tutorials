//
//  ALViewController.h
//  Tutorial2.1
//
//  Created by Juan Docal on 19.03.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddLive/AddLiveAPI.h>

@interface ALTutorialTwoOneViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel *errorLbl;
@property (weak, nonatomic) IBOutlet UILabel *errorContentLbl;
@property (strong, nonatomic) IBOutlet UIButton *startRenderBtn;
@property (strong, nonatomic) IBOutlet UIButton *stopRenderBtn;

@end
