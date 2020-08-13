//
//  QBGLContext.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/21.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLContext.h"
#import "QBGLFilterFactory.h"
#import "QBGLProgram.h"
#import "QBGLUtils.h"
#import "QBGLBeautyFilter.h"
#import "QBGLBeautyColorMapFilter.h"
#import "QBGLMagicFilterBase.h"
#import "QBGLMagicFilterFactory.h"
#import "QBGLTexturesFilter.h"
#import "QBGLPainterFilter.h"
#import "QBGLTextureRenderInfo.h"
#import "QBGLPainterRenderInfo.h"
#import "QBGLExtFilter.h"
#import "QBGLExtFilterFactory.h"

@interface QBGLContext ()

@property (copy, nonatomic) NSArray<__kindof QBGLExtFilter *> *extFilterGroup;
@property (copy, nonatomic) NSArray<__kindof QBGLExtFilter *> *extFilterGroupForRender;
@property (strong, nonatomic) __kindof QBGLExtFilter *lastExtRenderFilter;
@property (assign, nonatomic) QBGLFilterType colorFilterTypeForRender;

@property (nonatomic, readonly) QBGLYuvFilter *filter;
@property (nonatomic, readonly) QBGLYuvFilter *inputFilter;
@property (nonatomic, readonly) QBGLFilter *outputFilter;

@property (strong, nonatomic) QBGLYuvFilter *normalFilter;
@property (strong, nonatomic) QBGLBeautyFilter *beautyFilter;
@property (strong, nonatomic) QBGLColorMapFilter *colorFilter;
@property (strong, nonatomic) QBGLBeautyColorMapFilter *beautyColorFilter;

@property (strong, nonatomic) QBGLMagicFilterFactory *magicFilterFactory;
@property (strong, nonatomic) QBGLMagicFilterBase *magicFilter;

@property (nonatomic) QBGLImageRotation inputRotation;
@property (nonatomic) QBGLImageRotation previewInputRotation;
@property (nonatomic) QBGLImageRotation previewAnimationRotation;

@property (nonatomic) CVOpenGLESTextureCacheRef textureCacheRef;
@property (assign, nonatomic) BOOL hasSnowEffect;

@end

@implementation QBGLContext

- (instancetype)init {
    return [self initWithContext:nil animationView:nil];
}

- (instancetype)initWithContext:(EAGLContext *)context
                  animationView:(UIView *)animationView {
    if (context.API == kEAGLRenderingAPIOpenGLES1)
        @throw [NSException exceptionWithName:@"QBGLContext init error" reason:@"GL context  can't be kEAGLRenderingAPIOpenGLES1" userInfo:nil];
    if (self = [super init]) {
        _glContext = context ?: [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];;
        _animationView = animationView;
        [self becomeCurrentContext];
    }
    return self;
}

- (void)dealloc {
    [self becomeCurrentContext];
    CFRelease(_textureCacheRef);
    
    [EAGLContext setCurrentContext:nil];
    
    [_magicFilterFactory clearCache];
}

- (CVPixelBufferRef)outputPixelBuffer {
    if (self.lastExtRenderFilter) {
        return self.lastExtRenderFilter.outputPixelBuffer;
    }

    return self.outputFilter.outputPixelBuffer;
}

- (QBGLMagicFilterFactory *)magicFilterFactory {
    if (!_magicFilterFactory) {
        _magicFilterFactory = [[QBGLMagicFilterFactory alloc] init];
    }
    return _magicFilterFactory;
}

- (QBGLYuvFilter *)normalFilter {
    if (!_normalFilter) {
        _normalFilter = [[QBGLYuvFilter alloc] initWithAnimationView:self.animationView];
        _normalFilter.textureCacheRef = _textureCacheRef;
    }
    return _normalFilter;
}

- (QBGLBeautyFilter *)beautyFilter {
    if (!_beautyFilter) {
        _beautyFilter = [[QBGLBeautyFilter alloc] initWithAnimationView:self.animationView];
        _beautyFilter.textureCacheRef = _textureCacheRef;
    }
    return _beautyFilter;
}

- (QBGLColorMapFilter *)colorFilter {
    if (!_colorFilter) {
        _colorFilter = [[QBGLColorMapFilter alloc] initWithAnimationView:self.animationView];
        _colorFilter.textureCacheRef = _textureCacheRef;
    }
    if (_colorFilter.type != _colorFilterTypeForRender) {
        [QBGLFilterFactory refactorColorFilter:_colorFilter withType:_colorFilterTypeForRender];
        _colorFilter.type = _colorFilterTypeForRender;
    }
    return _colorFilter;
}

- (QBGLBeautyColorMapFilter *)beautyColorFilter {
    if (!_beautyColorFilter) {
        _beautyColorFilter = [[QBGLBeautyColorMapFilter alloc] initWithAnimationView:self.animationView];
        _beautyColorFilter.textureCacheRef = _textureCacheRef;
    }
    if (_beautyColorFilter.type != _colorFilterTypeForRender) {
        [QBGLFilterFactory refactorColorFilter:_beautyColorFilter withType:_colorFilterTypeForRender];
        _beautyColorFilter.type = _colorFilterTypeForRender;
    }
    return _beautyColorFilter;
}

- (QBGLMagicFilterBase *)magicFilter {
    if (!_magicFilter || (_colorFilterTypeForRender != QBGLFilterTypeNone && _magicFilter.type != _colorFilterTypeForRender)) {
        _magicFilter = [self.magicFilterFactory filterWithType:_colorFilterTypeForRender animationView:self.animationView];
    }
    return _magicFilter;
}

- (QBGLYuvFilter *)filter {
    BOOL colorFilterType17 = (_colorFilterTypeForRender > QBGLFilterTypeNone && _colorFilterTypeForRender < QBGLFilterTypeFairytale);
    if (_beautyEnabled && _colorFilterTypeForRender != QBGLFilterTypeNone) {
        return (colorFilterType17 ? self.beautyColorFilter : self.beautyFilter);
    } else if (_beautyEnabled && _colorFilterTypeForRender == QBGLFilterTypeNone) {
        return self.beautyFilter;
    } else if (!_beautyEnabled && _colorFilterTypeForRender != QBGLFilterTypeNone) {
        return (colorFilterType17 ? self.colorFilter : self.normalFilter);
    } else {
        return self.normalFilter;
    }
}

- (QBGLYuvFilter *)inputFilter {
    return self.filter;
}

- (QBGLFilter *)outputFilter {
    BOOL colorFilterTypeMagic = (_colorFilterTypeForRender >= QBGLFilterTypeFairytale && _colorFilterTypeForRender <= QBGLFilterTypeWalden);
    return (colorFilterTypeMagic ? self.magicFilter : self.filter);
}

- (void)becomeCurrentContext {
    if ([EAGLContext currentContext] != _glContext) {
        [EAGLContext setCurrentContext:_glContext];
    }
}

- (void)reloadTextureCache {
    [self becomeCurrentContext];
    
    if (_textureCacheRef) {
        CFRelease(_textureCacheRef);
    }
    
    CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _glContext, NULL, &_textureCacheRef);
    
    self.normalFilter.textureCacheRef = _textureCacheRef;
    self.beautyFilter.textureCacheRef = _textureCacheRef;
    self.colorFilter.textureCacheRef = _textureCacheRef;
    self.beautyColorFilter.textureCacheRef = _textureCacheRef;
    
    [self.magicFilterFactory preloadFiltersWithTextureCacheRef:_textureCacheRef animationView:_animationView];
    [self setFilterGroupTextureCache:_textureCacheRef];
}

- (void)loadYUVPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    [self becomeCurrentContext];
    self.inputFilter.inputSize = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
    [self.inputFilter loadYUV:pixelBuffer];
}

- (void)loadBGRAPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    [self becomeCurrentContext];
    self.inputFilter.inputSize = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
    [self.inputFilter loadBGRA:pixelBuffer];
}

- (void)render {
    [self becomeCurrentContext];
    
    // Prefer magic filter to draw animation view texture than other filters because magic filter's z-order is upper than other filters
    BOOL hasMagicFilter = self.hasMagicFilter;
    BOOL hasMultiFilters = self.hasMultiFilters;
    self.inputFilter.enableAnimationView = (self.animationView != nil && !hasMagicFilter);
    self.inputFilter.inputRotation = self.inputRotation;
    self.inputFilter.animationRotation = QBGLImageRotationNone;
    self.inputFilter.hasSnowEffect = self.hasSnowEffect;
    [self.inputFilter bindDrawable];
    [self.inputFilter render];
    
    if (hasMultiFilters) {
        [self.inputFilter draw];
        GLuint textureId = self.inputFilter.outputTextureId;
        self.outputFilter.enableAnimationView = (self.animationView != nil && hasMagicFilter);
        self.outputFilter.animationRotation = QBGLImageRotationNone;
        [self.outputFilter loadTexture:textureId];
        [self.outputFilter render];
    }
}

- (void)updateExtFilter:(NSArray<NSObject *> *)infos type:(QBGLExtFilterType)type {
    for (QBGLExtFilter *filter in self.extFilterGroupForRender) {
        if (filter.filterType == type) {
            switch (type) {
                case QBGLExtFilterTypeNone: break;
                case QBGLExtFilterTypePainter: {
                    if (infos.count > 0 &&
                        [infos isKindOfClass:[NSArray<QBGLPainterRenderInfo *> class]]) {
                        [((QBGLPainterFilter *)filter) updatePathInfos:infos];
                    } else {
                        [((QBGLPainterFilter *)filter) updatePathInfos:nil];
                    }
                } break;
                case QBGLExtFilterTypeBoxes:
                case QBGLExtFilterTypeGame: {
                    if (infos.count > 0 &&
                        [infos isKindOfClass:[NSArray<QBGLTextureRenderInfo *> class]]) {
                        [((QBGLTexturesFilter *)filter) updateTextures:infos];
                    } else {
                        [((QBGLTexturesFilter *)filter) updateTextures:nil];
                    }
                } break;
            }
            break;
        }
    }
}

- (void)enableExtFilterRender:(QBGLExtFilterType)type enable:(BOOL)enable {
    for (QBGLExtFilter *filter in self.extFilterGroup) {
        if (filter.filterType == type) {
            filter.shouldRender = enable;
        }
    }
}

- (void)renderToOutput {
    [self render];
    [self.outputFilter bindDrawable];
    [self.outputFilter draw];
    [self renderToExtFilterGroup];

    glFlush();
}

- (void)renderToExtFilterGroup {
    if ([self isFilterGroupEmpty]) {
        if (self.lastExtRenderFilter != nil) {
            self.lastExtRenderFilter = nil;
        }
        
        return;
    }
    
    __kindof QBGLExtFilter *lastExtFilter = nil;
    __kindof QBGLFilter *sourceFilter = self.outputFilter;
    
    [self becomeCurrentContext];
    
    for (int i = 0; i < self.extFilterGroupForRender.count; i++) {
        __kindof QBGLExtFilter *filter = self.extFilterGroupForRender[i];
        if (!filter.shouldRender) {
            continue;
        }
        
        // 拿到前個 filter 結果的 texture ID
        GLuint textureId = sourceFilter.outputTextureId;
        
        // 載入 texture 並且畫出
        [filter loadTexture:textureId];
        [filter render];
        [filter bindDrawable];
        [filter prepareSetup];
        [filter draw];
        [filter drawExternalContent];
        
        // 更新下一個 source filter
        sourceFilter = filter;
        lastExtFilter = filter;
    }
    
    self.lastExtRenderFilter = lastExtFilter;
}

- (void)setDisplayOrientation:(UIInterfaceOrientation)orientation cameraPosition:(AVCaptureDevicePosition)position mirror:(BOOL)mirror {
    if (position == AVCaptureDevicePositionBack) {
        _inputRotation =
        orientation == UIInterfaceOrientationPortrait           ? (mirror ? QBGLImageRotationRightFlipHorizontal : QBGLImageRotationRight) :
        orientation == UIInterfaceOrientationPortraitUpsideDown ? (mirror ? QBGLImageRotationLeftFlipHorizontal  : QBGLImageRotationLeft)  :
        orientation == UIInterfaceOrientationLandscapeLeft      ? (mirror ? QBGLImageRotation180FlipHorizontal   : QBGLImageRotation180)   :
        orientation == UIInterfaceOrientationLandscapeRight     ? (mirror ? QBGLImageRotationFlipHorizonal       : QBGLImageRotationNone)  :
        QBGLImageRotationNone;
    } else {
        _inputRotation =
        orientation == UIInterfaceOrientationPortrait           ? (mirror ? QBGLImageRotationRightFlipHorizontal : QBGLImageRotationRight) :
        orientation == UIInterfaceOrientationPortraitUpsideDown ? (mirror ? QBGLImageRotationLeftFlipHorizontal  : QBGLImageRotationLeft)  :
        orientation == UIInterfaceOrientationLandscapeLeft      ? (mirror ? QBGLImageRotationFlipHorizonal       : QBGLImageRotationNone)  :
        orientation == UIInterfaceOrientationLandscapeRight     ? (mirror ? QBGLImageRotation180FlipHorizontal   : QBGLImageRotation180)   :
        QBGLImageRotationNone;
    }
}

- (BOOL)hasMagicFilter {
    return (self.outputFilter == self.magicFilter);
}

- (BOOL)hasMultiFilters {
    return (self.outputFilter != self.inputFilter);
}

- (void)updatePropertiesForRender {
    self.colorFilterTypeForRender = self.colorFilterType;
    self.extFilterGroupForRender = self.extFilterGroup;
}

#pragma mark - Setter/Getter

- (void)setFilterGroupConfig:(NSDictionary<NSString *, NSNumber *> *)filterGroupConfig {
    _filterGroupConfig = filterGroupConfig;
    
    [self updateFilterGroup];
}

- (void)setOutputSize:(CGSize)outputSize {
    if (CGSizeEqualToSize(outputSize, _outputSize)) {
        return;
    }
    
    _outputSize = outputSize;
    
    [self reloadTextureCache];
    
    self.normalFilter.outputSize = outputSize;
    self.beautyFilter.inputSize = self.beautyFilter.outputSize = outputSize;
    self.colorFilter.inputSize = self.colorFilter.outputSize = outputSize;
    self.beautyColorFilter.inputSize = self.beautyColorFilter.outputSize = outputSize;
    
    [self.magicFilterFactory updateInputOutputSizeForFilters:outputSize];
    [self setFilterGroupOutputSize:outputSize];
}

- (void)setViewPortSize:(CGSize)viewPortSize {
    if (CGSizeEqualToSize(viewPortSize, _viewPortSize)) {
        return;
    }
    
    _viewPortSize = viewPortSize;
    
    self.normalFilter.viewPortSize = viewPortSize;
    self.beautyFilter.viewPortSize = viewPortSize;
    self.colorFilter.viewPortSize = viewPortSize;
    self.beautyColorFilter.viewPortSize = viewPortSize;
    
    [self.magicFilterFactory updateViewPortSizeForFilters:viewPortSize];
    [self setFilterGroupViewPortSize:viewPortSize];
}

#pragma mark - Preview

- (void)setPreviewAnimationOrientationWithCameraPosition:(AVCaptureDevicePosition)position mirror:(BOOL)mirror {
    if (position == AVCaptureDevicePositionBack) {
        _previewAnimationRotation = (mirror ? QBGLImageRotationNone : QBGLImageRotationFlipHorizonal);
    } else {
        _previewAnimationRotation = (mirror ? QBGLImageRotationFlipHorizonal : QBGLImageRotationNone);
    }
}

- (void)setPreviewDisplayOrientation:(UIInterfaceOrientation)orientation cameraPosition:(AVCaptureDevicePosition)position {
    if (position == AVCaptureDevicePositionBack) {
        _previewInputRotation =
        orientation == UIInterfaceOrientationPortrait           ? QBGLImageRotationRightFlipHorizontal :
        orientation == UIInterfaceOrientationPortraitUpsideDown ? QBGLImageRotationLeftFlipHorizontal  :
        orientation == UIInterfaceOrientationLandscapeLeft      ? QBGLImageRotation180FlipHorizontal   :
        orientation == UIInterfaceOrientationLandscapeRight     ? QBGLImageRotationFlipHorizonal       :
        QBGLImageRotationNone;
    } else {
        _previewInputRotation =
        orientation == UIInterfaceOrientationPortrait           ? QBGLImageRotationRight :
        orientation == UIInterfaceOrientationPortraitUpsideDown ? QBGLImageRotationLeft  :
        orientation == UIInterfaceOrientationLandscapeLeft      ? QBGLImageRotationNone  :
        orientation == UIInterfaceOrientationLandscapeRight     ? QBGLImageRotation180   :
        QBGLImageRotationNone;
    }
}

- (void)configInputFilterToPreview {
    [self becomeCurrentContext];
    
    // Prefer magic filter to draw animation view texture than other filters because magic filter's z-order is upper than other filters
    BOOL hasMagicFilter = self.hasMagicFilter;
    self.inputFilter.enableAnimationView = (self.animationView != nil && !hasMagicFilter);
    self.inputFilter.inputRotation = self.previewInputRotation;
    self.inputFilter.animationRotation = (hasMagicFilter ? QBGLImageRotationNone : self.previewAnimationRotation);
}

- (void)renderInputFilterToPreview {
    [self.inputFilter render];
    [self.inputFilter draw];
}

- (void)renderInputFilterToOutputFilter {
    [self.inputFilter bindDrawable];
    [self.inputFilter render];
    [self.inputFilter draw];
    
    BOOL hasMagicFilter = self.hasMagicFilter;
    self.outputFilter.enableAnimationView = (self.animationView != nil && hasMagicFilter);
    self.outputFilter.animationRotation = (hasMagicFilter ? self.previewAnimationRotation : QBGLImageRotationNone);
}

- (void)renderOutputFilterToPreview {
    GLuint textureId = self.inputFilter.outputTextureId;
    [self.outputFilter loadTexture:textureId];
    [self.outputFilter render];
    [self.outputFilter draw];
}

#pragma mark - Snow

- (void)startSnowEffect {
    self.hasSnowEffect = YES;
}

- (void)stopSnowEffect {
    self.hasSnowEffect = NO;
}

#pragma mark - Filter Group

- (BOOL)isFilterGroupEmpty {
    return (self.extFilterGroupForRender.count < 1);
}

- (void)updateFilterGroup {
    // 找出目前正在使用的 ext filter 們，讓下面可以重複使用
    __kindof QBGLExtFilter *currBoxesFilter = nil;
    __kindof QBGLExtFilter *currGameFilter = nil;
    __kindof QBGLExtFilter *currPainterFilter = nil;
    for (int i = 0; i < self.extFilterGroup.count; i++) {
        QBGLExtFilterType extFilterType = self.extFilterGroup[i].filterType;
        switch (extFilterType) {
            case QBGLExtFilterTypeBoxes: {
                currBoxesFilter = self.extFilterGroup[i];
            }
            case QBGLExtFilterTypeGame: {
                currGameFilter = self.extFilterGroup[i];
            } break;
            case QBGLExtFilterTypePainter: {
                currPainterFilter = self.extFilterGroup[i];
            } break;
        }
    }
    
    // 判斷當下的設定值需要哪些 ext filter，順序目前定為 painter -> boxes -> game
    NSMutableArray<__kindof QBGLExtFilter *> *extFilterGroup = [NSMutableArray array];
    
    BOOL needPainterFilter = self.filterGroupConfig[@(QBGLExtFilterTypePainter).stringValue].boolValue;
    
    if (needPainterFilter) {
        if (currPainterFilter != nil) {
            [extFilterGroup addObject:currPainterFilter];
        } else {
            __kindof QBGLExtFilter *filter = [QBGLExtFilterFactory filterWithType:QBGLExtFilterTypePainter];
            if (filter) {
                filter.textureCacheRef = self.textureCacheRef;
                filter.viewPortSize = self.viewPortSize;
                filter.outputSize = self.outputSize;
                
                [extFilterGroup addObject:filter];
            }
        }
    }

    BOOL needBoxesFilter = self.filterGroupConfig[@(QBGLExtFilterTypeBoxes).stringValue].boolValue;
    if (needBoxesFilter) {
        if (currBoxesFilter != nil) {
            [extFilterGroup addObject:currBoxesFilter];
        } else {
            __kindof QBGLExtFilter *filter = [QBGLExtFilterFactory filterWithType:QBGLExtFilterTypeBoxes];
            if (filter) {
                filter.textureCacheRef = self.textureCacheRef;
                filter.viewPortSize = self.viewPortSize;
                filter.outputSize = self.outputSize;
                
                [extFilterGroup addObject:filter];
            }
        }
    }
    
    BOOL needGameFilter = self.filterGroupConfig[@(QBGLExtFilterTypeGame).stringValue].boolValue;
    if (needGameFilter) {
        if (currGameFilter != nil) {
            [extFilterGroup addObject:currGameFilter];
        } else {
            __kindof QBGLExtFilter *filter = [QBGLExtFilterFactory filterWithType:QBGLExtFilterTypeGame];
            if (filter) {
                filter.textureCacheRef = self.textureCacheRef;
                filter.viewPortSize = self.viewPortSize;
                filter.outputSize = self.outputSize;
                
                [extFilterGroup addObject:filter];
            }
        }
    }
    
    self.extFilterGroup = [extFilterGroup copy];
}

- (void)setFilterGroupOutputSize:(CGSize)outputSize {
    for (int i = 0; i < self.extFilterGroup.count; i++) {
        self.extFilterGroup[i].inputSize = self.extFilterGroup[i].outputSize = outputSize;
    }
}

- (void)setFilterGroupViewPortSize:(CGSize)viewPortSize {
    for (int i = 0; i < self.extFilterGroup.count; i++) {
        self.extFilterGroup[i].viewPortSize = viewPortSize;
    }
}

- (void)setFilterGroupTextureCache:(CVOpenGLESTextureCacheRef)textureCacheRef {
    for (int i = 0; i < self.extFilterGroup.count; i++) {
        self.extFilterGroup[i].textureCacheRef = textureCacheRef;
    }
}

@end
