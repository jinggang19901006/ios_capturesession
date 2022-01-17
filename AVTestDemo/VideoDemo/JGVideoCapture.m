//
//  JGVideoCapture.m
//  VideoDemo
//
//  Created by tony.jing on 2022/1/14.
//

#import "JGVideoCapture.h"
#import <UIKit/UIKit.h>

@implementation JGVideoCaptureParam

- (instancetype)init {
    self = [super init];
    if (self) {
        _devicePosition = AVCaptureDevicePositionFront;
        _sessionPreset = AVCaptureSessionPreset1280x720;
        _frameRate = 15;
        _videoOrientation = AVCaptureVideoOrientationPortrait;
        
        switch ([UIDevice currentDevice].orientation) {
            case UIDeviceOrientationPortrait:
            case UIDeviceOrientationPortraitUpsideDown:
                _videoOrientation = AVCaptureVideoOrientationPortrait;
                break;
                
            case UIDeviceOrientationLandscapeRight:
                _videoOrientation = AVCaptureVideoOrientationLandscapeRight;
                break;
                
            case UIDeviceOrientationLandscapeLeft:
                _videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
                break;
                
            default:
                break;
        }
    }
    return self;
}
@end


@interface JGVideoCapture()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;
//视频
@property (nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *captureVideoDataOutput;
@property (nonatomic, strong) AVCaptureConnection *captureConnection;

//音频
@property (nonatomic, strong) AVCaptureDeviceInput *audioDeviceInput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *captureAudioDataOutput;
@property (nonatomic, strong) AVCaptureConnection *audioConnection;

/**  预览图层,把这个图层加在view上并且为这个图层设置frame就能播放  **/
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, assign) BOOL isCapturing;

@end

@implementation JGVideoCapture

-(instancetype)initWithCaptureParam:(JGVideoCaptureParam *)captureParam error:(NSError *)error {
    if (self = [super init]) {
        NSError *errorMessage = nil;
        self.videoCaptureParam = captureParam;
        
        //获取支持的设备列表
        NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        //获取当前方向的摄像头
        NSArray *captureDeviceArray = [cameras filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"position == %d",captureParam.devicePosition]];
        
        if (captureDeviceArray.count == 0) {
            errorMessage = [self p_errorWithDomain:@"JGVideoCapture:: Get Camera Faild!"];
            return nil;
        }
        //设置输入设备
        AVCaptureDevice *camera = captureDeviceArray.firstObject;
        self.captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:camera error:&errorMessage];
        if (errorMessage) {
            errorMessage = [self p_errorWithDomain:@"JGVideoCapture:: Init AVCaptureDeviceInput Faild!"];
        }
        
        //设置输出设备
        self.captureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        
        //设置视频输出格式
        NSDictionary *videoSetting = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey, nil];
        [self.captureVideoDataOutput setVideoSettings:videoSetting];
        //设置输出串行队列和数据回调 设置代理
        dispatch_queue_t outputQueue = dispatch_queue_create("JGVideoCaptureDataOutput", DISPATCH_QUEUE_SERIAL);
        [self.captureVideoDataOutput setSampleBufferDelegate:self queue:outputQueue];
        self.captureVideoDataOutput.alwaysDiscardsLateVideoFrames = YES;
        
        //音频输入输出
        if (self.audioDeviceInput == nil) {
            AVCaptureDevice *micDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] lastObject];
            NSError *error;
            self.audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:micDevice error:&error];
        }
        
        if (self.captureAudioDataOutput == nil) {
            self.captureAudioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
            [self.captureAudioDataOutput setSampleBufferDelegate:self queue:outputQueue];
        }
        
        //初始化会话
        self.captureSession = [[AVCaptureSession alloc] init];
        self.captureSession.usesApplicationAudioSession = NO;
        
        //添加输入设备到会话
        if ([self.captureSession canAddInput:self.captureDeviceInput]) {
            [self.captureSession addInput:self.captureDeviceInput];
        }else {
            [self p_errorWithDomain:@"JGVideoCapture:: Add captureVideoDataInput Faild!"];
            NSLog(@"JGVideoCapture:: Add captureVideoDataInput Faild!");
            return nil;
        }
        //添加输出设备到会话
        if ([self.captureSession canAddOutput:self.captureVideoDataOutput]) {
            [self.captureSession addOutput:self.captureVideoDataOutput];
        }else {
            [self p_errorWithDomain:@"JGVideoCapture:: Add captureVideoDataOutput Faild!"];
            return nil;
        }
        
        //添加音频输入输出设备到会话
        if ([self.captureSession canAddInput:self.audioDeviceInput]) {
            [self.captureSession addInput:self.audioDeviceInput];
        }
        if ([self.captureSession canAddOutput:self.captureAudioDataOutput]) {
            [self.captureSession addOutput:self.captureAudioDataOutput];
        }
        
        //设置分辨率
        if ([self.captureSession canSetSessionPreset:self.captureSession.sessionPreset]) {
            [self.captureSession setSessionPreset:self.captureSession.sessionPreset];
        }
        
        //初始化连接
        self.captureConnection = [self.captureVideoDataOutput connectionWithMediaType:AVMediaTypeVideo];
        self.audioConnection = [self.captureVideoDataOutput connectionWithMediaType:AVMediaTypeAudio];
        self.captureConnection.videoOrientation = self.videoCaptureParam.videoOrientation;

        // ---  设置帧率  ---
        [self adjustFrameRate:self.videoCaptureParam.frameRate];
        
        self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        self.previewLayer.connection.videoOrientation = self.videoCaptureParam.videoOrientation;
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    return self;
}

- (NSError *)startCpture {
    if (self.isCapturing) {
        return [self p_errorWithDomain:@"VideoCapture:: startCapture faild: is capturing"];
    }
        
    // ---  摄像头权限判断  ---
    AVAuthorizationStatus videoAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    
    if (videoAuthStatus != AVAuthorizationStatusAuthorized) {
        return [self p_errorWithDomain:@"VideoCapture:: Camera Authorizate faild!"];
    }
    
    [self.captureSession startRunning];
    self.isCapturing = YES;
    
    NSLog(@"开始采集视频");
    
    return nil;
}

- (NSError *)stopCapture {
    if (!self.isCapturing) {
        return [self p_errorWithDomain:@"VideoCapture:: stop capture faild! is not capturing!"];
    }
    
    [self.captureSession stopRunning];
    self.isCapturing = NO;
    
    NSLog(@"停止采集视频");
    
    return nil;
}

- (NSError *)adjustFrameRate:(NSInteger)frameRate {
    NSError *error = nil;
    AVFrameRateRange *frameRateRange = [self.captureDeviceInput.device.activeFormat.videoSupportedFrameRateRanges objectAtIndex:0];
    
    NSLog(@"帧率设置范围: min: %f ,  max: %f", frameRateRange.minFrameRate, frameRateRange.maxFrameRate);
    
    if (frameRate > frameRateRange.maxFrameRate || frameRate < frameRateRange.minFrameRate) {
        return [self p_errorWithDomain:@"VideoCapture:: Set FrameRate faild! out of rang"];
    }
    
    [self.captureDeviceInput.device lockForConfiguration:&error];
    self.captureDeviceInput.device.activeVideoMinFrameDuration = CMTimeMake(1, (int)self.videoCaptureParam.frameRate);
    self.captureDeviceInput.device.activeVideoMaxFrameDuration = CMTimeMake(1, (int)self.videoCaptureParam.frameRate);
    [self.captureDeviceInput.device unlockForConfiguration];
    
    return error;
}

- (NSError *)reverseCamera {
    // ---  获取所有摄像头  ---
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    // ---  获取当前摄像头方向  ---
    AVCaptureDevicePosition currentPosition = self.captureDeviceInput.device.position;
    AVCaptureDevicePosition toPosition = AVCaptureDevicePositionUnspecified;
    
    if (currentPosition == AVCaptureDevicePositionBack || currentPosition == AVCaptureDevicePositionUnspecified) {
        toPosition = AVCaptureDevicePositionFront;
    } else {
        toPosition = AVCaptureDevicePositionBack;
    }
    
    NSArray *captureDeviceArr = [cameras filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"position == %d", toPosition]];
    
    if (captureDeviceArr.count == 0) {
        return [self p_errorWithDomain:@"VideoCapture:: reverseCamera faild! get new camera faild!"];
    }
    
    NSError *error = nil;
    
    // ---  添加翻转动画  ---
    CATransition *animation = [CATransition animation];
    animation.duration = 1.0;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.type = @"oglFlip";
    
    AVCaptureDevice *camera = captureDeviceArr.firstObject;
    AVCaptureDeviceInput *newInput = [AVCaptureDeviceInput deviceInputWithDevice:camera
                                                                           error:&error];
    
    animation.subtype = kCATransitionFromRight;
    [self.previewLayer addAnimation:animation forKey:nil];
    
    
    // ---  修改输入设备  ---
    [self.captureSession beginConfiguration];
    [self.captureSession removeInput:self.captureDeviceInput];
    if ([self.captureSession canAddInput:newInput]) {
        [self.captureSession addInput:newInput];
        self.captureDeviceInput = newInput;
    }
    
    [self.captureSession commitConfiguration];
    
    
    // ---  重新获取连接并设置方向  ---
    self.captureConnection = [self.captureVideoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    // ---  设置摄像头镜像，不设置的话前置摄像头采集出来的图像是反转的  ---
    if (toPosition == AVCaptureDevicePositionFront && self.captureConnection.supportsVideoMirroring) {
        self.captureConnection.videoMirrored = YES;
    }
    
    self.captureConnection.videoOrientation = self.videoCaptureParam.videoOrientation;
    
    return nil;
}

- (void)changeSessionPreset:(AVCaptureSessionPreset)sessionPreset {
    if (self.videoCaptureParam.sessionPreset == sessionPreset) {
        return;
    }
    
    
    self.videoCaptureParam.sessionPreset = sessionPreset;
    if ([self.captureSession canSetSessionPreset:self.videoCaptureParam.sessionPreset]) {
        [self.captureSession setSessionPreset:self.videoCaptureParam.sessionPreset];
        NSLog(@"分辨率切换成功");
    }
}

#pragma mark ————— AVCaptureVideoDataOutputSampleBufferDelegate —————

/**
 * 摄像头采集数据回调
 @prama output       输出设备
 @prama sampleBuffer 帧缓存数据，描述当前帧信息
 @prama connection   连接
 */
- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    if (output == self.captureVideoDataOutput) {
        if ([self.delegate respondsToSelector:@selector(videoCaptureOutputDataCallback:)]) {
            [self.delegate videoCaptureOutputDataCallback:sampleBuffer];
        }
    }
    if (output == self.captureAudioDataOutput) {
        if ([self.delegate respondsToSelector:@selector(videoCaptureOutputDataCallback:)]) {
            [self.delegate audioCaptureOutputDataCallback:sampleBuffer];
        }
    }
    
}

#pragma mark --private
- (NSError *)p_errorWithDomain:(NSString *)domain {
    NSLog(@"%@", domain);
    return [NSError errorWithDomain:domain code:1 userInfo:nil];
}

@end
