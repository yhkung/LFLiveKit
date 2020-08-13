//
//  RKExtFilterPresenter.m
//  LFLiveKit
//
//  Created by Jan Chen on 2020/5/28.
//

#import "RKExtFilterPresenter.h"
#import "QBGLContext.h"
#import "QBGLExtFilterType.h"
#import "QBGLTextureRenderInfo.h"
#import "QBGLPainterRenderInfo.h"
#import "LFLiveFeatureConfig.h"

@interface RKExtFilterPresenter()

@property (assign, nonatomic) BOOL enableBoxes;
@property (assign, nonatomic) BOOL enableGame;
@property (assign, nonatomic) BOOL enablePainter;

@end

@implementation RKExtFilterPresenter

#pragma mark - Init

+ (instancetype)extFilterPresenterWithLiveFeatureConfig:(LFLiveExtFilterConfig *)config {
    if (!config) {
        return nil;
    }
    
    return [[self alloc] initWithLiveFeatureConfig:config];
}

- (instancetype)initWithLiveFeatureConfig:(LFLiveExtFilterConfig *)config {
    if (!config) {
        return nil;
    }
    
    if (self = [super init]) {
        _enableGame = config.enableGame;
        _enableBoxes = config.enableBoxes;
        _enablePainter = config.enablePainter;
    }
    
    return self;
}

- (QBGLContext *)glContext {
    if ([self.delegate respondsToSelector:@selector(glContextForExtPresenter:)]) {
        return [self.delegate glContextForExtPresenter:self];
    }
    
    return nil;
}

#pragma mark - Public Method

- (void)renderToExtFilterGroup {
    [self.glContext renderToExtFilterGroup];
}

- (void)handleExtFilterRenderInfoIfNeeded {
    if (self.enableBoxes && [self.delegate respondsToSelector:@selector(boxesRenderInfosForExtPresenter:)]) {
        NSArray<NSDictionary *> *infos = [self.delegate boxesRenderInfosForExtPresenter:self];
        BOOL shouldRender = infos.count > 0;
        [self enableExtFilter:QBGLExtFilterTypeBoxes enable:shouldRender];
        if (shouldRender) {
            [self updateExtFilterWithInfos:infos type:QBGLExtFilterTypeBoxes];
        }
    }
    
    if (self.enablePainter &&
        [self.delegate respondsToSelector:@selector(painterRenderInfosForExtPresenter:)] &&
        [self.delegate respondsToSelector:@selector(painterShouldRenderForExtPresenter:)]) {
        NSArray<NSDictionary *> *infos = [self.delegate painterRenderInfosForExtPresenter:self];
        
        BOOL shouldRender = [self.delegate painterShouldRenderForExtPresenter:self];
        [self enableExtFilter:QBGLExtFilterTypePainter enable:shouldRender];
        
        if (shouldRender) {
            [self updateExtFilterWithInfos:infos type:QBGLExtFilterTypePainter];
        }
    }
}

#pragma mark - Private Method

- (void)enableExtFilter:(QBGLExtFilterType)type enable:(BOOL)enable {
    [self.glContext enableExtFilterRender:type enable:enable];
}

- (void)updateExtFilterWithInfos:(NSArray<NSDictionary *> *)infos
                            type:(QBGLExtFilterType)type {
    NSMutableArray<NSObject *> *renderInfos = [NSMutableArray array];

    if (type == QBGLExtFilterTypeGame || type == QBGLExtFilterTypeBoxes) {
        renderInfos = [QBGLTextureRenderInfo textureRenderInfosFromArray:infos];
    } else if (type == QBGLExtFilterTypePainter) {
        renderInfos = [QBGLPainterRenderInfo painterRenderInfosFromArray:infos];
    }
    
    [self.glContext updateExtFilter:[renderInfos copy] type:type];
}

@end
