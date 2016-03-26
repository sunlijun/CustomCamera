//
//  LJCustomCameraViewController.m
//  HWUniverscan
//
//  Created by hanvon on 16/3/15.
//  Copyright © 2016年 HWCloud. All rights reserved.
//
#define MaxEffectiveScale 4.0f
#define MinEffectiveScale 1.0f
#define ScreenWidth [UIScreen mainScreen].bounds.size.width
#define ScreenHeight [UIScreen mainScreen].bounds.size.height
#import "LJCustomCameraViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "HWShowCameraPhotoViewController.h"

@interface LJCustomCameraViewController ()<UIGestureRecognizerDelegate>
/// 选中照片数组
@property (nonatomic,strong) NSArray *images;
/// 选中资源素材数组，用于定位已经选择的照片
@property (nonatomic,strong) NSArray *selectedAssets;
//界面控件
@property (weak, nonatomic) IBOutlet UIView *preview;
// 切换摄像头
@property (weak, nonatomic) IBOutlet UIButton *switchCarmeraBtn;
// 闪光灯
@property (weak, nonatomic) IBOutlet UIButton *flashBtn;
// 相册
@property (weak, nonatomic) IBOutlet UIButton *albumBtn;
// 单拍
@property (weak, nonatomic) IBOutlet UIButton *singleTakeBtn;
//多拍
@property (weak, nonatomic) IBOutlet UIButton *moreTakeBtn;
// 闪光灯视图
@property (strong, nonatomic) IBOutlet UIView *flashView;
@property (weak, nonatomic) IBOutlet UIButton *flashView_AutoBtn;
@property (weak, nonatomic) IBOutlet UIButton *flashView_open;
@property (weak, nonatomic) IBOutlet UIButton *flashView_lightBtn;
@property (weak, nonatomic) IBOutlet UIButton *flashView_close;




//AVFoundation

@property (nonatomic) dispatch_queue_t sessionQueue;
/**
 *  控制输入和输出设备之间的数据传递
 */
@property (nonatomic, strong) AVCaptureSession* session;
/**
 *  输入设备调用所有的输入硬件。例如摄像头和麦克风
 */
@property (nonatomic, strong) AVCaptureDeviceInput* videoInput;
/**
 *  用于输出图像
 */
@property (nonatomic, strong) AVCaptureStillImageOutput* stillImageOutput;
/**
 *  镜头捕捉到得预览图层
 */
@property (nonatomic, strong) AVCaptureVideoPreviewLayer* previewLayer;


/**
 *  记录开始的缩放比例
 */
@property(nonatomic,assign)CGFloat beginGestureScale;
/**
 *  最后的缩放比例
 */
@property(nonatomic,assign)CGFloat effectiveScale;

/**
 *  是否是前摄像头
 */
@property (nonatomic,assign)BOOL isUsingFrontFacingCamera;


// 对焦框
@property (nonatomic, strong) UIImageView * focusImageView;
//相机硬件的接口 用于控制硬件特性，诸如镜头的位置、曝光、闪光灯等
@property (nonatomic, strong) AVCaptureDevice *device;
//提供来自设备的数据
@property (nonatomic, strong)AVCaptureDeviceInput *captureInput;
@property (nonatomic, assign) CGFloat preScaleNum;
//@property (nonatomic, assign) CGFloat scaleNum;
//根据设备输出获得连接
@property (nonatomic, strong)AVCaptureConnection *captureConnection;
// 闪光灯设备控制
@property (nonatomic, strong)AVCaptureDevice *CaptureDevice;
@end

@implementation LJCustomCameraViewController

- (AVCaptureDevice *)CaptureDevice
{
    if(!_CaptureDevice)
    {
        _CaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    return _CaptureDevice;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 初始化摄像头
    [self initAVCaptureSession];
    
     [self setUpGesture];
     self.effectiveScale = self.beginGestureScale = MinEffectiveScale;
    
    
}

- (void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:YES];
    self.navigationController.navigationBarHidden = YES;
    if (self.session) {
        
        [self.session startRunning];
    }
}

- (void)viewDidDisappear:(BOOL)animated{
    
    [super viewDidDisappear:YES];
    
    if (self.session) {
        
        [self.session stopRunning];
    }
}


// 初始化
-(void)initAVCaptureSession{
    
    //1.创建会话层
    self.session = [[AVCaptureSession alloc] init];
    //调整 PresetPhoto  AVCaptureSessionPreset640x480
     [self.session setSessionPreset:AVCaptureSessionPresetPhoto];
    
    //2.创建、配置输入设备
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if (device.position == AVCaptureDevicePositionBack)
        {
            _captureInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
        }
    }
    //NSError *error;
    if (!_captureInput)
    {
        return;
    }
    [_session addInput:_captureInput];
    
    NSError *error;
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
//    self.device = device;
    //更改这个设置的时候必须先锁定设备，修改完后再解锁，否则崩溃
    [device lockForConfiguration:nil];
    //设置闪光灯为自动
    [device setFlashMode:AVCaptureFlashModeAuto];
    [device unlockForConfiguration];
    // 后置摄像头标识
    self.isUsingFrontFacingCamera = NO;
    
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    if (error) {
        NSLog(@"%@",error);
    }
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    //输出设置。AVVideoCodecJPEG   输出jpeg格式图片
    NSDictionary * outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey, nil];
    [self.stillImageOutput setOutputSettings:outputSettings];
    
    if ([self.session canAddInput:self.videoInput]) {
        [self.session addInput:self.videoInput];
    }
    if ([self.session canAddOutput:self.stillImageOutput]) {
        [self.session addOutput:self.stillImageOutput];
    }
    
    //初始化预览图层
    self.preview.layer.masksToBounds = YES;
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession: _session];
    // 44 头部  97底部
    self.previewLayer.frame = CGRectMake(0,0, ScreenWidth, ScreenHeight- 97 - 44);
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    self.previewLayer.masksToBounds = YES;
    [self.preview.layer addSublayer:self.previewLayer];
    //对焦框
    [self addFocusView];
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        NSLog(@"设备不支持拍照功能");
    }

    
}



//- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation
//{
//    AVCaptureVideoOrientation result = (AVCaptureVideoOrientation)deviceOrientation;
//    if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
//        result = AVCaptureVideoOrientationLandscapeRight;
//    else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
//        result = AVCaptureVideoOrientationLandscapeLeft;
//    return result;
//}

// 隐藏电池栏
- (BOOL)prefersStatusBarHidden
{
    return YES;
    
}



#pragma mark 界面控制按钮
// 取消
- (IBAction)cancelClick {
    [self dismissViewControllerAnimated:YES completion:nil];
}
// 拍照
- (IBAction)takephotoClick:(UIButton *)sender {
    @autoreleasepool {
        
        //    判断是否有权限
        ALAuthorizationStatus author = [ALAssetsLibrary authorizationStatus];
        if (author == ALAuthorizationStatusRestricted || author == ALAuthorizationStatusDenied){
            NSLog(@"无权限保存至相册,请在设置中允许");
            return ;
        }
        //根据设备输出获得连接
        AVCaptureConnection *captureConnection=[_stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
        self.captureConnection  = captureConnection;
        //根据连接取得设备输出的数据
        [_stillImageOutput captureStillImageAsynchronouslyFromConnection:captureConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            
            if (imageDataSampleBuffer) {
                NSData *imageData=[AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                // 压缩图片
                
                // 保存到相册
//                [LJImageTool saveImageToAlbum:[UIImage imageWithData:imageData]];
                HWShowCameraPhotoViewController *showCameraPhotoVC = [[HWShowCameraPhotoViewController alloc]init];
                
                showCameraPhotoVC.cameraImage = [UIImage imageWithData:imageData];
                [self.navigationController pushViewController:showCameraPhotoVC animated:YES];
             
                
            }
        }];
    }
    
    
}

// 切换前后摄像头
- (IBAction)switchCarmeraClick:(UIButton *)sender {
    
    
    AVCaptureDevicePosition desiredPosition;
    if (self.isUsingFrontFacingCamera){
        desiredPosition = AVCaptureDevicePositionBack;
    }else{
        desiredPosition = AVCaptureDevicePositionFront;
    }
    
    for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if ([d position] == desiredPosition) {
            [self.previewLayer.session beginConfiguration];
            AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:d error:nil];
            for (AVCaptureInput *oldInput in self.previewLayer.session.inputs) {
                [[self.previewLayer session] removeInput:oldInput];
            }
            [self.previewLayer.session addInput:input];
            [self.previewLayer.session commitConfiguration];
            break;
        }
    }
    self.isUsingFrontFacingCamera = !self.isUsingFrontFacingCamera;
}

// 闪光灯状态
- (IBAction)flashClick:(UIButton *)sender {
    self.flashView.hidden = NO;
    
}


- (IBAction)flashViewAutoBtnClick:(UIButton *)sender {
    [self updateFlashBtnTitle:sender.titleLabel.text flashMode:AVCaptureFlashModeAuto];
}

- (IBAction)flashViewOpenBtnClick:(UIButton *)sender {
    [self updateFlashBtnTitle:sender.titleLabel.text flashMode:AVCaptureFlashModeOn];
}

- (IBAction)flashViewLightBtnClick:(UIButton *)sender {

    //   常亮
    [self.CaptureDevice lockForConfiguration:nil];
    [self.flashBtn setTitle:sender.titleLabel.text forState:UIControlStateNormal];
    self.flashView.hidden = YES;
    [self.CaptureDevice setTorchMode:AVCaptureTorchModeOn];
    [self.CaptureDevice unlockForConfiguration];

    //  [_device setTorchMode:AVCaptureTorchModeOff];

}

- (IBAction)flashViewCloseBtnClick:(UIButton *)sender {
   [self updateFlashBtnTitle:sender.titleLabel.text flashMode:AVCaptureFlashModeOff];
}

- (void)updateFlashBtnTitle:(NSString *)title flashMode:(AVCaptureFlashMode)flashMode
{
    [self.flashBtn setTitle:title forState:UIControlStateNormal];
    self.flashView.hidden = YES;
     //修改前必须先锁定
     [self.CaptureDevice lockForConfiguration:nil];
     //必须判定是否有闪光灯，否则如果没有闪光灯会崩溃
    if ([self.CaptureDevice hasFlash]) {
            self.CaptureDevice.flashMode = flashMode;
        // 关闭闪光灯
         [self.CaptureDevice setTorchMode:AVCaptureTorchModeOff];
     }
     [self.CaptureDevice unlockForConfiguration];
}





// 单张拍摄
- (IBAction)singerTakeBtnClick {
    
}
// 多张拍摄
- (IBAction)moreTakeBtnClick {
}





#pragma 创建手势
- (void)setUpGesture{
    
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    pinch.delegate = self;
    [self.preview addGestureRecognizer:pinch];
}

#pragma mark gestureRecognizer delegate
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ( [gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]] ) {
        self.beginGestureScale = self.effectiveScale;
    }
    return YES;
}
//缩放手势 用于调整焦距
- (void)handlePinchGesture:(UIPinchGestureRecognizer *)recognizer{
    
    BOOL allTouchesAreOnThePreviewLayer = YES;
    NSUInteger numTouches = [recognizer numberOfTouches], i;
    for ( i = 0; i < numTouches; ++i ) {
        CGPoint location = [recognizer locationOfTouch:i inView:self.preview];
        CGPoint convertedLocation = [self.previewLayer convertPoint:location fromLayer:self.previewLayer.superlayer];
        if ( ! [self.previewLayer containsPoint:convertedLocation] ) {
            allTouchesAreOnThePreviewLayer = NO;
            break;
        }
    }
    
    if ( allTouchesAreOnThePreviewLayer ) {
        
        
        self.effectiveScale = self.beginGestureScale * recognizer.scale;
        if (self.effectiveScale < MinEffectiveScale){
            self.effectiveScale = MinEffectiveScale;
        }
       
        CGFloat maxScaleAndCropFactor = [[self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo] videoMaxScaleAndCropFactor];
        
        NSLog(@"%f",maxScaleAndCropFactor);
        if (self.effectiveScale > MaxEffectiveScale){
            self.effectiveScale = MaxEffectiveScale;
            
        }
        
        [CATransaction begin];
        [CATransaction setAnimationDuration:.025];
        [self.previewLayer setAffineTransform:CGAffineTransformMakeScale(self.effectiveScale, self.effectiveScale)];
        [CATransaction commit];
        
    }
    
}


#pragma mark   @START 镜头伸缩，点击对焦
//对焦框
- (void)addFocusView {
    UIImageView *imgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"touch_focus_x.png"]];
    imgView.alpha = 0;
    [self.view addSubview:imgView];
    self.focusImageView = imgView;
}


// 拉近拉远镜头@param scale 拉伸倍数
- (void)pinchCameraViewWithScalNum:(CGFloat)scale {
    self.effectiveScale = scale;
    if (self.effectiveScale < MinEffectiveScale) {
        self.effectiveScale = MinEffectiveScale;
    } else if (self.effectiveScale > MaxEffectiveScale) {
        self.effectiveScale = MaxEffectiveScale;
    }
    [self doPinch];
    _preScaleNum = scale;
}
- (void)doPinch {
    CGFloat maxScale = self.captureConnection.videoMaxScaleAndCropFactor;//videoScaleAndCropFactor这个属性取值范围是1.0-videoMaxScaleAndCropFactor。iOS5+才可以用
    if (self.effectiveScale > maxScale) {
        self.effectiveScale = maxScale;
    }
    
    //    videoConnection.videoScaleAndCropFactor = _scaleNum;
    [CATransaction begin];
    [CATransaction setAnimationDuration:.025];
    [self.previewLayer setAffineTransform:CGAffineTransformMakeScale(self.effectiveScale, self.effectiveScale)];
    [CATransaction commit];
}
// -------------touch to focus---------------
#if SWITCH_SHOW_FOCUSVIEW_UNTIL_FOCUS_DONE
//监听对焦是否完成了
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:ADJUSTINT_FOCUS]) {
        BOOL isAdjustingFocus = [[change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:[NSNumber numberWithInt:1] ];
        if (!isAdjustingFocus) {
            alphaTimes = -1;
        }
    }
}
- (void)showFocusInPoint:(CGPoint)touchPoint {
    
    [UIView animateWithDuration:0.1f delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        
        int alphaNum = (alphaTimes % 2 == 0 ? HIGH_ALPHA : LOW_ALPHA);
        self.focusImageView.alpha = alphaNum;
        alphaTimes++;
        
    } completion:^(BOOL finished) {
        
        if (alphaTimes != -1) {
            [self showFocusInPoint:currTouchPoint];
        } else {
            self.focusImageView.alpha = 0.0f;
        }
    }];
}





#endif

static BOOL touchTag = YES;
static CGFloat startPointX;
// 点击屏幕
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint  currTouchPoint = [touch locationInView:self.view];
    startPointX = currTouchPoint.x;
    
    
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    
    
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint currTouchPoint = [touch locationInView:self.view];
    // 位置在头部44内不出发对焦 || 底部视图的高 97
    BOOL isInpoint = currTouchPoint.y < 44 || currTouchPoint.y > ScreenHeight - 97;
    if(isInpoint) return;
    CGFloat endPointX = currTouchPoint.x;

    // 判断偏移量，超过5 点击对焦功能取消
    BOOL leftSlide = startPointX  -  endPointX <-5;
    BOOL rightSlide = startPointX  -  endPointX >5;
    if (!(leftSlide||rightSlide) && touchTag == YES) {
        UITouch *touch = [touches anyObject];
        currTouchPoint = [touch locationInView:self.view];
        
        // 点击的位置是否包含在相机框内  -- 不精准
//        if (CGRectContainsPoint(_preview.bounds, currTouchPoint) == NO) {
//            return;
//        }
        
        [self focusInPoint:currTouchPoint];
        //添加 对焦框
        [self.focusImageView setCenter:currTouchPoint];
        self.focusImageView.transform = CGAffineTransformMakeScale(2.0, 2.0);
        
#if SWITCH_SHOW_FOCUSVIEW_UNTIL_FOCUS_DONE
        [UIView animateWithDuration:0.1f animations:^{
            _focusImageView.alpha = HIGH_ALPHA;
            _focusImageView.transform = CGAffineTransformMakeScale(1.0, 1.0);
        } completion:^(BOOL finished) {
            [self showFocusInPoint:currTouchPoint];
        }];
#else
        [UIView animateWithDuration:0.3f delay:0.f options:UIViewAnimationOptionAllowUserInteraction animations:^{
            _focusImageView.alpha = 1.f;
            _focusImageView.transform = CGAffineTransformMakeScale(1.0, 1.0);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.5f delay:0.5f options:UIViewAnimationOptionAllowUserInteraction animations:^{
                _focusImageView.alpha = 0.f;
            } completion:nil];
        }];
    }
#endif
}


//点击后对焦@param devicePoint 点击的point

- (void)focusInPoint:(CGPoint)devicePoint {
    devicePoint = [self convertToPointOfInterestFromViewCoordinates:devicePoint];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}
//外部的point转换为camera需要的point(外部point/相机页面的frame)@param viewCoordinates 外部的point@return 相对位置的point
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates {
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = _preview.bounds.size;
    
    AVCaptureVideoPreviewLayer *videoPreviewLayer = self.previewLayer;
    
    if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResize]) {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        for(AVCaptureInputPort *port in [[_session.inputs lastObject]ports]) {
            if([port mediaType] == AVMediaTypeVideo) {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;
                
                if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspect]) {
                    if(viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        if(point.x >= blackBar && point.x <= blackBar + x2) {
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        if(point.y >= blackBar && point.y <= blackBar + y2) {
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                } else if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                    if(viewRatio > apertureRatio) {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                        yc = (frameSize.width - point.x) / frameSize.width;
                    } else {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                        xc = point.y / frameSize.height;
                    }
                    
                }
                
                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }
    
    return pointOfInterest;
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange {
    
    _device = [_captureInput device];
    NSError *error = nil;
    if ([_device lockForConfiguration:&error])
    {
        if ([_device isFocusPointOfInterestSupported] && [_device isFocusModeSupported:focusMode])
        {
            [_device setFocusMode:focusMode];
            [_device setFocusPointOfInterest:point];
        }
        if ([_device isExposurePointOfInterestSupported] && [_device isExposureModeSupported:exposureMode])
        {
            [_device setExposureMode:exposureMode];
            [_device setExposurePointOfInterest:point];
        }
        [_device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
        //[_device unlockForConfiguration];
    }
    else
    {
        NSLog(@"%@", error);
    }
}



#pragma mark 打开照片库
/*
- (IBAction)AlbumClick {
    [self openImagePickerCon];
}


- (void)openImagePickerCon
{
    HMImagePickerController *picker = [[HMImagePickerController alloc] initWithSelectedAssets:self.selectedAssets];
    // 设置图像选择代理
    picker.pickerDelegate = self;
    // 设置目标图片尺寸
    picker.targetSize = CGSizeMake(600, 600);
    // 设置最大选择照片数量
    picker.maxPickerCount = 1;
    [self presentViewController:picker animated:YES completion:nil];
}



#pragma mark - HMImagePickerControllerDelegate
- (void)imagePickerController:(HMImagePickerController *)picker
      didFinishSelectedImages:(NSArray<UIImage *> *)images
               selectedAssets:(NSArray<PHAsset *> *)selectedAssets {
    
    // 记录图像，方便在 CollectionView 显示
    self.images = images;
    // 记录选中资源集合，方便再次选择照片定位
    self.selectedAssets = selectedAssets;
    NSLog(@"images  %@\n 已选照片  %@",self.images,self.selectedAssets);
    self.selectedAssets = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
    
    // 图片压缩
    UIImage *image1 = [self.images lastObject];
    NSLog(@"one  %ld",UIImageJPEGRepresentation(image1, 1.0).length);
    UIImage *image = [UIImage compressImage:image1 compressRatio:0.1f];
    NSLog(@"two  %ld",UIImageJPEGRepresentation(image, 1.0f).length);
}

*/


@end
