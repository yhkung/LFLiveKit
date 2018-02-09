//
//  QBGLView.h
//  LFLiveKit
//
//  Created by Ken Sun on 2018/2/6.
//  Copyright © 2018年 admin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "QBGLFilter.h"

@interface QBGLView : UIView

@property (strong, nonatomic) EAGLContext *glContext;

@property (nonatomic) QBGLImageRotation inputRotation;
@property (nonatomic) CGSize inputSize;

- (instancetype)initWithFrame:(CGRect)frame glContext:(EAGLContext *)context;

- (void)loadTexture:(GLuint)textureId;

- (GLuint)renderAtIndex:(GLuint)index;

- (GLuint)render;

@end
