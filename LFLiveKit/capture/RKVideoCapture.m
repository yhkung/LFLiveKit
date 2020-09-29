//
//  RKVideoCapture.m
//  LFLiveKit
//
//  Created by Ken Sun on 2018/1/11.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "RKVideoCapture.h"
#import "LFUtils.h"
#import "RKVideoCamera.h"
#import "QBGLContext.h"
#import "QBGLFilterTypes.h"
#import "QBGLUtils.h"
#import "QBGLTextureRenderInfo.h"
#import "LFLiveFeatureConfig.h"
#import "RKExtFilterPresenter.h"

@interface RKVideoCapture () <RKVideoCameraDelegate, RKExtFilterPresenterDelegate>

@property (strong, nonatomic) LFLiveVideoConfiguration *configuration;
@property (strong, nonatomic) RKVideoCamera *videoCamera;
@property (strong, nonatomic) QBGLContext *glContext;
@property (strong, nonatomic) RKExtFilterPresenter *extFilterPresenter;
@property (strong, nonatomic) GLKView *glkView;
@property (nonatomic) UIInterfaceOrientation displayOrientation;
@property (nonatomic) CGRect previewRect;
@property (assign, nonatomic) BOOL didUpdateVideoConfiguration;
@property (assign, nonatomic) BOOL shouldHandleResignActiveByWaitCameraThread;
@property (strong, nonatomic) NSOperationQueue *queue;
@property (strong, nonatomic) dispatch_group_t cameraThreadGroup;
@property (assign, nonatomic) BOOL hasSnowEffect;

@end

@implementation RKVideoCapture
@synthesize delegate = _delegate;
@synthesize running = _running;
@synthesize torch = _torch;
@synthesize mirror = _mirror;
@synthesize saveLocalVideo = _saveLocalVideo;
@synthesize saveLocalVideoPath = _saveLocalVideoPath;
@synthesize mirrorOutput = _mirrorOutput;
@synthesize displayOrientation = _displayOrientation;

- (instancetype)initWithVideoConfiguration:(LFLiveVideoConfiguration *)configuration {
    return [self initWithVideoConfiguration:configuration eaglContext:nil liveFeatureConfig:nil];
}

- (nullable instancetype)initWithVideoConfiguration:(nullable LFLiveVideoConfiguration *)configuration
                                        eaglContext:(nullable EAGLContext *)glContext
                                  liveFeatureConfig:(LFLiveFeatureConfig *)featureConfig {
    if (self = [super init]) {
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = 1;
        _queue.qualityOfService = NSQualityOfServiceUtility;
        
        _shouldHandleResignActiveByWaitCameraThread = featureConfig.shouldHandleResignActiveByWaitCameraThread;
        _configuration = configuration;
        _eaglContext = glContext;
        _displayOrientation = [[LFUtils sharedApplication] statusBarOrientation];
        _cameraThreadGroup = _shouldHandleResignActiveByWaitCameraThread ? dispatch_group_create() : nil;
        self.glContext.filterGroupConfig = @{@(QBGLExtFilterTypeBoxes).stringValue : @(featureConfig.extFilterConfig.enableBoxes),
                                             @(QBGLExtFilterTypeGame).stringValue : @(featureConfig.extFilterConfig.enableGame),
                                             @(QBGLExtFilterTypePainter).stringValue : @(featureConfig.extFilterConfig.enablePainter)};
        _extFilterPresenter = [RKExtFilterPresenter extFilterPresenterWithLiveFeatureConfig:featureConfig.extFilterConfig];
        _extFilterPresenter.delegate = self;
        self.beautyFace = YES;
        self.zoomScale = 1.0;
        self.mirror = YES;
    
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarChanged:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
    }
    
    return self;
}

- (void)dealloc {
    [self.queue cancelAllOperations];
    [self disableIdleTimer:NO];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.videoCamera stopCapture];
    
    [_glkView removeFromSuperview];
    _glkView = nil;
}

- (void)previousColorFilter {
    self.glContext.colorFilterType = [QBGLFilterTypes previousFilterForType:self.glContext.colorFilterType];
}

- (void)nextColorFilter {
    self.glContext.colorFilterType = [QBGLFilterTypes nextFilterForType:self.glContext.colorFilterType];
}

- (void)startSnowEffect {
    self.hasSnowEffect = YES;
}

- (void)stopSnowEffect {
    self.hasSnowEffect = NO;
}

- (void)setTargetColorFilter:(NSInteger)targetIndex {
    if (![QBGLFilterTypes validFilterForType:targetIndex]) {
        return;
    }
    self.glContext.colorFilterType = targetIndex;
}

- (NSString *)currentColorFilterName {
    return [QBGLFilterTypes filterNameForType:self.glContext.colorFilterType];
}

- (NSInteger)currentColorFilterIndex {
    return self.glContext.colorFilterType;
}

- (NSArray<NSString *> *)colorFilterNames {
    return [QBGLFilterTypes filterNames];
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
        [self disableIdleTimer:NO];
        [self.videoCamera stopCapture];
    } else {
        [self disableIdleTimer:YES];
        [self.videoCamera startCapture];
    }
}

- (void)setNextVideoConfiguration:(LFLiveVideoConfiguration *)nextVideoConfiguration {
    [self.queue addOperationWithBlock:^{
        _nextVideoConfiguration = nextVideoConfiguration;
    }];
}

- (QBGLContext *)glContext {
    if (!_glContext) {
        _glContext = [[QBGLContext alloc] initWithContext:_eaglContext animationView:self.configuration.animationView];
        _glContext.outputSize = _configuration.videoSize;
        [_glContext setPreviewDisplayOrientation:self.displayOrientation cameraPosition:self.captureDevicePosition];
        [_glContext setPreviewAnimationOrientationWithCameraPosition:self.captureDevicePosition mirror:self.mirrorOutput];
        [_glContext setDisplayOrientation:self.displayOrientation cameraPosition:self.captureDevicePosition mirror:self.mirrorOutput];
    }
    return _glContext;
}

- (GLKView *)glkView {
    if (!_glkView) {
        _glkView = [[GLKView alloc] initWithFrame:[UIScreen mainScreen].bounds context:self.glContext.glContext];
        _glkView.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
        _glkView.drawableDepthFormat = GLKViewDrawableDepthFormatNone;
        _glkView.drawableStencilFormat = GLKViewDrawableStencilFormatNone;
        _glkView.drawableMultisample = GLKViewDrawableMultisampleNone;
        _glkView.layer.masksToBounds = YES;
        _glkView.enableSetNeedsDisplay = NO;
        _glkView.contentScaleFactor = 1.0;
        _glkView.transform = CGAffineTransformMakeRotation(-M_PI); // TRICKY: dont know why glkview has wrong orientation
        
        [_glkView bindDrawable];
        self.previewRect = [self ratio_16_9_fill_frame:CGRectMake(0, 0, _glkView.drawableWidth, _glkView.drawableHeight)];
    }
    return _glkView;
}

- (void)setPreView:(UIView *)preView {
    if (self.glkView.superview) {
        [self.glkView removeFromSuperview];
    }
    [preView insertSubview:self.glkView atIndex:0];
    self.glkView.frame = self.previewRect;
}

- (UIView *)preView {
    return self.glkView.superview;
}

- (void)setCaptureDevicePosition:(AVCaptureDevicePosition)captureDevicePosition {
    if (captureDevicePosition == self.videoCamera.cameraPosition)
        return;
    [self.videoCamera rotateCamera];
    self.videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
    [self.glContext setPreviewDisplayOrientation:self.displayOrientation cameraPosition:self.captureDevicePosition];
    [self.glContext setPreviewAnimationOrientationWithCameraPosition:self.captureDevicePosition mirror:self.mirrorOutput];
    [self.glContext setDisplayOrientation:self.displayOrientation cameraPosition:self.captureDevicePosition mirror:self.mirrorOutput];
}

- (AVCaptureDevicePosition)captureDevicePosition {
    return [self.videoCamera cameraPosition];
}

- (void)setDisplayOrientation:(UIInterfaceOrientation)displayOrientation {
    _displayOrientation = displayOrientation;
    [self.glContext setPreviewDisplayOrientation:displayOrientation cameraPosition:self.captureDevicePosition];
    [self.glContext setPreviewAnimationOrientationWithCameraPosition:self.captureDevicePosition mirror:self.mirrorOutput];
    [self.glContext setDisplayOrientation:displayOrientation cameraPosition:self.captureDevicePosition mirror:self.mirrorOutput];
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
}

- (void)setMirrorOutput:(BOOL)mirrorOutput {
    _mirrorOutput = mirrorOutput;
    [self.glContext setPreviewAnimationOrientationWithCameraPosition:self.captureDevicePosition mirror:mirrorOutput];
    [self.glContext setDisplayOrientation:self.displayOrientation cameraPosition:self.captureDevicePosition mirror:mirrorOutput];
}

- (void)setBeautyFace:(BOOL)beautyFace {
    self.glContext.beautyEnabled = beautyFace;
}

- (BOOL)beautyFace {
    return self.glContext.beautyEnabled;
}

- (void)setZoomScale:(CGFloat)zoomScale {
    self.videoCamera.zoomFactor = zoomScale;
}

- (CGFloat)zoomScale {
    return self.videoCamera.zoomFactor;
}

- (UIImage *)currentImage {
    return nil;
}

- (CGRect)ratio_16_9_fill_frame:(CGRect)inputFrame {
    CGRect frame = inputFrame;
    CGFloat widthDiff = 0.f;
    CGFloat heightDiff = 0.f;
    if (frame.size.width * 16.f < frame.size.height * 9.f) {
        CGFloat newWidth = frame.size.height * 9.f / 16.f;
        widthDiff = newWidth - frame.size.width;
        frame.size.width = newWidth;
        frame.origin.x = frame.origin.x - widthDiff / 2.f;
        
    } else if (frame.size.width * 16.f > frame.size.height * 9.f) {
        CGFloat newHeight = frame.size.width * 16.f / 9.f;
        heightDiff = newHeight - frame.size.height;
        frame.size.height = newHeight;
        frame.origin.y = frame.origin.y - heightDiff / 2.f;
    }
    return frame;
}

#pragma mark - Notification

- (void)willResignActive:(NSNotification *)notification {
    [self disableIdleTimer:NO];
    [self.videoCamera pauseCapture];
    NSLog(@"[GPUProcessing] camera pauseCapture");
    /**
     每次進入camera thread都會有enter跟leave, 在退到背景時, 如果group是在enter期間則等待到leave後才執行glFinish.
     **/
    if (self.shouldHandleResignActiveByWaitCameraThread &&
        self.cameraThreadGroup) {
        dispatch_group_wait(self.cameraThreadGroup, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)));
        glFinish();
        NSLog(@"[GPUProcessing] glFinish by wait camera thread.");
    } else {
        glFinish();
        NSLog(@"[GPUProcessing] glFinish.");
    }
}

- (void)willEnterForeground:(NSNotification *)notification {
    [self.videoCamera resumeCapture];
    [self disableIdleTimer:YES];
}

- (void)statusBarChanged:(NSNotification *)notification {
    UIInterfaceOrientation statusBar = [[LFUtils sharedApplication] statusBarOrientation];
    self.displayOrientation = statusBar == UIInterfaceOrientationPortrait ? UIInterfaceOrientationPortraitUpsideDown : UIInterfaceOrientationPortrait;
}

- (void)enterCameraThread {
    if (self.cameraThreadGroup) {
        dispatch_group_enter(self.cameraThreadGroup);
    }
}

- (void)leaveCameraThread {
    if (self.cameraThreadGroup) {
        dispatch_group_leave(self.cameraThreadGroup);
    }
}

#pragma mark - RKVideoCamera Delegate

- (void)videoCamera:(RKVideoCamera *)camera didCaptureVideoSample:(CMSampleBufferRef)sampleBuffer {
    [self enterCameraThread];
    
    if (self.nextVideoConfiguration) {
        __weak typeof(self) weakSelf = self;
        NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
            weakSelf.configuration.videoFrameRate = weakSelf.nextVideoConfiguration.videoFrameRate;
            weakSelf.configuration.videoMaxFrameRate = weakSelf.nextVideoConfiguration.videoMaxFrameRate;
            weakSelf.configuration.videoMinFrameRate = weakSelf.nextVideoConfiguration.videoMinFrameRate;
            weakSelf.configuration.videoBitRate = weakSelf.nextVideoConfiguration.videoBitRate;
            weakSelf.configuration.videoMaxBitRate = weakSelf.nextVideoConfiguration.videoMaxBitRate;
            weakSelf.configuration.videoMinBitRate = weakSelf.nextVideoConfiguration.videoMinFrameRate;
            weakSelf.configuration.videoSize = weakSelf.nextVideoConfiguration.videoSize;
            weakSelf.nextVideoConfiguration = nil;
            weakSelf.didUpdateVideoConfiguration = YES;
        }];
        
        [self.queue addOperation:operation];
        [operation waitUntilFinished];
    }

    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    if ([self.delegate respondsToSelector:@selector(captureRawCamera:pixelBuffer:atTime:)]) {
        CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        [self.delegate captureRawCamera:self pixelBuffer:pixelBuffer atTime:time];
    }
    
    if ([self.delegate respondsToSelector:@selector(captureOutput:onPreProcessPixelBuffer:)]) {
        pixelBuffer = [self.delegate captureOutput:self onPreProcessPixelBuffer:pixelBuffer];
    }
    
    [self.glContext updatePropertiesForRender];
    
    if (self.hasSnowEffect) {
        [self.glContext startSnowEffect];
    } else {
        [self.glContext stopSnowEffect];
    }
    
    [self.glContext loadYUVPixelBuffer:pixelBuffer];
    
    if (_glkView) {
        BOOL hasMultiFilters = self.glContext.hasMultiFilters;
        self.glContext.viewPortSize = hasMultiFilters ? _configuration.videoSize : self.previewRect.size;
        self.glContext.outputSize = _configuration.videoSize;
        
        [self.glContext configInputFilterToPreview];
        
        if (hasMultiFilters) {
            [self.glContext renderInputFilterToOutputFilter];
            self.glContext.viewPortSize = self.previewRect.size;
            [_glkView bindDrawable];
            [self.glContext renderOutputFilterToPreview];
        } else {
            [_glkView bindDrawable];
            [self.glContext renderInputFilterToPreview];
        }
        
        [self.extFilterPresenter renderToExtFilterGroup];
                
        [_glkView display];
    }
    
    if ([self.delegate respondsToSelector:
         @selector(captureOutput:pixelBuffer:atTime:didUpdateVideoConfiguration:)]) {
        self.glContext.viewPortSize = _configuration.videoSize;
        self.glContext.outputSize = _configuration.videoSize;
        
        [self.extFilterPresenter handleExtFilterRenderInfoIfNeeded];
        
        [self.glContext renderToOutput];
        if (self.glContext.outputPixelBuffer) {
            CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            [self.delegate captureOutput:self
                             pixelBuffer:self.glContext.outputPixelBuffer
                                  atTime:time
             didUpdateVideoConfiguration:_didUpdateVideoConfiguration];
        }
    }
    
    self.didUpdateVideoConfiguration = NO;
    [self leaveCameraThread];
}

#pragma mark - RKExtFilterPresenterDelegate

- (NSArray<NSDictionary *> *)boxesRenderInfosForExtPresenter:(RKExtFilterPresenter *)presenter {
    if ([self.delegate respondsToSelector:@selector(boxesRenderInfosForVideoCapture:)]) {
        return [self.delegate boxesRenderInfosForVideoCapture:self];
    }
    
    return nil;
}

- (NSArray<NSDictionary *> *)gameRenderInfosForExtPresenter:(RKExtFilterPresenter *)presenter {
    if ([self.delegate respondsToSelector:@selector(gameRenderInfosForVideoCapture:)]) {
        return [self.delegate gameRenderInfosForVideoCapture:self];
    }
    
    return nil;
}

- (NSArray<NSDictionary *> *)painterRenderInfosForExtPresenter:(RKExtFilterPresenter *)presenter {
    if ([self.delegate respondsToSelector:@selector(painterRenderInfosForVideoCapture:)]) {
        NSArray *infos = [self.delegate painterRenderInfosForVideoCapture:self];
        
        return infos;
    }
    
    return nil;
}

- (BOOL)painterShouldRenderForExtPresenter:(RKExtFilterPresenter *)presenter {
    if ([self.delegate respondsToSelector:@selector(painterShouldRenderForVideoCapture:)]) {
        return [self.delegate painterShouldRenderForVideoCapture:self];
    }
    
    return NO;
}

- (QBGLContext *)glContextForExtPresenter:(RKExtFilterPresenter *)presenter {
    return _glContext;
}

# pragma mark - Helper

- (void)disableIdleTimer:(BOOL)disabled {
    dispatch_async(dispatch_get_main_queue(), ^{
        [LFUtils sharedApplication].idleTimerDisabled = disabled;
    });
}

@end
