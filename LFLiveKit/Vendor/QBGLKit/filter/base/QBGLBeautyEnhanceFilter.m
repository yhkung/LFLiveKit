//
//  QBGLBeautyEnhanceFilter.m
//  LFLiveKit
//
//  Created by Ken Sun on 2018/2/1.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "QBGLBeautyEnhanceFilter.h"
#import "QBGLProgram.h"
#import "QBGLDrawable.h"

char *const kQBGLBeautyEnhanceFilterVertex;
char * const kQBGLBeautyEnhanceFilterFragment;

@implementation QBGLBeautyEnhanceFilter

- (instancetype)init {
    if (self = [super initWithVertexShader:kQBGLBeautyEnhanceFilterVertex fragmentShader:kQBGLBeautyEnhanceFilterFragment]) {
        [self setSharpness:0.5];
        [self setTemperature:4700];
        [self setTint:0.0];
        [self setBeta:2.0];
    }
    return self;
}

- (void)setInputSize:(CGSize)inputSize {
    [super setInputSize:inputSize];
    const GLfloat offset[] = {1.0 / self.inputSize.width, 1.0 / self.inputSize.height};
    glUniform2fv([self.program uniformWithName:"singleStepOffset"], 1, offset);
}

- (void)setSharpness:(float)value {
    glUniform1f([self.program uniformWithName:"sharpness"], value);
}

- (void)setTemperature:(float)value {
    value = value < 5000 ? 0.0004 * (value-5000.0) : 0.00006 * (value-5000.0);
    glUniform1f([self.program uniformWithName:"temperature"], value);
}

- (void)setTint:(float)value {
    value /= 100.0;
    glUniform1f([self.program uniformWithName:"tint"], value);
}

- (void)setBeta:(float)value {
    glUniform1f([self.program uniformWithName:"beta"], value);
}

@end


char *const kQBGLBeautyEnhanceFilterVertex = STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 //uniform mat4 transformMatrix;
 uniform float sharpness;
 
 uniform vec2 singleStepOffset;
 varying vec2 sharpCoordinates[4];
 
 varying vec2 textureCoordinate;
 
 varying float sharpCenterMultiplier;
 varying float sharpEdgeMultiplier;
 
 void main() {
     //gl_Position = position * transformMatrix;
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
     
     sharpCoordinates[0] = inputTextureCoordinate.xy - vec2(singleStepOffset.x, 0.0);
     sharpCoordinates[1] = inputTextureCoordinate.xy + vec2(singleStepOffset.x, 0.0);
     sharpCoordinates[2] = inputTextureCoordinate.xy + vec2(0.0, singleStepOffset.y);
     sharpCoordinates[3] = inputTextureCoordinate.xy - vec2(0.0, singleStepOffset.y);
     
     sharpCenterMultiplier = 1.0 + 4.0 * sharpness;
     sharpEdgeMultiplier = sharpness;
 }
 );


char * const kQBGLBeautyEnhanceFilterFragment = STRING
(
 precision highp float;
 
 varying vec2 textureCoordinate;
 
 varying vec2 sharpCoordinates[4];
 
 uniform vec2 singleStepOffset;
 
 uniform lowp float temperature;
 uniform lowp float tint;
 uniform highp float beta;
 
 uniform sampler2D inputImageTexture;
 
 varying highp float sharpCenterMultiplier;
 varying highp float sharpEdgeMultiplier;
 
 const lowp vec3 warmFilter = vec3(0.93, 0.54, 0.0);
 const mediump mat3 RGBtoYIQ = mat3(0.299, 0.587, 0.114, 0.596, -0.274, -0.322, 0.212, -0.523, 0.311);
 const mediump mat3 YIQtoRGB = mat3(1.0, 0.956, 0.621, 1.0, -0.272, -0.647, 1.0, -1.105, 1.702);

 void main() {
     vec3 centralColor = texture2D(inputImageTexture, textureCoordinate).rgb;
     
     // 銳化
     vec3 sharpenColor = centralColor * sharpCenterMultiplier;
     sharpenColor -= texture2D(inputImageTexture, sharpCoordinates[0]).rgb * sharpEdgeMultiplier;
     sharpenColor -= texture2D(inputImageTexture, sharpCoordinates[1]).rgb * sharpEdgeMultiplier;
     sharpenColor -= texture2D(inputImageTexture, sharpCoordinates[2]).rgb * sharpEdgeMultiplier;
     sharpenColor -= texture2D(inputImageTexture, sharpCoordinates[3]).rgb * sharpEdgeMultiplier;
     
     // 白平衡
     mediump vec3 yiq = RGBtoYIQ * sharpenColor; //adjusting tint
     yiq.b = clamp(yiq.b + tint*0.5226*0.1, -0.5226, 0.5226);
     lowp vec3 rgb = YIQtoRGB * yiq;
     
     lowp vec3 processed = vec3(
                                (rgb.r < 0.5 ? (2.0 * rgb.r * warmFilter.r) : (1.0 - 2.0 * (1.0 - rgb.r) * (1.0 - warmFilter.r))), //adjusting temperature
                                (rgb.g < 0.5 ? (2.0 * rgb.g * warmFilter.g) : (1.0 - 2.0 * (1.0 - rgb.g) * (1.0 - warmFilter.g))),
                                (rgb.b < 0.5 ? (2.0 * rgb.b * warmFilter.b) : (1.0 - 2.0 * (1.0 - rgb.b) * (1.0 - warmFilter.b))));
     
     vec3 wBalanceColor = mix(rgb, processed, temperature);
     
     // 美白
     vec3 whitenColor = log(wBalanceColor * (beta - 1.0) + 1.0) / log(beta);
     
     gl_FragColor = vec4(whitenColor, 1.0);
 }
 
 );
