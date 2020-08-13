//
//  QBGLTexturesFilter.m
//  LFLiveKit
//
//  Created by Jan Chen on 2020/5/7.
//

#import "QBGLTexturesFilter.h"
#import "QBGLDrawable.h"
#import "QBGLProgram.h"
#import "QBGLTextureRenderInfo.h"

char * const kQBTexturesFilterVertex;
char * const kQBTexturesFilterFragment;

@interface QBGLTexturesFilter()

@property (strong, nonatomic) NSMutableDictionary<NSString *, QBGLDrawable *> *texturesMap;
@property (assign, nonatomic) int attrMatrix;
@property (copy, nonatomic) NSArray<UIImage *> *images;
@property (copy, nonatomic) NSArray<QBGLTextureRenderInfo *> *textureRenderInfos;

@end

@implementation QBGLTexturesFilter

#pragma mark - Life Cycle

- (instancetype)init {
    if (self = [super initWithVertexShader:kQBTexturesFilterVertex fragmentShader:kQBTexturesFilterFragment]) {
        self.attrMatrix = [self.program uniformWithName:"u_Matrix"];
        self.texturesMap = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (void)dealloc {
    [self cleanTexturesCache];
    [self releaseUsages];
}

#pragma mark - Accessor

// clean textures cache when this filter is stopped
- (void)setShouldRender:(BOOL)shouldRender {
    [super setShouldRender:shouldRender];
    
    if (!shouldRender) {
        [self cleanTexturesCache];
    }
}

#pragma mark - Public

- (void)updateTextures:(NSArray<QBGLTextureRenderInfo *> *)infos {
    _textureRenderInfos = [infos copy];
}

#pragma mark - Private

- (void)cleanTexturesCache {
    for (QBGLDrawable *drawable in self.texturesMap.allValues) {
        [drawable deleteTexture];
    }
    
    [self.texturesMap removeAllObjects];
}

- (void)renderTextureInfos {
    if (!self.shouldRender || self.textureRenderInfos.count == 0) {
        return;
    }
    
    glClear(GL_DEPTH_BUFFER_BIT);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
    
    NSArray *infos = [self.textureRenderInfos copy];
    
    for (QBGLTextureRenderInfo *obj in infos) {
        if (obj.imageName.length == 0) {
            continue;
        }
        
        QBGLDrawable *drawalbe = self.texturesMap[obj.imageName];
        
        if (!drawalbe) {
            drawalbe = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:obj.imageName] identifier:@"inputImageTexture"];
            self.texturesMap[obj.imageName] = drawalbe;
        }
        
        [drawalbe prepareToDrawAtTextureIndex:0 program:self.program];
        
        /*
         obj.zOrder有可能是0,
         如果是 1.0 - 0 = 1.0, 則無法通過深度測試,
         需要減掉0.01讓其少於1.0,
         並且不小於0.01.
         */
        CGFloat zPosition = MAX(1.0 - obj.zOrder - 0.01 , 0.01);
        GLKMatrix4 translate = GLKMatrix4Translate(GLKMatrix4Identity,
                                                   obj.position.x,
                                                   obj.position.y,
                                                   zPosition);
        GLKMatrix4 scale = GLKMatrix4Scale(translate, obj.size.width, obj.size.height, 1.0);
        GLKMatrix4 rotation = GLKMatrix4RotateZ(scale, obj.rotation);
        
        [self.program setParameter:"iAlpha" floatValue:obj.alpha];

        glUniformMatrix4fv(self.attrMatrix, 1, GL_FALSE, rotation.m);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
    
    glDisable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);
}

#pragma mark - Override

- (void)prepareSetup {
    glUniformMatrix4fv(self.attrMatrix, 1, GL_FALSE, GLKMatrix4Identity.m);
}

- (void)drawExternalContent {
    [self renderTextureInfos];
}

@end

#pragma mark - Shader

#define STRING(x) #x

char * const kQBTexturesFilterVertex = STRING
(
 uniform mat4 u_Matrix;
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 varying vec2 textureCoordinate;
 
 void main()
 {
    gl_Position = u_Matrix * position;
    textureCoordinate = inputTextureCoordinate.xy;
 }
);

char * const kQBTexturesFilterFragment = STRING
(
 precision highp float;
 
 uniform sampler2D inputImageTexture;
 varying highp vec2 textureCoordinate;
 uniform float iAlpha;
 
 void main() {
    vec4 val = texture2D(inputImageTexture, textureCoordinate);

    /*
     關於此discard作法
     
     Why:
        直接使用texture當成gl_FragColor的話, 會連透明pixel一起render上去,
        會讓透明pixel的部分蓋到其他texture.
     
     How:
        判斷此pixel的alpha >= 0.1 才Render pixel,
        所以會render出 0.1 ~ 1.0 的 pixel, 其餘disacrd (不做事)
        但如果只這樣做會無法呈現node本身圖片的alpha值, 必須考慮原本node的alpha值,
        當這個node需要漸淡時, node本身的alpha會從1.0慢慢降到0.1,
        但是在render時只看pixel本身的alpha, 所以無法呈現漸淡.
        解決方法是pixel alpha 乘上 node本身alpha,
        例如pixel為1, node正在淡出, node alpha為0.3,
        此時此pixel的alpha為 1 * 0.3 = 0.3
    */
    
    if (val.a >= 0.1) {
        gl_FragColor = vec4(val.rgb, iAlpha * val.a);
    } else {
        discard;
    }
});
