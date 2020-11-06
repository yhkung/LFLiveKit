//
//  QBGLPainterFilter.m
//  LFLiveKit
//
//  Created by Jan Chen on 2020/6/15.
//

#import "QBGLPainterFilter.h"
#import "QBGLDrawable.h"
#import "QBGLProgram.h"
#import "QBGLPainterRenderInfo.h"
#import <OpenGLES/ES1/gl.h>

char * const kQBPainterFilterVertex;
char * const kQBPainterFilterFragment;

@interface QBGLPainterFilter()

@property (strong, nonatomic) NSMutableDictionary<NSString *, QBGLDrawable *> *texturesMap;
@property (copy, nonatomic) NSArray<UIImage *> *images;
@property (copy, nonatomic) NSArray<QBGLPainterRenderInfo *> *painterRenderInfos;
@property (assign, nonatomic) int attrMatrix;
@property (assign, nonatomic) GLuint vertexBufferId;
@property (assign, nonatomic) GLuint paintingTextureId;
@property (assign, nonatomic) GLuint paintingFrameBuffer; // frameBuffer for painting points.
@property (strong, nonatomic) QBGLDrawable *paintingDrawable;
@property (strong, nonatomic) QBGLProgram *paintingProgram;

@end

@implementation QBGLPainterFilter

- (instancetype)init {
    if (self = [super init]) {
        self.vertexBufferId = 0;
        self.texturesMap = [[NSMutableDictionary alloc] init];
        
        self.paintingProgram = [[QBGLProgram alloc] initWithVertexShader:kQBPainterFilterVertex
                                                          fragmentShader:kQBPainterFilterFragment];
        
        self.attrMatrix = [self.paintingProgram uniformWithName:"MVP"];

        [self.program use];
        glGenTextures(1, &_paintingTextureId);
        glGenBuffers(1, &_vertexBufferId);
    }
    
    return self;
}

- (void)dealloc {
    [self cleanTexturesCache];
    [self releaseUsages];
}

#pragma mark - Private

- (void)printGLError:(int)number {
    if (glGetError()) {
        NSLog(@"[GL] Error : %d", number);
    }
}

- (void)setupPaintingFrameBuffer {
    self.paintingDrawable = [[QBGLDrawable alloc] initWithTextureId:self.paintingTextureId
                                                             identifier:@"inputImageTexture"];
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)self.outputSize.width, (int)self.outputSize.height, 0, GL_BGRA, GL_UNSIGNED_BYTE, NULL);
    glGenFramebuffers(1, &_paintingFrameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, self.paintingFrameBuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, self.paintingTextureId, 0);
}

- (void)setOutputSize:(CGSize)outputSize {
    if (CGSizeEqualToSize(outputSize, self.outputSize)) {
        return;
    }
    
    [super setOutputSize:outputSize];
    [self setupPaintingFrameBuffer];
}

- (void)cleanTexturesCache {
    /*
    for (QBGLDrawable *drawable in self.texturesMap.allValues) {
        [drawable deleteTexture];
    }
    
    [self.texturesMap removeAllObjects];
     */
}

- (void)renderPaths {
    glBindFramebuffer(GL_FRAMEBUFFER, _paintingFrameBuffer);
    [self.paintingProgram use];
    NSArray<QBGLPainterRenderInfo *> * paths = [self.painterRenderInfos copy];
    glViewport(0, 0, self.viewPortSize.width, self.viewPortSize.height);
    
    for (QBGLPainterRenderInfo *info in paths) {
        [self renderPath:info immediately:YES];
    }

    // it will cause crash if not unbind vbo.
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glFlush();
}

#pragma mark - Public

- (void)updatePathInfos:(NSArray<QBGLPainterRenderInfo *> *)infos {
    self.painterRenderInfos = [infos copy];
}

- (void)renderPath:(QBGLPainterRenderInfo *)info immediately:(BOOL)immediately {
    if (info.clear || info.redraw) {
        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        return;
    }
    
    CGPoint start = info.start;
    CGPoint end = info.end;

    int count = MAX((ceilf(sqrtf((end.x - start.x) * (end.x - start.x) + (end.y - start.y) * (end.y - start.y)) / (info.gap * 3))) + 1, 1);
    GLfloat *vertexBuffer = (GLfloat *) malloc(count * 2 * sizeof(GLfloat));

    CGRect frame = [QBGLUtils ratio16isTo9FillScreenRect];
    CGFloat width = frame.size.width / 2.0;
    CGFloat height = frame.size.height / 2.0;
    
    for (int i = 0 ; i < count ; i+= 2) {
        CGFloat x = start.x + (end.x - start.x) * ((CGFloat)i / (CGFloat)count);
        CGFloat y = start.y + (end.y - start.y) * ((CGFloat)i / (CGFloat)count);
        
        x = -((x / width) - 1.0);
        y = -((y / height) - 1.0);
        
        vertexBuffer[i] = (GLfloat)x;
        vertexBuffer[i+1] = (GLfloat)y;        
    }
    /* 暫時不用 bursh texture
    QBGLDrawable *brushTexture = self.texturesMap[info.textureName];

    if (!brushTexture) {
        UIImage *image = [UIImage imageNamed:info.textureName];
        if (image) {
            brushTexture = [[QBGLDrawable alloc] initWithImage:image identifier:@"texture"];
            self.texturesMap[info.textureName] = brushTexture;
        }
    }
    
    [brushTexture prepareToDrawAtTextureIndex:0 program:self.paintingProgram];
    */
    if (info.blend) {
        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    } else {
        glDisable(GL_BLEND);
        glColor4f(0, 0, 0, 0);
    }

    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBufferId);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertexBuffer), vertexBuffer, GL_DYNAMIC_DRAW);
    
    int positionSlot = [self.paintingProgram attributeWithName:"position"];
    [self.paintingProgram enableAttributeWithId:positionSlot];
    glVertexAttribPointer(positionSlot, 2, GL_FLOAT, GL_FALSE, 0, nil);
    
    [self.paintingProgram setParameter:"pointSize" floatValue:info.size * 6.0 * (self.outputSize.width/360.0)];

    int colorSlot = [self.paintingProgram uniformWithName:"vertexColor"];
    GLfloat color[] = {info.r, info.g, info.b, info.a * info.opacity};

    glUniform4fv(colorSlot, 1, color);
    glUniformMatrix4fv(self.attrMatrix, 1, GL_FALSE, GLKMatrix4Identity.m);
    
    if (immediately) {
        glDrawArrays(GL_POINTS, 0, count / 2);
    }
    
    free(vertexBuffer);
}

#pragma mark - Override

- (void)drawExternalContent {
    // 1. draw paths on painter frameBuffer, stored in paintingDrawable.
    [self renderPaths];
    // 2. draw paintingDrawable content on main frameBuffer.
    [self renderDrawable:self.paintingDrawable];
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

@end

#pragma mark - Shader

#define STRING(x) #x

char * const kQBPainterFilterVertex = STRING
(
 precision highp float;
 attribute vec4 position;
 uniform mat4 MVP;
 uniform float pointSize;
 uniform highp vec4 vertexColor;
 varying highp vec4 color;
 
 void main()
 {
    gl_Position = position * MVP;
    gl_PointSize = pointSize;
    color = vertexColor;
 }
);

char * const kQBPainterFilterFragment = STRING
(
 precision highp float;
 uniform sampler2D texture;
 varying highp vec4 color;
 
 void main()
 {
//    vec4 mainColor = color * texture2D(texture, gl_PointCoord);
    float r = distance(gl_PointCoord, vec2(0.5, 0.5));
    if (r >= 0.5) {
        discard;
    }
    gl_FragColor = color;
 }
);
