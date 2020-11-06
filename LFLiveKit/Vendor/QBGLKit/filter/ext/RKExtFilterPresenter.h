//
//  RKExtFilterPresenter.h
//  LFLiveKit
//
//  Created by Jan Chen on 2020/5/28.
//

#import <Foundation/Foundation.h>
#import "QBGLExtFilterType.h"

@class QBGLContext;
@class LFLiveExtFilterConfig;
@class RKExtFilterPresenter;

NS_ASSUME_NONNULL_BEGIN

@protocol RKExtFilterPresenterDelegate <NSObject>
@optional

- (NSArray<NSDictionary *> *)boxesRenderInfosForExtPresenter:(RKExtFilterPresenter *)presenter;
- (NSArray<NSDictionary *> *)gameRenderInfosForExtPresenter:(RKExtFilterPresenter *)presenter;
- (NSArray<NSDictionary *> *)painterRenderInfosForExtPresenter:(RKExtFilterPresenter *)presenter;
- (BOOL)painterShouldRenderForExtPresenter:(RKExtFilterPresenter *)presenter;
- (QBGLContext *)glContextForExtPresenter:(RKExtFilterPresenter *)presenter;

@end


@interface RKExtFilterPresenter : NSObject
@property (weak, nonatomic) id<RKExtFilterPresenterDelegate> delegate;

+ (instancetype)extFilterPresenterWithLiveFeatureConfig:(LFLiveExtFilterConfig *)config;
- (void)handleExtFilterRenderInfoIfNeeded;
- (void)renderToExtFilterGroup;

@end

NS_ASSUME_NONNULL_END
