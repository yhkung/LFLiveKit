//
//  QBGLYuvFilter.m
//  LFLiveKit
//
//  Created by Ken Sun on 2018/2/1.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "QBGLYuvFilter.h"
#import "QBGLProgram.h"
#import "QBGLDrawable.h"

char * const kQBGLYuvFilterVertex;
char * const kQBGLYuvFilterFragment;

@interface QBGLYuvFilter ()
@property (strong, nonatomic) QBGLDrawable *yDrawable;
@property (strong, nonatomic) QBGLDrawable *uvDrawable;
@property (assign, nonatomic) NSTimeInterval time;

@end


@implementation QBGLYuvFilter

- (instancetype)init {
    return [self initWithVertexShader:kQBGLYuvFilterVertex fragmentShader:kQBGLYuvFilterFragment];
}

- (void)loadYUV:(CVPixelBufferRef)pixelBuffer {
    int width = (int) CVPixelBufferGetWidth(pixelBuffer);
    int height = (int) CVPixelBufferGetHeight(pixelBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    CVOpenGLESTextureRef luminanceTextureRef, chrominanceTextureRef;
    
    // y texture
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCacheRef, pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE, width, height, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
    
    _yDrawable = [[QBGLDrawable alloc] initWithTextureRef:luminanceTextureRef identifier:@"yTexture"];
    
    // uv texture
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCacheRef, pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, width/2, height/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
    
    _uvDrawable = [[QBGLDrawable alloc] initWithTextureRef:chrominanceTextureRef identifier:@"uvTexture"];
    
    CFRelease(luminanceTextureRef);
    CFRelease(chrominanceTextureRef);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    NSMutableArray *array = [NSMutableArray arrayWithArray:[super renderTextures]];
    if (self.yDrawable && self.uvDrawable ) {
        [array addObject:self.yDrawable];
        [array addObject:self.uvDrawable];
    }
    return [array copy];
}

- (void)setAdditionalUniformVarsForRender {
    [super setAdditionalUniformVarsForRender];
    
    if (self.hasSnowEffect) {
        if (self.time > FLT_EPSILON) {
            float time = [[NSDate date] timeIntervalSince1970] - self.time;
            int layers = MAX((int)time, 1);
            layers = MIN(layers, 15);
            [self.program setParameter:"iTime" floatValue:time];
            [self.program setParameter:"iLayers" intValue:layers];
        } else {
            self.time = [[NSDate date] timeIntervalSince1970];
            [self.program setParameter:"iTime" floatValue:0.0];
            [self.program setParameter:"iViewPortHeight" floatValue:self.viewPortSize.height];
        }
    } else {
        self.time = 0.0;
    }
    
    [self.program setParameter:"iSnowing" intValue:(int)self.hasSnowEffect];
}

@end


char * const kQBGLYuvFilterVertex = STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 varying vec2 textureCoordinate;
 
 attribute vec4 inputAnimationCoordinate;
 varying vec2 animationCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
     animationCoordinate = inputAnimationCoordinate.xy;
 }
 );

char * const kQBGLYuvFilterFragment = STRING
(
 precision highp float;
 
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D yTexture;
 uniform sampler2D uvTexture;
 
 varying highp vec2 animationCoordinate;
 uniform sampler2D animationTexture;
 uniform int enableAnimationView;
 uniform float iTime;
 uniform bool iSnowing;
 uniform int iLayers;
 uniform float iViewPortHeight;
 
 const mat3 yuv2rgbMatrix = mat3(1.0, 1.0, 1.0,
                                 0.0, -0.343, 1.765,
                                 1.4, -0.711, 0.0);
 
 const float DEPTH1 = .3;
 const float WIDTH1 = .1;
 const float SPEED1 = .6;
 const float DEPTH2 = .1;
 const float WIDTH2 = .3;
 const float SPEED2 = .1;
 
 vec3 rgbFromYuv(sampler2D yTexture, sampler2D uvTexture, vec2 textureCoordinate) {
     float y = texture2D(yTexture, textureCoordinate).r;
     float u = texture2D(uvTexture, textureCoordinate).r - 0.5;
     float v = texture2D(uvTexture, textureCoordinate).a - 0.5;
     return yuv2rgbMatrix * vec3(y, u, v);
 }
 
 float snowing(in vec2 uv, in vec2 fragCoord ) {
     const mat3 p = mat3(13.323122,23.5112,21.71123,21.1212,28.7312,11.9312,21.8112,14.7212,61.3934);
     //   vec2 mp = fragCoord.xy / vec2(360.0, 640.0);//iMouse.xy / iResolution.xy;
     vec2 mp = vec2(0.0);
     uv.x += mp.x*4.0;
     mp.y *= 0.25;
     float depth = smoothstep(DEPTH1, DEPTH2, mp.y);
     float width = smoothstep(WIDTH1, WIDTH2, mp.y);
     float speed = smoothstep(SPEED1, SPEED2, mp.y);
     float acc = 0.0;
     float dof = 5.0 * sin(iTime * 0.1);
     for (int i=0; i < iLayers; i++) {
         float fi = float(i);
         vec2 q = uv * (1.0 + fi*depth);
         float w = width * mod(fi*7.238917,1.0)-.05*sin(iTime*2.+fi);
         q += vec2(q.y*w, speed*iTime / (1.0+fi*depth*0.03));
         vec3 n = vec3(floor(q),31.189+fi);
         vec3 m = floor(n)*0.00001 + fract(n);
         vec3 mp = (31415.9+m) / fract(p*m);
         vec3 r = fract(mp);
         vec2 s = abs(mod(q,1.0) -0.5 +0.9*r.xy -0.45);
         s += 0.01*abs(2.0*fract(10.*q.yx)-1.);
         float d = 0.6*max(s.x-s.y,s.x+s.y)+max(s.x,s.y)-.01;
         float edge = 0.05 +0.05*min(.5*abs(fi-5.-dof),1.);
         acc += smoothstep(edge,-edge,d)*(r.x/(1.+.02*fi*depth));
     }
     
     return acc;
 }
 
 void main() {
     vec3 centralColor = rgbFromYuv(yTexture, uvTexture, textureCoordinate).rgb;
     vec4 animationColor = texture2D(animationTexture, animationCoordinate);
     vec4 tempColor = vec4(centralColor, 1.0);
     
     if (iSnowing) {
         vec2 transformCoord = vec2(gl_FragCoord.x, iViewPortHeight - gl_FragCoord.y);
         vec2 uv = transformCoord.xy / iViewPortHeight;
         float snowOut = snowing(uv,gl_FragCoord.xy);
         float move = iTime * 0.14;
         
         if (move > 1.0) {
             move = 1.0;
         }
         
         if (textureCoordinate.x <= move) {
             float alpha = ((move - textureCoordinate.x)/(move*0.35));
             tempColor += vec4(vec3(snowOut *alpha), 1.0);
         }
     }
     
     if (enableAnimationView == 1) {
         centralColor.r = animationColor.r + tempColor.r * (1.0 - animationColor.a);
         centralColor.g = animationColor.g + tempColor.g * (1.0 - animationColor.a);
         centralColor.b = animationColor.b + tempColor.b * (1.0 - animationColor.a);
         gl_FragColor = vec4(centralColor, 1.0);
     } else {
         gl_FragColor = tempColor;
     }
 }
 );
