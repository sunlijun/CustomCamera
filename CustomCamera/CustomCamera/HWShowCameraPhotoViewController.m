//
//  HWShowCameraPhotoViewController.m
//  HWUniverscan
//
//  Created by mac on 16/3/24.
//  Copyright © 2016年 HWCloud. All rights reserved.
//

#import "HWShowCameraPhotoViewController.h"

@interface HWShowCameraPhotoViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@end

@implementation HWShowCameraPhotoViewController
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = NO;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"返回" style:UIBarButtonItemStylePlain target:self action:@selector(backClick)];
    self.imageView.image = self.cameraImage;
    
}
- (IBAction)doneBtnClick:(UIButton *)sender {
}

- (IBAction)repeatBtnClick:(UIButton *)sender {
    
    [self backClick];
}


-(void)backClick
{
    [self.navigationController popViewControllerAnimated:YES];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
