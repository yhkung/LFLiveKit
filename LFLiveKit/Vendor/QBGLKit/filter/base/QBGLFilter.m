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

char * const kQBNoFilterVertex;
char * const kQBNoFilterFragment;

@interface QBGLFilter ()

@property (nonatomic) int attrPosition;
@property (nonatomic) int attrInputTextureCoordinate;

@property (strong, nonatomic) QBGLDrawable *inputImageDrawable;

@property (nonatomic) GLuint outputFrameBuffer;

@end

@implementation QBGLFilter

- (instancetype)init {
    return [self initWithVertexShader:kQBNoFilterVertex fragmentShader:kQBNoFilterFragment];
}

- (instancetype)initWithVertexShader:(const char *)vertexShader
                      fragmentShader:(const char *)fragmentShader {
    if (self = [super init]) {
        _program = [[QBGLProgram alloc] initWithVertexShader:vertexShader fragmentShader:fragmentShader];
        _attrPosition = [_program attributeWithName:"position"];
        _attrInputTextureCoordinate = [_program attributeWithName:"inputTextureCoordinate"];
        
        //[self setRotation:0 flipHorizontal:NO];
    }
    return self;
}

- (void)dealloc {
    [self deleteTextures];
    [self unloadOutputBuffer];
}

- (void)loadTextures {
    
}

- (void)deleteTextures {
    for (QBGLDrawable *drawable in [self renderTextures]) {
        [drawable deleteTexture];
    }
}

- (void)setOutputSize:(CGSize)outputSize {
    if (CGSizeEqualToSize(outputSize, _outputSize))
        return;
    _outputSize = outputSize;
    
    [self unloadOutputBuffer];
    [self loadOutputBuffer];
}

- (void)loadOutputBuffer {
    NSDictionary* attrs = @{(__bridge NSString*) kCVPixelBufferIOSurfacePropertiesKey: @{}};
    CVPixelBufferCreate(kCFAllocatorDefault, _outputSize.width, _outputSize.height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef) attrs, &_outputPixelBuffer);
    
    CVOpenGLESTextureRef outputTextureRef;
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
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
    _outputTextureId = CVOpenGLESTextureGetName(outputTextureRef);
    [QBGLUtils bindTexture:_outputTextureId];
    CFRelease(outputTextureRef);
    
    // create output frame buffer
    glGenFramebuffers(1, &_outputFrameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _outputFrameBuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _outputTextureId, 0);
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

- (void)loadTexture:(GLuint)textureId {
    _inputImageDrawable = [[QBGLDrawable alloc] initWithTextureId:textureId identifier:@"inputImageTexture"];
}

- (GLuint)renderAtIndex:(GLuint)index {
    [_program use];
    [_program enableAttributeWithId:_attrPosition];
    [_program enableAttributeWithId:_attrInputTextureCoordinate];
    
    glVertexAttribPointer(_attrPosition, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(_attrInputTextureCoordinate, 2, GL_FLOAT, 0, 0, [self.class textureCoordinatesForRotation:_inputRotation]);
    
    if (_inputImageDrawable) {
        index = [_inputImageDrawable prepareToDrawAtTextureIndex:index program:_program];
    }
    for (QBGLDrawable *drawable in [self renderTextures]) {
        index = [drawable prepareToDrawAtTextureIndex:index program:_program];
    }
    return index;
}

- (GLuint)render {
    return [self renderAtIndex:0];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return nil;
}

- (void)draw {
    glBindFramebuffer(GL_FRAMEBUFFER, _outputFrameBuffer);
    glViewport(0, 0, _outputSize.width, _outputSize.height);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void)setRotation:(float)degrees flipHorizontal:(BOOL)flip {
    GLKMatrix4 matrix = GLKMatrix4MakeZRotation(GLKMathDegreesToRadians(degrees));
    if (flip) {
        matrix = GLKMatrix4Multiply(matrix, GLKMatrix4MakeScale(-1.0, 1.0, 1.0));
    }
    glUniformMatrix4fv([_program uniformWithName:"transformMatrix"], 1, false, matrix.m);
}

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
    
    static const GLfloat rotateRightVerticalFlipTextureCoordinates[] = {
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat rotateRightHorizontalFlipTextureCoordinates[] = {
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
    };
    
    static const GLfloat rotate180TextureCoordinates[] = {
        1.0f, 1.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
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

char * const kQBNoFilterVertex = STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 //uniform mat4 transformMatrix;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     //gl_Position = position * transformMatrix;
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


