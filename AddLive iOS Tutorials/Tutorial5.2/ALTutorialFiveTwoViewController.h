//
//  ALViewController.h
//  Tutorial5.2
//
//  Created by Juan Docal on 04.07.14.
//  Copyright (c) 2014 AddLive. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddLive/AddLiveAPI.h>

@interface ALTutorialFiveTwoViewController : UIViewController

@property(strong, nonatomic) IBOutlet ALVideoView *localPreviewVV;
@property(strong, nonatomic) IBOutlet UILabel *stateLbl;
@property(strong, nonatomic) IBOutlet UILabel *errorLbl;
@property(strong, nonatomic) IBOutlet UILabel *errorContentLbl;
@property(strong, nonatomic) IBOutlet UIButton *connectBtn;
@property(strong, nonatomic) IBOutlet UIButton *disconnectBtn;
@property(strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property(strong, nonatomic) IBOutlet UIPageControl *pageControl;

- (IBAction)connect:(id)sender;
- (IBAction)disconnect:(id)sender;

@end
