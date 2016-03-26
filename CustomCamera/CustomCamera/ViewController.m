//
//  ViewController.m
//  CustomCamera
//
//  Created by bluehedgehog on 16/3/26.
//  Copyright © 2016年 bluehedgehog. All rights reserved.
//

#import "ViewController.h"
#import "LJCustomCameraViewController.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}
- (IBAction)cameraClick:(id)sender {
    LJCustomCameraViewController *cameraVC = [[LJCustomCameraViewController alloc]init];
    [self presentViewController:cameraVC animated:YES completion:nil];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
