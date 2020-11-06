//
//  QBGLTextureRenderInfo.h
//  LFLiveKit
//
//  Created by Jan Chen on 2020/5/21.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface QBGLTextureRenderInfo : NSObject

+ (NSArray<QBGLTextureRenderInfo *> *)textureRenderInfosFromArray:(NSArray<NSDictionary *> *)renderInfos;
- (instancetype)initWithRenderInfoDict:(NSDictionary *)dict;
- (instancetype)initWithImageName:(NSString *)imageName
                         position:(CGPoint)position
                             size:(CGSize)size
                         rotation:(CGFloat)rotation
                           xScale:(CGFloat)xScale
                           yScale:(CGFloat)yScale
                            alpha:(CGFloat)alpha
                           zOrder:(CGFloat)zOrder;

@property (copy, nonatomic) NSString *imageName;
@property (assign, nonatomic) CGPoint position;
@property (assign, nonatomic) CGSize size;
@property (assign, nonatomic) CGFloat rotation;
@property (assign, nonatomic) CGFloat xScale;
@property (assign, nonatomic) CGFloat yScale;
@property (assign, nonatomic) CGFloat alpha;
@property (assign, nonatomic) CGFloat zOrder;

@end

NS_ASSUME_NONNULL_END
