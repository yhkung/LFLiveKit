//
//  QBGLContext.h
//  Qubi
//
//  Created by Ken Sun on 2016/8/21.
//  Copyright © 2016年 Qubi. All rights reserved.
//

@class QBGLTextureRenderInfo;
@class QBGLPainterRenderInfo;

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#import "QBGLFilterTypes.h"
#import "QBGLExtFilterType.h"

@interface QBGLContext : NSObject

@property (strong, nonatomic, readonly) EAGLContext *glContext;
@property (nonatomic, readonly) CVPixelBufferRef outputPixelBuffer;

@property (nonatomic) CGSize outputSize;
@property (nonatomic) CGSize viewPortSize;

@property (nonatomic) QBGLFilterType colorFilterType;

@property (nonatomic) BOOL beautyEnabled;

@property (strong, nonatomic) UIView *animationView;

@property (assign, nonatomic, readonly) BOOL hasMagicFilter;
@property (assign, nonatomic, readonly) BOOL hasMultiFilters;

@property (copy, nonatomic) NSDictionary<NSString *, NSNumber *> *filterGroupConfig;

- (instancetype)initWithContext:(EAGLContext *)context animationView:(UIView *)animationView;

- (void)loadYUVPixelBuffer:(CVPixelBufferRef)pixelBuffer;

- (void)loadBGRAPixelBuffer:(CVPixelBufferRef)pixelBuffer;

- (void)render;

- (void)renderToOutput;

- (void)setDisplayOrientation:(UIInterfaceOrientation)orientation cameraPosition:(AVCaptureDevicePosition)position mirror:(BOOL)mirror;

- (void)updatePropertiesForRender;
- (void)renderToExtFilterGroup;

#pragma mark - Animation

- (void)setPreviewAnimationOrientationWithCameraPosition:(AVCaptureDevicePosition)position mirror:(BOOL)mirror;

#pragma mark - Preview

- (void)setPreviewDisplayOrientation:(UIInterfaceOrientation)orientation cameraPosition:(AVCaptureDevicePosition)position;
- (void)configInputFilterToPreview;
- (void)renderInputFilterToPreview;
- (void)renderInputFilterToOutputFilter;
- (void)renderOutputFilterToPreview;

#pragma mark - Snow

- (void)startSnowEffect;
- (void)stopSnowEffect;

#pragma mark - ExtFilter

- (void)enableExtFilterRender:(QBGLExtFilterType)type enable:(BOOL)enable;
- (void)updateExtFilter:(NSArray<NSObject *> *)infos type:(QBGLExtFilterType)type;

@end
