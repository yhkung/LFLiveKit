//
//  QBGLBeautyColorMapFilter.m
//  LFLiveKit
//
//  Created by Ken Sun on 2018/1/12.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "QBGLBeautyColorMapFilter.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"
#import "QBGLDrawable.h"

char *const kQBBeautyColorMapFilterVertex = STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 varying vec2 textureCoordinate;
 
 uniform vec2 singleStepOffset;
 
 attribute vec4 inputAnimationCoordinate;
 varying vec2 animationCoordinate;
 
 void main() {
     gl_Position = position;
     
     textureCoordinate = inputTextureCoordinate.xy;
     animationCoordinate = inputAnimationCoordinate.xy;
 }
 );


char * const kQBBeautyColorMapFilterFragment = STRING
(
 precision highp float;
 
 varying vec2 textureCoordinate;
 vec2 blurCoordinates[24];
 
 uniform vec2 singleStepOffset;
 uniform vec4 params;
 
 uniform sampler2D yTexture;
 uniform sampler2D uvTexture;
 
 uniform sampler2D colorMapTexture; // mandatory
 uniform sampler2D overlayTexture1; // optional
 uniform sampler2D overlayTexture2; // optional
 
 uniform float filterMixPercentage;
 uniform int overlay1Enabled;
 uniform int overlay2Enabled;
 
 varying highp vec2 animationCoordinate;
 uniform sampler2D animationTexture;
 uniform int enableAnimationView;
 
 const vec3 W = vec3(0.299, 0.587, 0.114);
 const mat3 saturateMatrix = mat3(1.1102, -0.0598, -0.061,
                                  -0.0774, 1.0826, -0.1186,
                                  -0.0228, -0.0228, 1.1772);
 
 const mat3 yuv2rgbMatrix = mat3(1.0, 1.0, 1.0,
                                 0.0, -0.343, 1.765,
                                 1.4, -0.711, 0.0);
 
 /* Snow Parameters */
 uniform float iTime;
 uniform bool iSnowing;
 uniform int iLayers;
 uniform float iViewPortHeight;
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
 
 float hardLight(float color) {
     if (color <= 0.5)
         color = color * color * 2.0;
     else
         color = 1.0 - ((1.0 - color)*(1.0 - color) * 2.0);
     return color;
 }
 
 vec3 applyColorMap(vec3 inputTexture, sampler2D colorMap) {
     float size = 33.0;
     
     float sliceSize = 1.0 / size;
     float slicePixelSize = sliceSize / size;
     float sliceInnerSize = slicePixelSize * (size - 1.0);
     float xOffset = 0.5 * sliceSize + inputTexture.x * (1.0 - sliceSize);
     float yOffset = 0.5 * slicePixelSize + inputTexture.y * sliceInnerSize;
     float zOffset = inputTexture.z * (size - 1.0);
     float zSlice0 = floor(zOffset);
     float zSlice1 = zSlice0 + 1.0;
     float s0 = yOffset + (zSlice0 * sliceSize);
     float s1 = yOffset + (zSlice1 * sliceSize);
     vec4 sliceColor0 = texture2D(colorMap, vec2(xOffset, s0));
     vec4 sliceColor1 = texture2D(colorMap, vec2(xOffset, s1));
     
     return mix(sliceColor0, sliceColor1, zOffset - zSlice0).rgb;
 }
 
 float softLightCal(float a, float b){
     if(b<.5)
         return 2.*a*b+a*a*(1.-2.*b);
     else
         return 2.*a*(1.-b)+sqrt(a)*(2.*b-1.);
     
     return 0.;
 }
 
 float overlayCal(float a, float b){
     if(a<.5)
         return 2.*a*b;
     else
         return 1.-2.*(1.-a)*(1.-b);
     
     return 0.;
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
 
 void main(){
     vec3 centralColor = rgbFromYuv(yTexture, uvTexture, textureCoordinate).rgb;
     blurCoordinates[0] = textureCoordinate.xy + singleStepOffset * vec2(0.0, -10.0);
     blurCoordinates[1] = textureCoordinate.xy + singleStepOffset * vec2(0.0, 10.0);
     blurCoordinates[2] = textureCoordinate.xy + singleStepOffset * vec2(-10.0, 0.0);
     blurCoordinates[3] = textureCoordinate.xy + singleStepOffset * vec2(10.0, 0.0);
     blurCoordinates[4] = textureCoordinate.xy + singleStepOffset * vec2(5.0, -8.0);
     blurCoordinates[5] = textureCoordinate.xy + singleStepOffset * vec2(5.0, 8.0);
     blurCoordinates[6] = textureCoordinate.xy + singleStepOffset * vec2(-5.0, 8.0);
     blurCoordinates[7] = textureCoordinate.xy + singleStepOffset * vec2(-5.0, -8.0);
     blurCoordinates[8] = textureCoordinate.xy + singleStepOffset * vec2(8.0, -5.0);
     blurCoordinates[9] = textureCoordinate.xy + singleStepOffset * vec2(8.0, 5.0);
     blurCoordinates[10] = textureCoordinate.xy + singleStepOffset * vec2(-8.0, 5.0);
     blurCoordinates[11] = textureCoordinate.xy + singleStepOffset * vec2(-8.0, -5.0);
     blurCoordinates[12] = textureCoordinate.xy + singleStepOffset * vec2(0.0, -6.0);
     blurCoordinates[13] = textureCoordinate.xy + singleStepOffset * vec2(0.0, 6.0);
     blurCoordinates[14] = textureCoordinate.xy + singleStepOffset * vec2(6.0, 0.0);
     blurCoordinates[15] = textureCoordinate.xy + singleStepOffset * vec2(-6.0, 0.0);
     blurCoordinates[16] = textureCoordinate.xy + singleStepOffset * vec2(-4.0, -4.0);
     blurCoordinates[17] = textureCoordinate.xy + singleStepOffset * vec2(-4.0, 4.0);
     blurCoordinates[18] = textureCoordinate.xy + singleStepOffset * vec2(4.0, -4.0);
     blurCoordinates[19] = textureCoordinate.xy + singleStepOffset * vec2(4.0, 4.0);
     blurCoordinates[20] = textureCoordinate.xy + singleStepOffset * vec2(-2.0, -2.0);
     blurCoordinates[21] = textureCoordinate.xy + singleStepOffset * vec2(-2.0, 2.0);
     blurCoordinates[22] = textureCoordinate.xy + singleStepOffset * vec2(2.0, -2.0);
     blurCoordinates[23] = textureCoordinate.xy + singleStepOffset * vec2(2.0, 2.0);
     
     float sampleColor = centralColor.g * 22.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[0]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[1]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[2]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[3]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[4]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[5]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[6]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[7]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[8]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[9]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[10]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[11]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[12]).g * 2.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[13]).g * 2.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[14]).g * 2.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[15]).g * 2.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[16]).g * 2.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[17]).g * 2.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[18]).g * 2.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[19]).g * 2.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[20]).g * 3.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[21]).g * 3.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[22]).g * 3.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[23]).g * 3.0;
     
     sampleColor = sampleColor / 62.0;
     
     float highPass = centralColor.g - sampleColor + 0.5;
     
     for (int i = 0; i < 5; i++) {
         highPass = hardLight(highPass);
     }
     float lumance = dot(centralColor, W);
     
     float alpha = pow(lumance, params.r);
     
     vec3 smoothColor = centralColor + (centralColor-vec3(highPass))*alpha*0.1;
     
     smoothColor.r = clamp(pow(smoothColor.r, params.g), 0.0, 1.0);
     smoothColor.g = clamp(pow(smoothColor.g, params.g), 0.0, 1.0);
     smoothColor.b = clamp(pow(smoothColor.b, params.g), 0.0, 1.0);
     
     // 濾色 Screen
     vec3 lvse = vec3(1.0)-(vec3(1.0)-smoothColor)*(vec3(1.0)-centralColor);
     // 變亮 Lighten
     vec3 bianliang = max(smoothColor, centralColor);
     // 柔光 SoftLight
     vec3 rouguang = 2.0*centralColor*smoothColor + centralColor*centralColor - 2.0*centralColor*centralColor*smoothColor;
     
     vec3 beautyColor = mix(centralColor, lvse, alpha);
     beautyColor = mix(beautyColor, bianliang, alpha);
     beautyColor = mix(beautyColor, rouguang, params.b);
     
     // 調節飽和度
     vec3 satcolor = beautyColor * saturateMatrix;
     beautyColor = mix(beautyColor, satcolor, params.a);
     
     vec3 filter_result = applyColorMap(beautyColor, colorMapTexture);
     
     if (overlay1Enabled == 1) {
         vec3 overlay_image1 = texture2D(overlayTexture1, textureCoordinate).rgb;
         
         filter_result = vec3(softLightCal(filter_result.r, overlay_image1.r),
                              softLightCal(filter_result.g, overlay_image1.g),
                              softLightCal(filter_result.b, overlay_image1.b));
         
         filter_result = clamp(filter_result, 0.0, 1.0);
     }
     if (overlay2Enabled == 1) {
         vec3 overlay_image2 = texture2D(overlayTexture2, textureCoordinate).rgb;
         
         filter_result = vec3(overlayCal(filter_result.r, overlay_image2.r),
                              overlayCal(filter_result.g, overlay_image2.g),
                              overlayCal(filter_result.b, overlay_image2.b));
         
         filter_result = clamp(filter_result, 0.0, 1.0);
     }
     
     filter_result = mix(beautyColor, filter_result, filterMixPercentage);
     
     vec4 tempColor = vec4(filter_result, 1.0);
     
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

     vec4 animationColor = texture2D(animationTexture, animationCoordinate);
     if (enableAnimationView == 1) {
         filter_result.r = animationColor.r + tempColor.r * (1.0 - animationColor.a);
         filter_result.g = animationColor.g + tempColor.g * (1.0 - animationColor.a);
         filter_result.b = animationColor.b + tempColor.b * (1.0 - animationColor.a);
         gl_FragColor = vec4(filter_result, 1.0);
     } else {
         gl_FragColor = tempColor;
     }
 }
 
 );

@implementation QBGLBeautyColorMapFilter

- (instancetype)init {
    if (self = [super initWithVertexShader:kQBBeautyColorMapFilterVertex fragmentShader:kQBBeautyColorMapFilterFragment]) {
        [self loadTextures];
        [self setBeautyParams];
    }
    return self;
}

- (void)setInputSize:(CGSize)inputSize {
    [super setInputSize:inputSize];
    const GLfloat offset[] = {2.0 / self.inputSize.width, 2.0 / self.inputSize.height};
    glUniform2fv([self.program uniformWithName:"singleStepOffset"], 1, offset);
}

- (void)setBeautyParams {
    const GLfloat params[] = {0.33f, 0.63f, 0.4f, 0.35f};
    glUniform4fv([self.program uniformWithName:"params"], 1, params);
}

@end
