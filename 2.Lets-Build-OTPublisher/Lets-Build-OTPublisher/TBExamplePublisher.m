//
//  TBExamplePublisher.m
//  Lets-Build-OTPublisher
//
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "TBExamplePublisher.h"
#import "TBExampleVideoCapture.h"
#import "TBExampleVideoRender.h"

@interface TBExamplePublisher ()
@property (strong, nonatomic) TBExampleVideoRender* videoView;
@property (strong, nonatomic) TBExampleVideoCapture* defaultVideoCapture;
@end

@implementation TBExamplePublisher

- (id)init {
    self = [self initWithDelegate:nil name:nil];
    if (self) {
        // nothing to do!
    }
    return self;
}

- (id)initWithDelegate:(id<OTPublisherDelegate>)delegate {
    self = [self initWithDelegate:delegate name:nil];
    if (self) {
        // nothing to do!
    }
    return self;
}

- (id)initWithDelegate:(id<OTPublisherDelegate>)delegate
                  name:(NSString*)name
{
    self = [super initWithDelegate:delegate name:name];
    if (self) {
        TBExampleVideoCapture* videoCapture = [[TBExampleVideoCapture alloc] init];
        [self setVideoCapture:videoCapture];
        
        _videoView = [[TBExampleVideoRender alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
        // Set mirroring only if the front camera is being used.
        [_videoView setMirroring:(AVCaptureDevicePositionFront == videoCapture.cameraPosition)];
        [self setVideoRender:_videoView];
    }
    return self;
}

- (void)dealloc {
    self.videoView = nil;
    [self.defaultVideoCapture removeObserver:self
                              forKeyPath:@"cameraPosition"
                                 context:nil];
    self.defaultVideoCapture = nil;
}

- (UIView *)view {
    return self.videoView;
}

#pragma mark - Public API

- (void)setCameraPosition:(AVCaptureDevicePosition)cameraPosition {
    [self.defaultVideoCapture setCameraPosition:cameraPosition];
}

- (AVCaptureDevicePosition)cameraPosition {
    return [self.defaultVideoCapture cameraPosition];
}

#pragma mark - Overrides for public API

- (void)setVideoCapture:(id<OTVideoCapture>)videoCapture {
    [super setVideoCapture:videoCapture];
    [self.defaultVideoCapture removeObserver:self
                              forKeyPath:@"cameraPosition"
                                 context:nil];
    self.defaultVideoCapture = nil;
    
    // Save the new instance if it's still compatible with the public contract
    // for defaultVideoCapture
    if ([videoCapture isKindOfClass:[TBExampleVideoCapture class]]) {
        self.defaultVideoCapture = (TBExampleVideoCapture*) videoCapture;
    }
    
    [self.defaultVideoCapture addObserver:self
                           forKeyPath:@"cameraPosition"
                              options:NSKeyValueObservingOptionNew
                              context:nil];
    
}

#pragma mark - Overrides for UI

- (void)setPublishVideo:(BOOL)publishVideo {
    [super setPublishVideo:publishVideo];
    if (!publishVideo) {
        [self.videoView clearRenderBuffer];
    }
}

#pragma mark - KVO listeners for Delegate notification

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([@"cameraPosition" isEqualToString:keyPath]) {
        // For example, this is how you could notify a delegate about camera
        // position changes.
    }
}

@end