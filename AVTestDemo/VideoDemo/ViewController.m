//
//  ViewController.m
//  VideoDemo
//
//  Created by tony.jing on 2022/1/14.
//

#import "ViewController.h"
#import "JGVideoCapture.h"
#import <GLKit/GLKit.h>

@interface ViewController ()<JGVideoCaptureDelegate>
@property (nonatomic, strong)JGVideoCapture *capture;
/**  播放视图  **/
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    JGVideoCaptureParam *param = [JGVideoCaptureParam new];
    
    self.capture = [[JGVideoCapture alloc] initWithCaptureParam:param error:nil];
    self.capture.delegate = self;
    
    UIButton *startBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    startBtn.frame = CGRectMake(50, 200, 120, 30);
    [startBtn setTitle:@"开始采集" forState:UIControlStateNormal];
    [startBtn setTintColor:[UIColor redColor]];
    [startBtn addTarget:self action:@selector(startVideoCapture) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:startBtn];
    
    UIButton *stopBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    stopBtn.frame = CGRectMake(50, 300, 120, 30);
    [stopBtn setTitle:@"停止采集" forState:UIControlStateNormal];
    [stopBtn setTintColor:[UIColor redColor]];
    [stopBtn addTarget:self action:@selector(stopVideoCapture) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:stopBtn];
    
    self.previewLayer = self.capture.previewLayer;
    self.previewLayer.frame = self.view.frame;
    [self.view.layer addSublayer:self.previewLayer];
}

- (void) startVideoCapture {
    [self.capture startCpture];
    
}

- (void) stopVideoCapture {
    [self.capture stopCapture];
    
}


- (void)videoCaptureOutputDataCallback:(CMSampleBufferRef)sampleBuffer {
    NSLog(@"video sampleBuffer = %@",sampleBuffer);
    
}

- (void)audioCaptureOutputDataCallback:(CMSampleBufferRef)sampleBuffer {
    NSLog(@"audio sampleBuffer = %@",sampleBuffer);
}
@end
