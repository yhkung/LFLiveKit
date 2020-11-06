//
//  QBGLPainterRenderInfo.h
//  LFLiveKit
//
//  Created by Jan Chen on 2020/6/15.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface QBGLPainterRenderInfo : NSObject

+ (NSArray<QBGLPainterRenderInfo *> *)painterRenderInfosFromArray:(NSArray<NSDictionary *> *)renderInfos;
- (instancetype)initWithRenderInfoDict:(NSDictionary *)dict;

@property (copy, nonatomic, readonly) NSString *textureName;
@property (assign, nonatomic, readonly) CGPoint start;
@property (assign, nonatomic, readonly) CGPoint end;
@property (assign, nonatomic, readonly) CGFloat size;
@property (assign, nonatomic, readonly) CGFloat gap;
@property (assign, nonatomic, readonly) CGFloat r;
@property (assign, nonatomic, readonly) CGFloat g;
@property (assign, nonatomic, readonly) CGFloat b;
@property (assign, nonatomic, readonly) CGFloat a;
@property (assign, nonatomic, readonly) CGFloat opacity;

@property (assign, nonatomic, readonly) BOOL blend; // for earse
@property (assign, nonatomic, readonly) BOOL clear; // clear
@property (assign, nonatomic, readonly) BOOL redraw; // clear and redraw (undo & redo)

@end

NS_ASSUME_NONNULL_END
