//
//  ViewController.m
//  QQVideoSessionDemo
//
//  Created by QuinnQiu on 16/1/11.
//  Copyright © 2016年 QuinnQiu. All rights reserved.
//

#import "ViewController.h"
#import "QQVideoSessionManager.h"

@interface ViewController () <QQVideoSessionManagerDelegate>{
    QQVideoSessionManager *mVideoSession;
    NSTimer *timer;
    UIImageView *testStreamImageView;
}
@property (weak, nonatomic) IBOutlet UIView *preview;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    /* init class */
    self->mVideoSession = [[QQVideoSessionManager alloc] init];
    /* set delegate */
    self->mVideoSession.delegate = self;
    /* set preview */
    [self->mVideoSession setPreview:self.preview withFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
    /* start capture */
    [self->mVideoSession startVideoCapture];
    
    self->testStreamImageView = [[UIImageView alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width - 160, [UIScreen mainScreen].bounds.size.height - 120, 160, 120)];
    [self.view addSubview:self->testStreamImageView];
    self->timer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(refreshImageview:) userInfo:nil repeats:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)lightBtn:(UIButton *)sender {
    
    sender.selected = !sender.selected;
    [self turnTorchOn:sender.selected];
    
}

- (IBAction)cameraChangeBtn:(UIButton *)sender {
    
    if ([self->mVideoSession determineTheCurrentCameraIsFront]) {
        [self->mVideoSession setBackCamera];
    }else{
        [self->mVideoSession setFrontCamera];
    }
}

#pragma mark 开关闪光灯
- (void)turnTorchOn:(bool)on {
    
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (captureDeviceClass != nil) {
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        if ([device hasTorch] && [device hasFlash]){
            
            [device lockForConfiguration:nil];
            if (on) {
                [device setTorchMode:AVCaptureTorchModeOn];
                [device setFlashMode:AVCaptureFlashModeOn];
            } else {
                [device setTorchMode:AVCaptureTorchModeOff];
                [device setFlashMode:AVCaptureFlashModeOff];
            }
            [device unlockForConfiguration];
        }
    }
}

- (void) refreshImageview: (NSTimer *)timer {
    [self->mVideoSession getCurrentFramePicture:^(UIImage *image, char *imageBuffer, int bufferLength) {
        self->testStreamImageView.image = image;
        NSLog(@"imagBuffer = %s", imageBuffer);
        NSLog(@"bufferLength = %d", bufferLength);
    }];
}

#pragma mark - delegate
- (void)videoDataOutputBuffer:(char *)videoBuffer dataSize:(int)size {
    //here you could get stream datas;
}

- (void) dealloc {
    [timer invalidate];
    timer = nil;
    self->mVideoSession = nil;
}
@end
