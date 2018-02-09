//
//  QBGLContext.h
//  Qubi
//
//  Created by Ken Sun on 2016/8/21.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <GLKit/GLKit.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreMedia/CoreMedia.h>
#import "QBGLFilterTypes.h"
#import "QBGLUtils.h"

@interface QBGLContext : NSObject

@property (strong, nonatomic, readonly) EAGLContext *glContext;
@property (nonatomic, readonly) CVPixelBufferRef outputPixelBuffer;

@property (nonatomic) CGSize viewPortSize;
@property (nonatomic) CGSize outputSize;

@property (nonatomic) QBGLFilterType colorFilterType;
@property (nonatomic) BOOL beautyEnabled;
@property (nonatomic) BOOL beautyEnhanced;
@property (nonatomic) BOOL drawDisplay;
@property (nonatomic) BOOL displayMirror;
@property (nonatomic) BOOL outputMirror;

- (instancetype)initWithContext:(EAGLContext *)context;

- (void)loadYUVPixelBuffer:(CVPixelBufferRef)pixelBuffer;

- (void)loadBGRAPixelBuffer:(CVPixelBufferRef)pixelBuffer;

- (void)render;

//- (void)draw;

- (void)drawToOutput;

- (void)setDisplayOrientation:(UIInterfaceOrientation)orientation cameraPosition:(AVCaptureDevicePosition)position;

- (UIView *)displayView;

@end
