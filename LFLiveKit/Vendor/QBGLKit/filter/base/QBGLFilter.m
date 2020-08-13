//
//  QBGLFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/21.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLFilter.h"
#import "QBGLProgram.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"

char * const kQBNoFilterVertex;
char * const kQBNoFilterFragment;

@interface QBGLFilter ()
@property (assign, nonatomic) int attrPosition;
@property (assign, nonatomic) int attrInputTextureCoordinate;

@property (strong, nonatomic) QBGLDrawable *inputImageDrawable;

@property (assign, nonatomic) GLuint outputFrameBuffer;
@property (assign, nonatomic) GLuint depthRenderBuffer;

// animation
@property (assign, nonatomic) int attrInputAnimationCoordinate;
@property (strong, nonatomic) QBGLDrawable *animationDrawable;

@end


@implementation QBGLFilter

#pragma mark - Class

+ (const GLfloat *)textureCoordinatesForRotation:(QBGLImageRotation)rotation {
    static const GLfloat noRotationTextureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat rotateLeftTextureCoordinates[] = {
        1.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
    };
    
    static const GLfloat rotateRightTextureCoordinates[] = {
        0.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
    };
    
    static const GLfloat verticalFlipTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    
    static const GLfloat horizontalFlipTextureCoordinates[] = {
        1.0f, 0.0f,
        0.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 1.0f,
    };
    
    // vertical flip first and then rotate right
    static const GLfloat rotateRightVerticalFlipTextureCoordinates[] = {
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
    };
    
    // horizontal flip first and then rotate right
    static const GLfloat rotateRightHorizontalFlipTextureCoordinates[] = {
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat rotate180TextureCoordinates[] = {
        1.0f, 1.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
    };
    
    // vertical flip first and then rotate left
    static const GLfloat rotateLeftVerticalFlipTextureCoordinates[] = {
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
    };
    
    // horizontal flip first and then rotate left
    static const GLfloat rotateLeftHorizontalFlipTextureCoordinates[] = {
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
    };
    
    // vertical flip first and then rotate 180
    static const GLfloat rotate180VerticalFlipTextureCoordinates[] = {
        1.0f, 0.0f,
        0.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 1.0f,
    };
    
    // horizontal flip first and then rotate 180
    static const GLfloat rotate180HorizontalFlipTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
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
        case QBGLImageRotationLeftFlipVertical:
            return rotateLeftVerticalFlipTextureCoordinates;
        case QBGLImageRotationLeftFlipHorizontal:
            return rotateLeftHorizontalFlipTextureCoordinates;
        case QBGLImageRotation180FlipVertical:
            return rotate180VerticalFlipTextureCoordinates;
        case QBGLImageRotation180FlipHorizontal:
            return rotate180HorizontalFlipTextureCoordinates;
    }
}

#pragma mark - Life Cycle

- (instancetype)init {
    return [self initWithVertexShader:kQBNoFilterVertex fragmentShader:kQBNoFilterFragment];
}

- (instancetype)initWithVertexShader:(const char *)vertexShader
                      fragmentShader:(const char *)fragmentShader {
    if (self = [super init]) {
        _program = [[QBGLProgram alloc] initWithVertexShader:vertexShader fragmentShader:fragmentShader];
        _attrPosition = [_program attributeWithName:"position"];
        _attrInputTextureCoordinate = [_program attributeWithName:"inputTextureCoordinate"];
    }
    return self;
}

- (instancetype)initWithAnimationView:(UIView *)animationView {
    if (self = [self init]) {
        [_program setParameter:"enableAnimationView" intValue:(animationView == nil ? 0 : 1)];
        if (animationView) {
            _attrInputAnimationCoordinate = [_program attributeWithName:"inputAnimationCoordinate"];
            _animationView = animationView;
            _animationDrawable = [[QBGLDrawable alloc] initWithView:animationView identifier:@"animationTexture" horizontalFlip:NO verticalFlip:NO];
        }
    }
    return self;
}

- (void)dealloc {
    [self deleteTextures];
    [self unloadOutputBuffer];
}

#pragma mark - Getter/Setter

- (void)setOutputSize:(CGSize)outputSize {
    if (CGSizeEqualToSize(outputSize, _outputSize))
        return;
    _outputSize = outputSize;
    
    [self unloadOutputBuffer];
    [self loadOutputBuffer];
}

#pragma mark - Public

- (void)loadTextures {
    // do nothing
}

- (void)deleteTextures {
    for (QBGLDrawable *drawable in [self renderTextures]) {
        [drawable deleteTexture];
    }
}

- (void)loadTexture:(GLuint)textureId {
    _inputImageDrawable = [[QBGLDrawable alloc] initWithTextureId:textureId identifier:@"inputImageTexture"];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    if (self.animationDrawable) {
        return @[self.animationDrawable];
    }
    return nil;
}

- (void)loadBGRA:(CVPixelBufferRef)pixelBuffer {
    int width = (int) CVPixelBufferGetWidth(pixelBuffer);
    int height = (int) CVPixelBufferGetHeight(pixelBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    CVOpenGLESTextureRef imageTextureRef;
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                 _textureCacheRef,
                                                 pixelBuffer,
                                                 NULL,
                                                 GL_TEXTURE_2D,
                                                 GL_RGBA,
                                                 width,
                                                 height,
                                                 GL_BGRA,
                                                 GL_UNSIGNED_BYTE,
                                                 0,
                                                 &imageTextureRef);
    _inputImageDrawable = [[QBGLDrawable alloc] initWithTextureRef:imageTextureRef identifier:@"inputImageTexture"];
    CFRelease(imageTextureRef);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (void)setAdditionalUniformVarsForRender {
    [self.program setParameter:"enableAnimationView" intValue:(self.enableAnimationView ? 1 : 0)];
    if (self.animationView) {
        [self.program enableAttributeWithId:self.attrInputAnimationCoordinate];
        glVertexAttribPointer(self.attrInputAnimationCoordinate, 2, GL_FLOAT, 0, 0, [self.class textureCoordinatesForRotation:_animationRotation]);
    }
}

- (void)updateDrawable {
    if (self.animationView) {
        [self.animationDrawable reloadView:self.animationView];
    }
}

- (void)renderDrawable:(QBGLDrawable *)drawable {
    if (!drawable) {
        return;
    }
    
    [self bindDrawable];
    
    [_program use];
    [_program enableAttributeWithId:_attrPosition];
    [_program enableAttributeWithId:_attrInputTextureCoordinate];
    
    glVertexAttribPointer(_attrPosition, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(_attrInputTextureCoordinate, 2, GL_FLOAT, 0, 0, [self.class textureCoordinatesForRotation:_inputRotation]);
    
    [self setAdditionalUniformVarsForRender];
    [self updateDrawable];
    
    [drawable prepareToDrawAtTextureIndex:0 program:_program];
}

- (GLuint)render {
    [_program use];
    [_program enableAttributeWithId:_attrPosition];
    [_program enableAttributeWithId:_attrInputTextureCoordinate];
    
    glVertexAttribPointer(_attrPosition, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(_attrInputTextureCoordinate, 2, GL_FLOAT, 0, 0, [self.class textureCoordinatesForRotation:_inputRotation]);
    
    [self setAdditionalUniformVarsForRender];
    [self updateDrawable];
    
    GLuint index = 0;
    if (_inputImageDrawable) {
        index = [_inputImageDrawable prepareToDrawAtTextureIndex:index program:_program];
    }
    for (QBGLDrawable *drawable in [self renderTextures]) {
        index = [drawable prepareToDrawAtTextureIndex:index program:_program];
    }
    return index;
}

- (void)bindDrawable {
    glBindFramebuffer(GL_FRAMEBUFFER, _outputFrameBuffer);
}

- (void)draw {
    glViewport(0, 0, _viewPortSize.width, _viewPortSize.height);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

#pragma mark - Private

- (void)loadOutputBuffer {
    NSDictionary* attrs = @{(__bridge NSString*) kCVPixelBufferIOSurfacePropertiesKey: @{}};
    CVPixelBufferCreate(kCFAllocatorDefault, _outputSize.width, _outputSize.height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef) attrs, &_outputPixelBuffer);
    
    CVOpenGLESTextureRef outputTextureRef;
    CVReturn error = kCVReturnSuccess;
    error = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                 _textureCacheRef,
                                                 _outputPixelBuffer,
                                                 NULL,
                                                 GL_TEXTURE_2D,
                                                 GL_RGBA,
                                                 _outputSize.width,
                                                 _outputSize.height,
                                                 GL_BGRA,
                                                 GL_UNSIGNED_BYTE,
                                                 0,
                                                 &outputTextureRef);
    if (error) {
        NSLog(@"Fail to create output texture!");
        return;
    }
    
    _outputTextureId = CVOpenGLESTextureGetName(outputTextureRef);
    [QBGLUtils bindTexture:_outputTextureId];
    CFRelease(outputTextureRef);
    
    // create output frame buffer
    glGenFramebuffers(1, &_outputFrameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _outputFrameBuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _outputTextureId, 0);
    
    // Bind RenderBuffer for depth test
    glGenRenderbuffers(1, &_depthRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _depthRenderBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, _outputSize.width, _outputSize.height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthRenderBuffer);
}

- (void)releaseUsages {
    [self unloadOutputBuffer];
    [self deleteTextures];
}

- (void)unloadOutputBuffer {
    if (_outputTextureId) {
        glDeleteTextures(1, &_outputTextureId);
    }
    if (_outputPixelBuffer) {
        CFRelease(_outputPixelBuffer);
        _outputPixelBuffer = NULL;
    }
    if (_outputFrameBuffer) {
        glDeleteFramebuffers(1, &_outputFrameBuffer);
    }
    
    if (_depthRenderBuffer) {
        glDeleteRenderbuffers(1, &_depthRenderBuffer);
    }
}

@end


char * const kQBNoFilterVertex = STRING
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

char * const kQBNoFilterFragment = STRING
(
 varying highp vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
);
