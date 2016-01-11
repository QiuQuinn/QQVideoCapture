//
//  QQVideoSessionManager.m
//  QQVideoSessionDemo
//
//  Created by QuinnQiu on 16/1/11.
//  Copyright © 2016年 QuinnQiu. All rights reserved.
//

#import "QQVideoSessionManager.h"
#define QQ_RESOLUTION_ARRAY [NSMutableArray arrayWithObjects:/*@"3840*2160",*/ @"1920*1080", @"1280*720", /*@"960*540", */@"640*480", @"352*288", /*@"320x240",*/ nil]


@interface QQVideoSessionManager () <AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>{
    int mWidth;
    int mHeight;
    int mFps;
    BOOL mFrontCamera;
    BOOL mStarted;
    CGRect mPreviewFrame;
    UIView *mPreview;
    
    NSDictionary *mOptions;
    CIContext *mContext;
    
    AVCaptureSession *mCaptureSession;//IOStream bridge
    AVCaptureDevice *mVideoDevice;//camera
    AVCaptureDevice *mAudioDevice;//microphone
    
//    AVCaptureConnection *mVideoConnection;//video
//    AVCaptureConnection *mAudioConnection;//audio
    
    /* picture */
    BOOL mGetPicture;
    UIImage *mCurrentImage;
}

@end

@implementation QQVideoSessionManager

#pragma mark - init
#pragma mark init
- (instancetype) init {
    self = [super init];
    if (self) {

        self->mWidth        = 640;
        self->mHeight       = 480;
        self->mFps          = 30;
        self->mFrontCamera  = NO;
        self->mStarted      = NO;
        self->mGetPicture   = NO;
        self->mCurrentImage = nil;

        self->mOptions      = @{ kCIContextWorkingColorSpace : [NSNull null], kCIContextOutputColorSpace : [NSNull null] };
        self->mContext      = [CIContext contextWithEAGLContext:[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2] options:self->mOptions];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:[UIApplication sharedApplication]];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:[UIApplication sharedApplication]];
    }
    return self;
}

#pragma mark dealloc
- (void) dealloc {
    if ([self->mCaptureSession isRunning]) {
        [self stopVideoCapture];
    }
    self->mCaptureSession = nil;
    self->mOptions        = nil;
    self->mContext        = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];

}

#pragma mark - notification
#pragma mark Enter background
- (void)applicationDidEnterBackground{
    [self stopVideoCapture];
}

#pragma mark enter foreground
- (void)applicationWillEnterForeground{
    [self startVideoCapture];
}

#pragma mark get resolution array of the current camera
- (NSMutableArray *) getCurrentCameraResolutionArray {
    NSMutableArray *resoluArray = nil;
    if (self->mCaptureSession) {
        NSMutableArray *array = [[NSMutableArray alloc] initWithObjects:AVCaptureSessionPreset1920x1080, AVCaptureSessionPreset1280x720, AVCaptureSessionPreset640x480, AVCaptureSessionPreset352x288, nil];
        resoluArray = [[NSMutableArray alloc] initWithCapacity:1];
        
        for (int i = 0; i < array.count; i++) {
            if ([self->mCaptureSession canSetSessionPreset:[array objectAtIndex:i]]) {
                [resoluArray addObject:[QQ_RESOLUTION_ARRAY objectAtIndex:i]];
            }
        }
        
    } else {
        resoluArray = [[NSMutableArray alloc] initWithObjects:AVCaptureSessionPreset640x480, nil];
    }
    
    return resoluArray;
}

#pragma mark determint whether the current camera front camera
- (BOOL) determineTheCurrentCameraIsFront {
    return mFrontCamera;
}

#pragma mark set the front camera
- (BOOL) setFrontCamera {
    if (self->mFrontCamera) {
        return YES;
    }
    
    [self stopVideoCapture];
    self->mFrontCamera = YES;
    [self startVideoCapture];
    return YES;
}

#pragma mark set the back camera
- (BOOL) setBackCamera {
    if (!self->mFrontCamera) {
        return YES;
    }
    
    [self stopVideoCapture];
    mFrontCamera = NO;
    [self startVideoCapture];
    return YES;
}

#pragma mark set capture resolution
- (void) setPrepareVideoCaptureResolution: (int)width andHeight: (int)height {
    self->mWidth  = width;
    self->mHeight = height;
    /*If you are running must be stopped*/
    if ([self->mCaptureSession isRunning]) {
        [self stopVideoCapture];
        [self startVideoCapture];
    } else {
        [self startVideoCapture];
    }
    mStarted = NO;
}

#pragma mark set the preview
- (void) setPreview: (UIView *)preview withFrame: (CGRect)frame {
    self->mPreview      = preview;
    self->mPreviewFrame = frame;
}

#pragma mark - 
#pragma mark start capture
- (void) startVideoCapture {
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];/*Open anti-lock*/
    /*if open , set nil;*/
    if (self->mVideoDevice || self->mCaptureSession) {
        self->mVideoDevice    = nil;
        self->mCaptureSession = nil;
    }
    
    if ((self->mVideoDevice = [self getAVCaptureDeviceCamera]) == nil) {
        /*If the open fails, the return;*/
        return;
    }
    /*set frame rate*/
    NSError *error = nil;
    if ([self->mVideoDevice lockForConfiguration:&error]) {
        [self->mVideoDevice setActiveVideoMaxFrameDuration:CMTimeMake(1, self->mFps)];
        [self->mVideoDevice setActiveVideoMinFrameDuration:CMTimeMake(1, self->mFps)];
        [self->mVideoDevice unlockForConfiguration];
    } else {
        NSLog(@"videoDevice lockForConfiguration returned error %@", error);
    }
    /*init device input*/
    error = nil;
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:self->mVideoDevice error:&error];
    if (!videoInput) {
        self->mVideoDevice = nil;
        return;
    }
    /*init capture session*/
    self->mCaptureSession = [[AVCaptureSession alloc] init];
    [self->mCaptureSession addInput:videoInput];
    /*set resolution*/
    NSString *captureQuality = [NSString stringWithString:[self getCaptureQuality]];
    /*begin configuration for the AVCaptureSession*/
    [self->mCaptureSession beginConfiguration];
    /*quality*/
    [self->mCaptureSession setSessionPreset:captureQuality];
    
    /* Currently, the only supported key is kCVPixelBufferPixelFormatTypeKey. Recommended pixel format choices are
       kCVPixelFormatType_420YpCbCr8BiPlanarFullRange(420f:YUV type) or kCVPixelFormatType_32BGRA(32 byte BGRA)...
       On iPhone 3G, the recommended pixel format choices are kCVPixelFormatType_422YpCbCr8 or kCVPixelFormatType_32BGRA.
     */
    AVCaptureVideoDataOutput *avCaptureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    NSString *key = (NSString *)kCVPixelBufferPixelFormatTypeKey;//only supported key;
    NSNumber *val = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];//h264 used YUV;
    NSDictionary *settings = [NSDictionary dictionaryWithObject:val forKey:key];
    avCaptureVideoDataOutput.videoSettings = settings;
    
    /*we create a serial queue to handle the processing of our frames*/
    dispatch_queue_t queue = dispatch_queue_create("com.QuinnQiu.class.video", NULL);
    [avCaptureVideoDataOutput setSampleBufferDelegate:self queue:queue];
    
    /* default orientation portrait*/
    [[avCaptureVideoDataOutput connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:AVCaptureVideoOrientationPortrait];
    [self->mCaptureSession addOutput:avCaptureVideoDataOutput];
    /* preview */
    AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self->mCaptureSession];
    previewLayer.frame = self->mPreviewFrame;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self->mPreview.layer addSublayer:previewLayer];
    
    /* start */
    self->mStarted = YES;
    /* commit configuration */
    [self->mCaptureSession commitConfiguration];
    [self->mCaptureSession startRunning];
}

#pragma mark stop capture
- (void) stopVideoCapture {
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    
    if ([self->mCaptureSession isRunning]) {
        [self->mCaptureSession stopRunning];
    }
    self->mCaptureSession = nil;
    self->mVideoDevice    = nil;
    
    /* remove subviews */
    for (UIView *view in self->mPreview.subviews) {
        [view removeFromSuperview];
    }
    self->mStarted = NO;
    
}
#pragma mark Get the camera device
- (AVCaptureDevice *)getAVCaptureDeviceCamera{
    return [self cameraAtPosition:mFrontCamera ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack];
}

#pragma mark - get the current camera device
- (AVCaptureDevice *)cameraAtPosition:(AVCaptureDevicePosition)position{
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];//set type with AVMediaTypeVideo
    for (AVCaptureDevice *device in cameras){
        if (device.position == position){
            return device;
        }
    }
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}

#pragma get capture resulotion string
-(NSString *) getCaptureQuality{
    NSString *captureQuality = AVCaptureSessionPreset640x480;
    switch (self->mWidth) {
        case 352:
            captureQuality = AVCaptureSessionPreset352x288;
            break;
        case 640:
            captureQuality = AVCaptureSessionPreset640x480;
            break;
        case 960:
            captureQuality = AVCaptureSessionPresetiFrame960x540;
            break;
        case 1280:
            captureQuality = AVCaptureSessionPreset1280x720;
            break;
        case 1920:
            captureQuality = AVCaptureSessionPreset1920x1080;
            break;
        case 3840:
            captureQuality = AVCaptureSessionPreset3840x2160;
            break;
        default:
            break;
    }
    return captureQuality;
}

#pragma mark get stream each frame image
- (void) getCurrentFramePicture:(void (^)(UIImage *image, char *imageBuffer, int bufferLength))success {
    self->mGetPicture = YES;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (self->mCurrentImage == nil) {
            usleep(10000);
        }
        
        NSData *data = UIImageJPEGRepresentation(self->mCurrentImage, 0.5);
        char *imageBuffer = (char *)[data bytes];
        dispatch_async(dispatch_get_main_queue(), ^{
            success(self->mCurrentImage, imageBuffer, (int)data.length);
            self->mCurrentImage = nil;
        });
        
    });
}

#pragma mark - capture sample buffer delegate
#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate
- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    /* Here only handles video stream, audio stream based on connection to distinguish */
    /* Since 32BGRA very simple, here only deal with YUV format */
    const int kFlags = 0;
    CVImageBufferRef videoFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    if (CVPixelBufferLockBaseAddress(videoFrame, kFlags) != kCVReturnSuccess) {
        return;
    }
    
    const int kYPlaneIndex    = 0;
    const int kUVPlaneIndex   = 1;

    uint8_t *baseAddress      = (uint8_t*)CVPixelBufferGetBaseAddressOfPlane(videoFrame, kYPlaneIndex);
    size_t yPlaneBytesPerRow  = CVPixelBufferGetBytesPerRowOfPlane(videoFrame, kYPlaneIndex);
    size_t yPlaneHeight       = CVPixelBufferGetHeightOfPlane(videoFrame, kYPlaneIndex);
    size_t uvPlaneBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(videoFrame, kUVPlaneIndex);
    size_t uvPlaneHeight      = CVPixelBufferGetHeightOfPlane(videoFrame, kUVPlaneIndex);
    size_t frameSize          = yPlaneBytesPerRow * yPlaneHeight + uvPlaneBytesPerRow * uvPlaneHeight;
    
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(videoDataOutputBuffer:dataSize:)]) {
        /* delegate call back data to you */
        [self.delegate videoDataOutputBuffer:(char *)baseAddress dataSize:(int)frameSize];
    }
    
    CVPixelBufferUnlockBaseAddress(videoFrame, kFlags);
    
    /* get picture */
    if (self->mGetPicture) {
        self->mGetPicture   = NO;
        UIImage *image      = [self getCurrentImageWith:sampleBuffer];
        self->mCurrentImage = [self fixOrientation:image];
    }
}

#pragma mark get iamge with CMSampleBufferRef
- (UIImage *) getCurrentImageWith: (CMSampleBufferRef)sampleBuffer {
    
    CVPixelBufferRef buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *ciImage        = [CIImage imageWithCVPixelBuffer:buffer];

    CGImageRef cgImage      = [mContext createCGImage:ciImage fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer))];

    UIImage *image          = [UIImage imageWithCGImage:cgImage];
    
    CGImageRelease(cgImage);
    return image;
}

#pragma mark rotate picture
- (UIImage *)fixOrientation:(UIImage *)image {
    long double rotate = 0.0;
    CGRect rect;
    float translateX = 0;
    float translateY = 0;
    float scaleX     = 1.0;
    float scaleY     = 1.0;
    
    CGSize newSize;
    
    if (image.size.width < image.size.height) {
        newSize.width  = image.size.width;
        newSize.height = image.size.width / 4 * 3;//this attention;4:3
    }else{
        newSize = image.size;
    }
    /* current device orientation */
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    if (self->mFrontCamera) {
        switch (deviceOrientation) {
            case UIDeviceOrientationLandscapeRight:
                rotate     = 0;
                rect       = CGRectMake(0, 0, newSize.width, newSize.height);
                translateX = 0;
                translateY = 0;
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                rotate     = M_PI_2;
                rect       = CGRectMake(0, 0, newSize.width, newSize.height);
                translateX = 0;
                translateY = -rect.size.width;
                scaleY     = rect.size.width/rect.size.height;
                scaleX     = rect.size.height/rect.size.width;
                break;
            case UIDeviceOrientationLandscapeLeft:
                rotate     = M_PI;
                rect       = CGRectMake(0, 0, newSize.width, newSize.height);
                translateX = -rect.size.width;
                translateY = -rect.size.height;
                break;
            default:
                rotate     = -M_PI_2;
                rect       = CGRectMake(0, 0, newSize.width, newSize.height);
                translateX = -rect.size.height;
                translateY = 0;
                scaleY     = rect.size.width/rect.size.height;
                scaleX     = rect.size.height/rect.size.width;
                break;
        }
    }else{
        switch (deviceOrientation) {
            case UIDeviceOrientationLandscapeRight:
                rotate     = M_PI;
                rect       = CGRectMake(0, 0, newSize.width, newSize.height);
                translateX = -rect.size.width;
                translateY = -rect.size.height;
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                rotate     = M_PI_2;
                rect       = CGRectMake(0, 0, newSize.width, newSize.height);
                translateX = 0;
                translateY = -rect.size.width;
                scaleY     = rect.size.width/rect.size.height;
                scaleX     = rect.size.height/rect.size.width;
                break;
            case UIDeviceOrientationLandscapeLeft:
                rotate     = 0;
                rect       = CGRectMake(0, 0, newSize.width, newSize.height);
                translateX = 0;
                translateY = 0;
                break;
            default:
                rotate     = -M_PI_2;
                rect       = CGRectMake(0, 0, newSize.width, newSize.height);
                translateX = -rect.size.height;
                translateY = 0;
                scaleY     = rect.size.width/rect.size.height;
                scaleX     = rect.size.height/rect.size.width;
                break;
        }
    }
    
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    /* Do CTM conversion */
    CGContextTranslateCTM(context, 0.0, rect.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextRotateCTM(context, rotate);
    CGContextTranslateCTM(context, translateX, translateY);
    
    CGContextScaleCTM(context, scaleX, scaleY);
    /* draw image */
    CGContextDrawImage(context, CGRectMake(0, 0, rect.size.width, rect.size.height), image.CGImage);
    
    UIImage *newPic = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newPic;
}

@end
