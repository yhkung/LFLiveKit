//
//  QBGLExtFilter.h
//  LFLiveKit
//
//  Created by Jan Chen on 2020/5/22.
//

#import "QBGLFilter.h"
#import "QBGLExtFilterType.h"

NS_ASSUME_NONNULL_BEGIN

@interface QBGLExtFilter : QBGLFilter

@property (assign, nonatomic) QBGLExtFilterType filterType;
@property (assign, nonatomic) BOOL shouldRender;

+ (instancetype)instanceWithFilterType:(QBGLExtFilterType)filterType;
- (void)drawExternalContent;
- (void)prepareSetup;

@end

NS_ASSUME_NONNULL_END
