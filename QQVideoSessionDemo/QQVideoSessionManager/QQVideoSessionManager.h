//
//  QQVideoSessionManager.h
//  QQVideoSessionDemo
//
//  Created by QuinnQiu on 16/1/11.
//  Copyright © 2016年 QuinnQiu. All rights reserved.
//


/*
 1.default back camera;
 
 2.only video;
 
 3.YUV type;
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>


@protocol QQVideoSessionManagerDelegate;

@interface QQVideoSessionManager : NSObject {
    
}
//delegate
@property (nonatomic, assign) id<QQVideoSessionManagerDelegate> delegate;

//Configuration

/**
 *  Get resolution array of the current camera
 *
 *  @return NSMutableArray
 */
- (NSMutableArray *) getCurrentCameraResolutionArray;

/**
 *  Determine whether the current camera front camera
 *
 *  @return YES/NO
 */
- (BOOL) determineTheCurrentCameraIsFront;

/**
 *  Set the front camera;
 *
 *  @return YES/NO
 */
- (BOOL) setFrontCamera;

/**
 *  Set the back camera;
 *
 *  @return YES/NO
 */
- (BOOL) setBackCamera;

/**
 *  Set capture resolution parameter;
 *
 *  @param width  Resolution width;
 *  @param height Resolution height;
 */
- (void) setPrepareVideoCaptureResolution: (int)width andHeight: (int)height;

/**
 *  Set the preview
 *
 *  @param preview  preview
 *  @param frame    frame
 */
- (void) setPreview: (UIView *)preview withFrame: (CGRect)frame;

/**
 *  start capture
 */
- (void) startVideoCapture;

/**
 *  stop capture
 */
- (void) stopVideoCapture;

//Other features
/**
 *  Get the video stream for each frame image
 *
 *  @return UIImage
 */
- (void) getCurrentFramePicture:(void (^)(UIImage *image, char *imageBuffer, int bufferLength))success;

@end

/**
 *  video stream data delegate
 */
@protocol QQVideoSessionManagerDelegate <NSObject>

- (void)videoDataOutputBuffer: (char *)videoBuffer dataSize: (int)size;

@end

