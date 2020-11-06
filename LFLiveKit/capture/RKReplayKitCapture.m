//
//  RKReplayKitCapture.m
//  LFLiveKit
//
//  Created by Han Chang on 2018/7/19.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "RKReplayKitCapture.h"
#import "RKAudioMixSource.h"
#import "RKReplayKitGLContext.h"
#import <ReplayKit/ReplayKit.h>

@interface RKReplayKitCapture ()

@property (nonatomic) AudioStreamBasicDescription appAudioFormat;

@property (nonatomic) AudioStreamBasicDescription micAudioFormat;

@property (strong, nonatomic) RKAudioDataMixSrc *micDataSrc;

@property (strong, nonatomic) RKReplayKitGLContext *glContext;

@property (nonatomic) CFTimeInterval lastVideoTime;

@property (nonatomic) CFTimeInterval lastAppAudioTime;

@property (strong, nonatomic) dispatch_queue_t slienceAudioQueue;

@property (assign, nonatomic, readonly) CGSize targetCanvasSize;

@end

@implementation RKReplayKitCapture

+ (AudioStreamBasicDescription)defaultAudioFormat {
    static AudioStreamBasicDescription format = {0};
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        format.mSampleRate = 44100;
        format.mFormatID = kAudioFormatLinearPCM;
        format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        format.mChannelsPerFrame = 1;
        format.mFramesPerPacket = 1;
        format.mBitsPerChannel = 16;
        format.mBytesPerFrame = format.mBitsPerChannel / 8 * format.mChannelsPerFrame;
        format.mBytesPerPacket = format.mBytesPerFrame * format.mFramesPerPacket;
    });
    return format;
}

- (instancetype)init {
    if (self = [super init]) {
        _targetCanvasSize = CGSizeMake(720, 1280);
        _micDataSrc = [[RKAudioDataMixSrc alloc] init];
        _slienceAudioQueue = dispatch_queue_create("livekit.replaykitcapture.sliencequeue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)pushVideoSample:(CMSampleBufferRef)sample {
    if (!_videoConfiguration) {
        _videoConfiguration = [LFLiveVideoConfiguration defaultConfigurationFromSampleBuffer:sample];
        
        CGSize targetCanvasSize = [self calculateCanvasSizeWithSample:sample];
        if (!CGSizeEqualToSize(targetCanvasSize, CGSizeZero)) {
            _videoConfiguration.videoSize = targetCanvasSize;
        }
        _glContext = [[RKReplayKitGLContext alloc] initWithCanvasSize:_videoConfiguration.videoSize];
    }
    
    [self processVideo:sample];
    
    _lastVideoTime = CACurrentMediaTime();
    [self checkAudio];
}

- (void)processVideo:(CMSampleBufferRef)sample {
    [self handleVideoOrientation:sample];
    [_glContext processPixelBuffer:CMSampleBufferGetImageBuffer(sample)];
    [_glContext render];
    [_delegate replayKitCapture:self didCaptureVideo:_glContext.outputPixelBuffer];
}

- (void)handleVideoOrientation:(CMSampleBufferRef)sample {
    if (@available(iOS 11.1, *)) {
        CFNumberRef orientationAttachment = CMGetAttachment(sample, (__bridge CFStringRef)RPVideoSampleOrientationKey, NULL);
        CGImagePropertyOrientation orientation = [(__bridge NSNumber*)orientationAttachment intValue];
        BOOL mirror = (orientation > kCGImagePropertyOrientationDownMirrored);
        
        CGSize canvasSize = [self calculateCanvasSizeWithSample:sample mirror:mirror];
        if (!CGSizeEqualToSize(canvasSize, CGSizeZero)) {
            _glContext.canvasSize = canvasSize;
            
            if (orientation == kCGImagePropertyOrientationUp) {
                [_glContext setRotation:90];
            } else if (orientation == kCGImagePropertyOrientationDown) {
                [_glContext setRotation:-90];
            } else if (orientation == kCGImagePropertyOrientationRight) {
                [_glContext setRotation:180];
            } else {
                [_glContext setRotation:0];
            }
        }
    }
}

- (void)pushAppAudioSample:(CMSampleBufferRef)sample {
    _lastAppAudioTime = CACurrentMediaTime();
    
    _appAudioFormat = *CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(sample));
    
    if (!_audioConfiguration) {
        _audioConfiguration = [LFLiveAudioConfiguration defaultConfigurationFromFormat:_appAudioFormat];
    }
    
    AudioBufferList audioBufferList;
    CMBlockBufferRef blockBuffer;
    OSStatus status =
    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sample,
                                                            NULL,
                                                            &audioBufferList,
                                                            sizeof(audioBufferList),
                                                            NULL,
                                                            NULL,
                                                            0,
                                                            &blockBuffer);
    if (status != noErr) {
        NSLog(@"app audio sample error = %d", (int)status);
        return;
    }
    for (int i = 0; i < audioBufferList.mNumberBuffers; i++) {
        AudioBuffer audioBuffer = audioBufferList.mBuffers[i];
        NSAssert(audioBuffer.mDataByteSize % 2 == 0, @"data size error");
        NSAssert(audioBuffer.mData != NULL, @"data is null");
        [self convertAudioBufferToNativeEndian:audioBuffer fromFormat:_appAudioFormat];
        [self mixMicAudioToAudioBuffer:audioBuffer];
        NSData *data = [NSData dataWithBytes:audioBuffer.mData length:audioBuffer.mDataByteSize];
        [_delegate replayKitCapture:self didCaptureAudio:data];
    }
    CFRelease(blockBuffer);
}

- (void)pushMicAudioSample:(CMSampleBufferRef)sample {
    _micAudioFormat = *CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(sample));
    
    // 不要在這裡去設定 _audioConfiguration，因為 _micAudioFormat 與 _appAudioFormat 裡的內容可能不同，ex: mSampleRate 不同
//    if (!_audioConfiguration) {
//        _audioConfiguration = [LFLiveAudioConfiguration defaultConfigurationFromFormat:_micAudioFormat];
//    }
    
    AudioBufferList audioBufferList;
    CMBlockBufferRef blockBuffer;
    OSStatus status =
    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sample,
                                                            NULL,
                                                            &audioBufferList,
                                                            sizeof(audioBufferList),
                                                            NULL,
                                                            NULL,
                                                            0,
                                                            &blockBuffer);
    if (status != noErr) {
        NSLog(@"mic audio sample error = %d", (int)status);
        return;
    }
    
    // 3900 = 48000 - 44100
    Float64 sampleRateDiff = self.micAudioFormat.mSampleRate - self.appAudioFormat.mSampleRate;
    int sampleRateDiffInt = 0;
    if (self.appAudioFormat.mSampleRate > 0 && sampleRateDiff > FLT_EPSILON) {
        sampleRateDiffInt = (int)sampleRateDiff;
    }
    
    for (int i = 0; i < audioBufferList.mNumberBuffers; i++) {
        AudioBuffer audioBuffer = audioBufferList.mBuffers[i];
        NSAssert(audioBuffer.mDataByteSize % 2 == 0, @"data size error");
        NSAssert(audioBuffer.mData != NULL, @"data is null");
        NSAssert(audioBuffer.mNumberChannels == 1, @"channel is not mono");
        [self convertAudioBufferToNativeEndian:audioBuffer fromFormat:_micAudioFormat];
        NSData *data = [self syncMicAudioSampleRate:audioBuffer sampleRateDiff:sampleRateDiff];
        [_micDataSrc pushData:data];
    }
    
    CFRelease(blockBuffer);
}

- (NSData *)syncMicAudioSampleRate:(AudioBuffer)audioBuffer sampleRateDiff:(int)sampleRateDiff {
    // 調整 mic audio sample rate 與 app audio sample rate 一致
    NSData *completeData = [NSData dataWithBytes:audioBuffer.mData length:audioBuffer.mDataByteSize];
    if (sampleRateDiff <= 0) {
        return completeData;
    }
    
    // 20 這個值不是算出來的，是怕前面幾個 bytes 會包含一些 header 資料，所以刻意避開不要刪除
    int theFirstReservedByteCount = 20;
    // 2 這個值不是算出來的，只是取一個比較小的數值。因為一次在最末端刪除 166 bytes 會有雜音
    int removedDataByteCount = 2;
    int selectedDataIdx = theFirstReservedByteCount + removedDataByteCount;
    
    // 23.4375 = 48000 / 2048
    Float64 calledTimesPerSec = self.micAudioFormat.mSampleRate / audioBuffer.mDataByteSize;
    // 166 = 3900 / 23.4375
    int totalRemovedByteCount = sampleRateDiff / calledTimesPerSec;
    if (totalRemovedByteCount <= 0) {
        return completeData;
    }
    
    // 1862 = 2048 - 20 - 166
    int remainedDataByteCount = audioBuffer.mDataByteSize - theFirstReservedByteCount - totalRemovedByteCount;
    if (remainedDataByteCount <= 0) {
        return completeData;
    }
    
    // 83 = 166 / 2
    int removedTimes = totalRemovedByteCount / removedDataByteCount;
    // 22 = 1862 / 83
    int subDataSize = remainedDataByteCount / removedTimes;
    NSData *subData = [completeData subdataWithRange:NSMakeRange(0, theFirstReservedByteCount)];
    NSMutableData *trimmedData = [subData mutableCopy];
    // 減1是因為一開始已經先移掉一次了
    int loopCount = removedTimes > 1 ? (removedTimes - 1) : 0;
    for (int i = 0; i < loopCount; i++) {
        subData = [completeData subdataWithRange:NSMakeRange(selectedDataIdx, subDataSize)];
        [trimmedData appendData:subData];
        selectedDataIdx += subDataSize + removedDataByteCount;
    }
    
    NSUInteger finalSubDataSize = audioBuffer.mDataByteSize - selectedDataIdx;
    subData = [completeData subdataWithRange:NSMakeRange(selectedDataIdx, finalSubDataSize)];
    [trimmedData appendData:subData];
    
    return [trimmedData copy];
}

- (void)mixMicAudioToAudioBuffer:(AudioBuffer)audioBuffer {
    // 1 char = 1 byte, 1 short = 2 bytes, 1 byte = 8 bits
    // 1 channel = 16 bits = 2 bytes = 1 short = 2 chars
    char *audioBytes = audioBuffer.mData;
    int bytePerChannel = 2;
    int bytePerFrame = bytePerChannel * audioBuffer.mNumberChannels;
    short b = 0;
    for (int i = 0; i < audioBuffer.mDataByteSize && _micDataSrc.hasNext; i += bytePerChannel) {
        short a = (short)(((audioBytes[i + 1] & 0xFF) << 8) | (audioBytes[i] & 0xFF));
        if (i % bytePerFrame == 0) {
            b = [_micDataSrc next];
        }
        int mixed = (a + b) / 2;
        audioBytes[i] = mixed & 0xFF;
        audioBytes[i + 1] = (mixed >> 8) & 0xFF;
    }
}

- (void)checkAudio {
    if (_lastAppAudioTime == 0) {
        _lastAppAudioTime = _lastVideoTime;
        return;
    }
    
    CFTimeInterval diffInterval = _lastVideoTime - _lastAppAudioTime;
    if (diffInterval >= 1) {
        _lastAppAudioTime = _lastVideoTime;
        __weak typeof(self) wSelf = self;
        dispatch_async(_slienceAudioQueue, ^{
            [wSelf sendSlience];
        });
    }
}

- (void)sendSlience {
    AudioStreamBasicDescription audioFormat = [self.class defaultAudioFormat];
    if (!_audioConfiguration) {
        _audioConfiguration = [LFLiveAudioConfiguration defaultConfigurationFromFormat:audioFormat];
    }
    NSUInteger size = audioFormat.mSampleRate * audioFormat.mBytesPerFrame;   // 0.5 sec
    char *bytes = (char *)malloc(size);
    memset(bytes, 0, size);
    [_micDataSrc readBytes:bytes length:size];
    NSData *data = [NSData dataWithBytesNoCopy:bytes length:size freeWhenDone:YES];
    [_delegate replayKitCapture:self didCaptureAudio:data];
}

- (void)convertAudioBufferToNativeEndian:(AudioBuffer)buffer fromFormat:(AudioStreamBasicDescription)format {
    if (format.mFormatFlags & kAudioFormatFlagIsBigEndian) {
        int i = 0;
        char *ptr = buffer.mData;
        while (i < buffer.mDataByteSize) {
            SInt16 value = CFSwapInt16BigToHost(*((SInt16*)ptr));
            memcpy(ptr, &value, 2);
            i += 2;
            ptr += 2;
        }
    }
}

- (void)convertDataToNativeEndian:(NSMutableData *)data fromFormat:(AudioStreamBasicDescription)format {
    if (format.mFormatFlags & kAudioFormatFlagIsBigEndian) {
        const void *ptr = data.bytes;
        for (int i = 0; i < data.length; i += 2) {
            SInt16 endian = CFSwapInt16BigToHost(*((SInt16*)ptr));
            [data replaceBytesInRange:NSMakeRange(i, 2) withBytes:&endian];
            ptr += 2;
        }
    }
}

- (CGSize)calculateCanvasSizeWithSample:(CMSampleBufferRef)sample {
    if (@available(iOS 11.1, *)) {
        CFNumberRef orientationAttachment = CMGetAttachment(sample, (__bridge CFStringRef)RPVideoSampleOrientationKey, NULL);
        CGImagePropertyOrientation orientation = [(__bridge NSNumber*)orientationAttachment intValue];
        BOOL mirror = (orientation > kCGImagePropertyOrientationDownMirrored);
        
        return [self calculateCanvasSizeWithSample:sample mirror:mirror];
    }
    
    return CGSizeZero;
}

- (CGSize)calculateCanvasSizeWithSample:(CMSampleBufferRef)sample mirror:(BOOL)mirror {
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sample);
    CGSize inputSize = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
    CGFloat outputHeight = self.targetCanvasSize.width * inputSize.height / inputSize.width;
    CGSize outputSize = CGSizeMake(self.targetCanvasSize.width, outputHeight);
    if (mirror) {
        outputSize = CGSizeMake(outputSize.height, outputSize.width);
    }
    return outputSize;
}

@end
