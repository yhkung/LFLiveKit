//
//  QBGLFilter.h
//  Qubi
//
//  Created by Ken Sun on 2016/8/21.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <UIKit/UIKit.h>
#import "QBGLUtils.h"

typedef NS_ENUM(NSUInteger, QBGLImageRotation) {
    QBGLImageRotationNone,
    QBGLImageRotationLeft,
    QBGLImageRotationRight,
    QBGLImageRotationFlipVertical,
    QBGLImageRotationFlipHorizonal,
    QBGLImageRotationRightFlipVertical,
    QBGLImageRotationRightFlipHorizontal,
    QBGLImageRotation180,
    QBGLImageRotationLeftFlipVertical,
    QBGLImageRotationLeftFlipHorizontal,
    QBGLImageRotation180FlipVertical,
    QBGLImageRotation180FlipHorizontal
};

@class QBGLProgram;
@class QBGLDrawable;

@interface QBGLFilter : NSObject
@property (strong, nonatomic, readonly) QBGLProgram *program;

@property (nonatomic) QBGLImageRotation inputRotation;
@property (nonatomic) QBGLImageRotation animationRotation;
@property (nonatomic) CGSize inputSize;
@property (nonatomic) CGSize outputSize;
@property (nonatomic) CGSize viewPortSize;

@property (nonatomic) CVOpenGLESTextureCacheRef textureCacheRef;
@property (nonatomic) GLuint outputTextureId;
@property (nonatomic, readonly) CVPixelBufferRef outputPixelBuffer;

@property (strong, nonatomic) UIView *animationView;
@property (assign, nonatomic) BOOL enableAnimationView;

- (instancetype)initWithVertexShader:(const char *)vertexShader
                      fragmentShader:(const char *)fragmentShader;

- (instancetype)initWithAnimationView:(UIView *)animationView;

/**
 * Subclass should call this method when ready to load.
 */
- (void)loadTextures;

- (void)releaseUsages;
/**
 * Subclass should always call [super deleteTextures].
 */
- (void)deleteTextures;

- (void)loadTexture:(GLuint)textureId;

- (NSArray<QBGLDrawable*> *)renderTextures;

- (void)loadBGRA:(CVPixelBufferRef)pixelBuffer;

- (void)setAdditionalUniformVarsForRender;

- (void)updateDrawable;

/**
 * Prepare for drawing and return the next available active texture index.
 */
- (GLuint)render;
- (void)renderDrawable:(QBGLDrawable *)drawable;

- (void)bindDrawable;

- (void)draw;

@end
