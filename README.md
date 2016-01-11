# QQVideoCapture
手机视频采集、yuv数据实时转换为UIImage、视频流实时转换为char*类型方便推流到平台服务器

基于32BGRA格式简单易于处理，这儿只处理YUV420f格式的视频流，由于YUV格式有效减少传送负荷，实际视频直播中h264的编解码主用YUV流。

QQVideoSessionManager类里面有处理YUV转换为char*数据，以及将YUV视频流实时转换为UIImage的代码。

1、将类QQVideoSessionManager源文件加入项目；

2、#import "QQVideoSessionManager.h"导入文件；

3、  /* init class */
    self->mVideoSession = [[QQVideoSessionManager alloc] init];

    /* set delegate */
    self->mVideoSession.delegate = self;

    /* set preview */
    [self->mVideoSession setPreview:self.preview withFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];

    /* start capture */
    [self->mVideoSession startVideoCapture];

    即可在delegate中处理视频流数据
    #pragma mark - delegate
- (void)videoDataOutputBuffer:(char *)videoBuffer dataSize:(int)size {
    //here you could get stream datas;
}

4、相关参数可修改设置；
