//
//  QBGLContext.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/21.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLContext.h"
#import "QBGLFilter.h"
#import "QBGLFilterFactory.h"
#import "QBGLProgram.h"
#import "QBGLYuvFilter.h"
#import "QBGLBeautyFilter.h"
#import "QBGLBeautyEnhanceFilter.h"
#import "QBGLColorMapFilter.h"
#import "QBGLView.h"

@interface QBGLContext ()

@property (strong, nonatomic) QBGLYuvFilter *yuvFilter;
@property (strong, nonatomic) QBGLBeautyFilter *beautyFilter;
@property (strong, nonatomic) QBGLBeautyEnhanceFilter *beautyEnhanceFilter;
@property (strong, nonatomic) QBGLColorMapFilter *colorFilter;
@property (strong, nonatomic) QBGLFilter *outputFilter;
@property (strong, nonatomic) QBGLView *glView;

@property (nonatomic) CVOpenGLESTextureCacheRef textureCacheRef;

@end

@implementation QBGLContext

- (instancetype)init {
    return [self initWithContext:nil];
}

- (instancetype)initWithContext:(EAGLContext *)context {
    if (context.API == kEAGLRenderingAPIOpenGLES1)
        @throw [NSException exceptionWithName:@"QBGLContext init error" reason:@"GL context  can't be kEAGLRenderingAPIOpenGLES1" userInfo:nil];
    if (self = [super init]) {
        _glContext = context ?: [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];;
        [self becomeCurrentContext];
        CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _glContext, NULL, &_textureCacheRef);
    }
    return self;
}

- (void)dealloc {
    [self becomeCurrentContext];
    CFRelease(_textureCacheRef);
    
    [EAGLContext setCurrentContext:nil];
}

- (CVPixelBufferRef)outputPixelBuffer {
    return self.outputFilter.outputPixelBuffer;
}

- (QBGLYuvFilter *)yuvFilter {
    if (!_yuvFilter) {
        _yuvFilter = [[QBGLYuvFilter alloc] init];
        _yuvFilter.textureCacheRef = _textureCacheRef;
    }
    return _yuvFilter;
}

- (QBGLBeautyFilter *)beautyFilter {
    if (!_beautyFilter) {
        _beautyFilter = [[QBGLBeautyFilter alloc] init];
        _beautyFilter.textureCacheRef = _textureCacheRef;
    }
    return _beautyFilter;
}

- (QBGLBeautyEnhanceFilter *)beautyEnhanceFilter {
    if (!_beautyEnhanceFilter) {
        _beautyEnhanceFilter = [[QBGLBeautyEnhanceFilter alloc] init];
        _beautyEnhanceFilter.textureCacheRef = _textureCacheRef;
        _beautyEnhanceFilter.inputSize = _beautyEnhanceFilter.outputSize = self.yuvFilter.outputSize;
    }
    return _beautyEnhanceFilter;
}

- (QBGLColorMapFilter *)colorFilter {
    if (!_colorFilter) {
        _colorFilter = [[QBGLColorMapFilter alloc] init];
        _colorFilter.textureCacheRef = _textureCacheRef;
        _colorFilter.inputSize = _colorFilter.outputSize = self.yuvFilter.outputSize;
    }
    if (_colorFilter.type != _colorFilterType) {
        [QBGLFilterFactory refactorColorFilter:_colorFilter withType:_colorFilterType];
        _colorFilter.type = _colorFilterType;
    }
    return _colorFilter;
}

- (QBGLFilter *)outputFilter {
    if (!_outputFilter) {
        _outputFilter = [[QBGLFilter alloc] init];
        _outputFilter.textureCacheRef = _textureCacheRef;
        _outputFilter.inputRotation = _outputMirror ? QBGLImageRotationFlipHorizonal : QBGLImageRotationNone;
    }
    return _outputFilter;
}

- (UIView *)displayView {
    if (!_glView) {
        _glView = [[QBGLView alloc] initWithFrame:[UIScreen mainScreen].bounds glContext:_glContext];
        _glView.inputSize = self.outputFilter.inputSize;
        _glView.inputRotation = _displayMirror ? QBGLImageRotationFlipHorizonal : QBGLImageRotationNone;
    }
    return _glView;
}

- (void)becomeCurrentContext {
    if ([EAGLContext currentContext] != _glContext) {
        [EAGLContext setCurrentContext:_glContext];
    }
}

- (void)setOutputSize:(CGSize)outputSize {
    if (CGSizeEqualToSize(outputSize, _outputSize))
        return;
    _outputSize = outputSize;
    
    self.yuvFilter.outputSize = outputSize;
    self.beautyFilter.inputSize = self.beautyFilter.outputSize = outputSize;
    _beautyEnhanceFilter.inputSize = _beautyEnhanceFilter.outputSize = outputSize;
    _colorFilter.inputSize = _colorFilter.outputSize = outputSize;
    self.outputFilter.inputSize = self.outputFilter.outputSize = outputSize;
    _glView.inputSize = outputSize;
}

- (void)loadYUVPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    [self becomeCurrentContext];
    self.yuvFilter.inputSize = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
    [self.yuvFilter loadYUV:pixelBuffer];
}

- (void)loadBGRAPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    [self becomeCurrentContext];
    // TODO:
}

- (void)render {
    [self becomeCurrentContext];
    
    [self.yuvFilter render];
    [self.yuvFilter draw];
    
    GLuint textureId = self.yuvFilter.outputTextureId;
    
    if (self.beautyEnabled) {
        [self.beautyFilter loadTexture:textureId];
        [self.beautyFilter render];
        [self.beautyFilter draw];
        textureId = self.beautyFilter.outputTextureId;
    }
    if (self.beautyEnhanced) {
        [self.beautyEnhanceFilter loadTexture:textureId];
        [self.beautyEnhanceFilter render];
        [self.beautyEnhanceFilter draw];
        textureId = self.beautyEnhanceFilter.outputTextureId;
    }
    if (self.colorFilterType != QBGLFilterTypeNone) {
        [self.colorFilter loadTexture:textureId];
        [self.colorFilter render];
        [self.colorFilter draw];
        textureId = self.colorFilter.outputTextureId;
    }
    if (self.drawDisplay) {
        [_glView loadTexture:textureId];
        [_glView render];
    }
    [self.outputFilter loadTexture:textureId];
}

- (void)drawToOutput {
    [self.outputFilter render];
    [self.outputFilter draw];
    glFlush();
}

- (void)setDisplayOrientation:(UIInterfaceOrientation)orientation cameraPosition:(AVCaptureDevicePosition)position {
    if (position == AVCaptureDevicePositionBack) {
        self.yuvFilter.inputRotation =
        orientation == UIInterfaceOrientationPortrait           ? QBGLImageRotationRight :
        orientation == UIInterfaceOrientationPortraitUpsideDown ? QBGLImageRotationLeft  :
        orientation == UIInterfaceOrientationLandscapeLeft      ? QBGLImageRotation180   : QBGLImageRotationNone;
    } else {
        self.yuvFilter.inputRotation =
        orientation == UIInterfaceOrientationPortrait           ? QBGLImageRotationRight :
        orientation == UIInterfaceOrientationPortraitUpsideDown ? QBGLImageRotationLeft  :
        orientation == UIInterfaceOrientationLandscapeLeft      ? QBGLImageRotationNone  :
        orientation == UIInterfaceOrientationLandscapeRight     ? QBGLImageRotation180   : QBGLImageRotationNone;
    }
}

- (void)setDisplayMirror:(BOOL)mirror {
    _displayMirror = mirror;
    _glView.inputRotation = _displayMirror ? QBGLImageRotationFlipHorizonal : QBGLImageRotationNone;
}

- (void)setOutputMirror:(BOOL)mirror {
    _outputMirror = mirror;
    _outputFilter.inputRotation = _outputMirror ? QBGLImageRotationFlipHorizonal : QBGLImageRotationNone;
}

@end
