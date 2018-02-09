//
//  RKVideoCapture.m
//  LFLiveKit
//
//  Created by Ken Sun on 2018/1/11.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "RKVideoCapture.h"
#import "RKVideoCamera.h"
#import "QBGLContext.h"
#import "QBGLFilterTypes.h"

@interface RKVideoCapture () <RKVideoCameraDelegate>

@property (strong, nonatomic) LFLiveVideoConfiguration *configuration;

@property (strong, nonatomic) RKVideoCamera *videoCamera;
@property (strong, nonatomic) QBGLContext *glContext;
//@property (strong, nonatomic) GLKView *glkView;
@property (nonatomic) UIInterfaceOrientation displayOrientation;

@end

@implementation RKVideoCapture
@synthesize delegate = _delegate;
@synthesize running = _running;
@synthesize torch = _torch;
@synthesize mirror = _mirror;
@synthesize zoomScale = _zoomScale;
@synthesize warterMarkView = _warterMarkView;
@synthesize saveLocalVideo = _saveLocalVideo;
@synthesize saveLocalVideoPath = _saveLocalVideoPath;
@synthesize mirrorOutput = _mirrorOutput;
@synthesize displayOrientation = _displayOrientation;

- (instancetype)initWithVideoConfiguration:(LFLiveVideoConfiguration *)configuration {
    return [self initWithVideoConfiguration:configuration eaglContext:nil];
}

- (nullable instancetype)initWithVideoConfiguration:(nullable LFLiveVideoConfiguration *)configuration
                                        eaglContext:(nullable EAGLContext *)glContext {
    if (self = [super init]) {
        _configuration = configuration;
        _eaglContext = glContext;
        _displayOrientation = [[UIApplication sharedApplication] statusBarOrientation];
        self.beautyFace = YES;
        self.zoomScale = 1.0;
        self.mirror = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarChanged:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.videoCamera stopCapture];
}

- (void)previousColorFilter {
    self.glContext.colorFilterType = [QBGLFilterTypes previousFilterForType:self.glContext.colorFilterType];
}

- (void)nextColorFilter {
    self.glContext.colorFilterType = [QBGLFilterTypes nextFilterForType:self.glContext.colorFilterType];
}

- (NSString *)currentColorFilterName {
    return [QBGLFilterTypes filterNameForType:self.glContext.colorFilterType];
}

- (RKVideoCamera *)videoCamera {
    if (!_videoCamera) {
        _videoCamera = [[RKVideoCamera alloc] initWithSessionPreset:_configuration.avSessionPreset cameraPosition:AVCaptureDevicePositionFront];
        _videoCamera.delegate = self;
        _videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
    }
    return _videoCamera;
}

- (void)setRunning:(BOOL)running {
    if (_running == running) return;
    _running = running;
    
    if (!_running) {
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        [self.videoCamera stopCapture];
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        [self.videoCamera startCapture];
    }
}

- (QBGLContext *)glContext {
    if (!_glContext) {
        _glContext = [[QBGLContext alloc] initWithContext:_eaglContext];
        _glContext.outputSize = _configuration.videoSize;
        [_glContext setDisplayOrientation:self.displayOrientation cameraPosition:self.captureDevicePosition];
    }
    return _glContext;
}

- (void)setPreView:(UIView *)preView {
    if (self.glContext.displayView.superview) {
        [self.glContext.displayView removeFromSuperview];
    }
    if (preView) {
        [preView insertSubview:self.glContext.displayView atIndex:0];
        self.glContext.displayView.frame = CGRectMake(0, 0, preView.frame.size.width, preView.frame.size.height);
        self.glContext.drawDisplay = YES;
    } else {
        self.glContext.drawDisplay = NO;
    }
}

- (UIView *)preView {
    return self.glContext.displayView.superview;
}

- (void)setCaptureDevicePosition:(AVCaptureDevicePosition)captureDevicePosition {
    if (captureDevicePosition == self.videoCamera.cameraPosition)
        return;
    [self.videoCamera rotateCamera];
    self.videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
    [self.glContext setDisplayOrientation:self.displayOrientation cameraPosition:self.captureDevicePosition];
    self.glContext.displayMirror = _mirror && captureDevicePosition == AVCaptureDevicePositionFront;
    self.glContext.outputMirror = _mirrorOutput && captureDevicePosition == AVCaptureDevicePositionFront;
}

- (AVCaptureDevicePosition)captureDevicePosition {
    return [self.videoCamera cameraPosition];
}

- (void)setDisplayOrientation:(UIInterfaceOrientation)displayOrientation {
    _displayOrientation = displayOrientation;
    [self.glContext setDisplayOrientation:displayOrientation cameraPosition:self.captureDevicePosition];
    self.glContext.displayMirror = _mirror && self.captureDevicePosition == AVCaptureDevicePositionFront;
    self.glContext.outputMirror = _mirrorOutput && self.captureDevicePosition == AVCaptureDevicePositionFront;
}

- (UIInterfaceOrientation)displayOrientation {
    return _displayOrientation;
}

- (void)setVideoFrameRate:(NSInteger)videoFrameRate {
    if (videoFrameRate <= 0) return;
    if (videoFrameRate == self.videoCamera.frameRate) return;
    self.videoCamera.frameRate = (uint32_t)videoFrameRate;
}

- (NSInteger)videoFrameRate {
    return self.videoCamera.frameRate;
}

- (void)setTorch:(BOOL)torch {
    BOOL ret;
    if (!self.videoCamera.captureSession) return;
    AVCaptureSession *session = (AVCaptureSession *)self.videoCamera.captureSession;
    [session beginConfiguration];
    if (self.videoCamera.videoDeviceInput) {
        if (self.videoCamera.captureDevice.torchAvailable) {
            NSError *err = nil;
            if ([self.videoCamera.captureDevice lockForConfiguration:&err]) {
                [self.videoCamera.captureDevice setTorchMode:(torch ? AVCaptureTorchModeOn : AVCaptureTorchModeOff) ];
                [self.videoCamera.captureDevice unlockForConfiguration];
                ret = (self.videoCamera.captureDevice.torchMode == AVCaptureTorchModeOn);
            } else {
                NSLog(@"Error while locking device for torch: %@", err);
                ret = false;
            }
        } else {
            NSLog(@"Torch not available in current camera input");
        }
    }
    [session commitConfiguration];
    _torch = ret;
}

- (BOOL)torch {
    return self.videoCamera.captureDevice.torchMode;
}

- (void)setMirror:(BOOL)mirror {
    _mirror = mirror;
    self.glContext.displayMirror = mirror && self.captureDevicePosition == AVCaptureDevicePositionFront;
}

- (void)setMirrorOutput:(BOOL)mirrorOutput {
    _mirrorOutput = mirrorOutput;
    self.glContext.outputMirror = mirrorOutput && self.captureDevicePosition == AVCaptureDevicePositionFront;
}

- (void)setBeautyFace:(BOOL)beautyFace {
    self.glContext.beautyEnabled = beautyFace;
}

- (BOOL)beautyFace {
    return self.glContext.beautyEnabled;
}

- (void)setBeautyFaceEnhanced:(BOOL)beautyFaceEnhanced {
    self.glContext.beautyEnhanced = beautyFaceEnhanced;
}

- (BOOL)beautyFaceEnhanced {
    return self.glContext.beautyEnhanced;
}

- (void)setZoomScale:(CGFloat)zoomScale {
    if (self.videoCamera && self.videoCamera.videoDeviceInput) {
        AVCaptureDevice *device = self.videoCamera.captureDevice;
        if ([device lockForConfiguration:nil]) {
            device.videoZoomFactor = zoomScale;
            [device unlockForConfiguration];
            _zoomScale = zoomScale;
        }
    }
}

- (CGFloat)zoomScale {
    return _zoomScale;
}

- (UIImage *)currentImage {
    return nil;
}

#pragma mark - Notification

- (void)willEnterBackground:(NSNotification *)notification {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self.videoCamera pauseCapture];
    glFinish();
}

- (void)willEnterForeground:(NSNotification *)notification {
    [self.videoCamera resumeCapture];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

- (void)statusBarChanged:(NSNotification *)notification {
    UIInterfaceOrientation statusBar = [[UIApplication sharedApplication] statusBarOrientation];
    self.displayOrientation = statusBar == UIInterfaceOrientationPortrait ? UIInterfaceOrientationPortraitUpsideDown : UIInterfaceOrientationPortrait;
}

#pragma mark - RKVideoCamera Delegate

- (void)videoCamera:(RKVideoCamera *)camera didCaptureVideoSample:(CMSampleBufferRef)sampleBuffer {
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    [self.glContext loadYUVPixelBuffer:pixelBuffer];
    [self.glContext render];
    
    if ([self.delegate respondsToSelector:@selector(captureOutput:pixelBuffer:atTime:)]) {
        [self.glContext drawToOutput];
        
        CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        [self.delegate captureOutput:self pixelBuffer:self.glContext.outputPixelBuffer atTime:time];
    }
}

@end
