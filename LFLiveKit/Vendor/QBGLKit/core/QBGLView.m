//
//  QBGLView.m
//  LFLiveKit
//
//  Created by Ken Sun on 2018/2/6.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "QBGLView.h"
#import <OpenGLES/EAGLDrawable.h>
#import <AVFoundation/AVFoundation.h>
#import "QBGLProgram.h"
#import "QBGLDrawable.h"

char * const kQBDisplayFilterVertex;
char * const kQBDisplayFilterFragment;

@interface QBGLView ()

@property (strong, nonatomic) QBGLProgram *program;
@property (strong, nonatomic) QBGLDrawable *inputImageDrawable;
@property (nonatomic) int attrPosition;
@property (nonatomic) int attrInputTextureCoordinate;

@end

@implementation QBGLView {
    GLuint _framebuffer;
    GLuint _renderbuffer;
    GLint  _backingWidth;
    GLint  _backingHeight;
    
    GLfloat imageVertices[8];
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame glContext:(EAGLContext *)context {
    if (self = [super initWithFrame:frame]) {
        _glContext = context;
        [self setupGL];
    }
    return self;
}

- (void)dealloc {
    [self destroyDisplayBuffer];
}

- (void)setupGL {
    self.contentScaleFactor = [UIScreen mainScreen].scale;
    
    CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking: @NO,
                                     kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8
                                     };
    eaglLayer.contentsScale = self.contentScaleFactor;
    
    _program = [[QBGLProgram alloc] initWithVertexShader:kQBDisplayFilterVertex fragmentShader:kQBDisplayFilterFragment];
    _attrPosition = [_program attributeWithName:"position"];
    _attrInputTextureCoordinate = [_program attributeWithName:"inputTextureCoordinate"];
    [_program use];
    [_program enableAttributeWithId:_attrPosition];
    [_program enableAttributeWithId:_attrInputTextureCoordinate];
    
    [self createDisplayBuffer];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if ((GLint)self.bounds.size.width != _backingWidth || (GLint)self.bounds.size.height != _backingHeight) {
        [self destroyDisplayBuffer];
        [self createDisplayBuffer];
    } else if (!CGSizeEqualToSize(self.bounds.size, CGSizeZero)) {
        [self recalculateViewGeometry];
    }
}

- (void)becomeCurrentContext {
    if ([EAGLContext currentContext] != _glContext) {
        [EAGLContext setCurrentContext:_glContext];
    }
}

- (void)createDisplayBuffer {
    [self becomeCurrentContext];
    
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    
    glGenRenderbuffers(1, &_renderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    
    [_glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    if (!_backingWidth || !_backingHeight) {
        [self destroyDisplayBuffer];
        return;
    }
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
    
    __unused GLuint framebufferCreationStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    NSAssert(framebufferCreationStatus == GL_FRAMEBUFFER_COMPLETE, @"Failure with display framebuffer generation for display of size: %f, %f", self.bounds.size.width, self.bounds.size.height);
    
    [self recalculateViewGeometry];
}

- (void)destroyDisplayBuffer {
    [self becomeCurrentContext];
    
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    if (_renderbuffer) {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }
}

- (void)recalculateViewGeometry {
    CGFloat heightScaling, widthScaling;
    CGSize currentViewSize = self.bounds.size;
    CGRect insetRect = AVMakeRectWithAspectRatioInsideRect(_inputSize, self.bounds);
    
    switch(self.contentMode) {
        case UIViewContentModeScaleAspectFit: {
            widthScaling = insetRect.size.width / currentViewSize.width;
            heightScaling = insetRect.size.height / currentViewSize.height;
        }   break;
        case UIViewContentModeScaleAspectFill: {
            widthScaling = currentViewSize.height / insetRect.size.height;
            heightScaling = currentViewSize.width / insetRect.size.width;
        }   break;
        default: {
            widthScaling = 1.0;
            heightScaling = 1.0;
        }   break;
    }
    
    imageVertices[0] = -widthScaling;
    imageVertices[1] = -heightScaling;
    imageVertices[2] = widthScaling;
    imageVertices[3] = -heightScaling;
    imageVertices[4] = -widthScaling;
    imageVertices[5] = heightScaling;
    imageVertices[6] = widthScaling;
    imageVertices[7] = heightScaling;
}

- (GLuint)renderAtIndex:(GLuint)index {
    [_program use];
    
    if (!_framebuffer) {
        [self createDisplayBuffer];
    }
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    
    glViewport(0, 0, _backingWidth, _backingHeight);
    
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    index = [_inputImageDrawable prepareToDrawAtTextureIndex:index program:_program];
    
    glVertexAttribPointer(_attrPosition, 2, GL_FLOAT, 0, 0, imageVertices);
    glVertexAttribPointer(_attrInputTextureCoordinate, 2, GL_FLOAT, 0, 0, [self.class textureCoordinatesForRotation:_inputRotation]);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_glContext presentRenderbuffer:GL_RENDERBUFFER];
    
    return index;
}

- (GLuint)render {
    return [self renderAtIndex:0];
}

- (void)loadTexture:(GLuint)textureId {
    _inputImageDrawable = [[QBGLDrawable alloc] initWithTextureId:textureId identifier:@"inputImageTexture"];
}

+ (const GLfloat *)textureCoordinatesForRotation:(QBGLImageRotation)rotation {
    
    static const GLfloat noRotationTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    
    static const GLfloat rotateRightTextureCoordinates[] = {
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
    };
    
    static const GLfloat rotateLeftTextureCoordinates[] = {
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat verticalFlipTextureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat horizontalFlipTextureCoordinates[] = {
        1.0f, 1.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
    };
    
    static const GLfloat rotateRightVerticalFlipTextureCoordinates[] = {
        1.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
    };
    
    static const GLfloat rotateRightHorizontalFlipTextureCoordinates[] = {
        0.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
    };
    
    static const GLfloat rotate180TextureCoordinates[] = {
        1.0f, 0.0f,
        0.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 1.0f,
    };
    
    switch(rotation) {
        case QBGLImageRotationNone:
            return noRotationTextureCoordinates;
        case QBGLImageRotationLeft:
            return rotateLeftTextureCoordinates;
        case QBGLImageRotationRight:
            return rotateRightTextureCoordinates;
        case QBGLImageRotationFlipVertical:
            return verticalFlipTextureCoordinates;
        case QBGLImageRotationFlipHorizonal:
            return horizontalFlipTextureCoordinates;
        case QBGLImageRotationRightFlipVertical:
            return rotateRightVerticalFlipTextureCoordinates;
        case QBGLImageRotationRightFlipHorizontal:
            return rotateRightHorizontalFlipTextureCoordinates;
        case QBGLImageRotation180:
            return rotate180TextureCoordinates;
    }
}

@end

char * const kQBDisplayFilterVertex = STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
 );

char * const kQBDisplayFilterFragment = STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
 );
