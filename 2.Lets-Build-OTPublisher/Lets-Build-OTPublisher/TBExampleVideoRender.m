//
//  OTGLKVideoRender.m
//  otkit-objc-libs
//
//  This class derived from WebRTC's RTCEAGLVideoView.m, license below.
//
//

/*
 * libjingle
 * Copyright 2014, Google Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "TBExampleVideoRender.h"
#import <libkern/OSAtomic.h>

@interface TBDisplayLinkProxy : NSObject

@property (weak, nonatomic) GLKView* glkView;
@property (weak, nonatomic) TBExampleVideoRender* delegate;

- (id)initWithGLKView:(GLKView*)view delegate:(TBExampleVideoRender*)delegate;
- (void)displayLinkDidFire:(CADisplayLink*)displayLink;
@end

@interface TBExampleVideoRender ()

@property (strong, nonatomic) CADisplayLink* displayLink;
@property (strong, nonatomic) TBDisplayLinkProxy* displayLinkProxy;
@property (strong, nonatomic) EAGLContext* glContext;
@property (strong, nonatomic) GLKView *glkView;
@property (strong, nonatomic) TBEAGLVideoRenderer* glRenderer;
@property (strong, nonatomic) OTVideoFrame* videoFrame;
@property (assign, nonatomic) int64_t lastFrameTime;
@property (strong, nonatomic) NSLock* frameLock;
@property (assign, nonatomic) int32_t clearRenderer;

- (BOOL)needsRendererUpdate;
@end

@implementation TBExampleVideoRender

@synthesize renderingEnabled = _renderingEnabled;

#pragma mark - Object Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _glContext =
        [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        _glRenderer = [[TBEAGLVideoRenderer alloc] initWithContext:_glContext];
        
        _glkView = [[GLKView alloc] initWithFrame:CGRectZero
                                          context:_glContext];
        _glkView.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
        _glkView.drawableDepthFormat = GLKViewDrawableDepthFormatNone;
        _glkView.drawableStencilFormat = GLKViewDrawableStencilFormatNone;
        _glkView.drawableMultisample = GLKViewDrawableMultisampleNone;
        _glkView.delegate = self;
        _glkView.layer.masksToBounds = YES;
        [self addSubview:_glkView];
        
        _frameLock = [[NSLock alloc] init];
        _renderingEnabled = YES;
        _clearRenderer = 0;
        
        // Listen to application state in order to clean up OpenGL before app
        // goes away.
        NSNotificationCenter* notificationCenter =
        [NSNotificationCenter defaultCenter];
        [notificationCenter
         addObserver:self
         selector:@selector(willResignActive)
         name:UIApplicationWillResignActiveNotification
         object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(didBecomeActive)
                                   name:UIApplicationDidBecomeActiveNotification
                                 object:nil];
        _displayLinkProxy =
        [[TBDisplayLinkProxy alloc] initWithGLKView:_glkView delegate:self];
        
        _displayLink = [CADisplayLink displayLinkWithTarget:_displayLinkProxy
                                                   selector:@selector(displayLinkDidFire:)];
        
        _displayLink.paused = YES;
        // Set to half of screen refresh, which should be 30fps.
        [_displayLink setFrameInterval:2];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                           forMode:NSRunLoopCommonModes];
        [self setupGL];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    UIApplicationState appState =
    [UIApplication sharedApplication].applicationState;
    if (appState == UIApplicationStateActive) {
        [self teardownGL];
    }
    [EAGLContext setCurrentContext:nil];
    
    [self.displayLink invalidate];
    [self.frameLock lock];
    free([self.videoFrame.planes pointerAtIndex:0]);
    self.videoFrame = nil;
    [self.frameLock unlock];
}


#pragma mark - Private Methods

- (void)setupGL {
    [self.glRenderer setupGL];
    self.displayLink.paused = NO;
}

- (void)teardownGL {
    self.displayLink.paused = YES;
    [self.glkView deleteDrawable];
    [self.glRenderer teardownGL];
}

- (void)didBecomeActive {
    [self setupGL];
}

- (void)willResignActive {
    [self teardownGL];
}

+ (BOOL)videoFrame:(OTVideoFrame*)fromFrame
    canCopyToFrame:(OTVideoFrame*)toFrame
{
    if (fromFrame.format.imageWidth != toFrame.format.imageWidth) {
        return NO;
    }
    
    if (fromFrame.format.imageHeight != toFrame.format.imageHeight) {
        return NO;
    }
    
    return YES;
}

- (BOOL)needsRendererUpdate {
    return (self.glRenderer.lastFrameTime != self.lastFrameTime && self.renderingEnabled) ||
    self.clearRenderer;
}


#pragma mark - Public

- (BOOL)mirroring {
    return self.glRenderer.mirroring;
}

- (void)setMirroring:(BOOL)mirroring {
    [self.glRenderer setMirroring:mirroring];
}

- (BOOL)renderingEnabled {
    return _renderingEnabled;
}

- (void)setRenderingEnabled:(BOOL)renderingEnabled {
    _renderingEnabled = renderingEnabled;
}

- (void)clearRenderBuffer {
    OSAtomicTestAndSet(1, &_clearRenderer);
}

#pragma mark - UIView

- (void)layoutSubviews {
    [super layoutSubviews];
    self.glkView.frame = self.bounds;
}


#pragma mark - OTVideoRender

- (void)renderVideoFrame:(OTVideoFrame*)frame {
    [self.frameLock lock];
    assert(OTPixelFormatI420 == frame.format.pixelFormat);
    if (![TBExampleVideoRender videoFrame:frame canCopyToFrame:self.videoFrame])
    {
        free([self.videoFrame.planes pointerAtIndex:0]);
        self.videoFrame = [[OTVideoFrame alloc] initWithFormat:frame.format];
        void* frameData = malloc(frame.format.imageWidth *
                                 frame.format.imageHeight * 3 / 2);
        
        // TODO: clean this up, lots of assumptions being made here.
        // Y
        [self.videoFrame.planes addPointer:frameData];
        // U
        [self.videoFrame.planes addPointer:&(frameData[frame.format.imageHeight
                                                   * frame.format.imageWidth])];
        // V
        [self.videoFrame.planes addPointer:&(frameData[frame.format.imageHeight *
                                                   frame.format.imageWidth *
                                                   5 / 4])];
    }
    
    memcpy([self.videoFrame.planes pointerAtIndex:0],
           [frame.planes pointerAtIndex:0],
           frame.format.imageHeight * frame.format.imageWidth * 3 / 2);
    
    self.videoFrame.timestamp = frame.timestamp;
    // Keep frame timestamp separately so we don't have to lock to access
    self.lastFrameTime = frame.timestamp.value;
    [self.frameLock unlock];
    
    if ([self.delegate respondsToSelector:@selector(renderer:didReceiveFrame:)]) {
        [self.delegate renderer:self didReceiveFrame:frame];
    }
}

#pragma mark - GLKViewDelegate

// This method is called when the GLKView's content is dirty and needs to be
// redrawn. This occurs on main thread.
- (void)glkView:(GLKView*)view drawInRect:(CGRect)rect {
    if (OSAtomicTestAndClear(1, &_clearRenderer)) {
        [self.glRenderer clearFrame];
        return;
    }
    
    [self.frameLock lock];
    if (self.videoFrame) {
        // The renderer will draw the frame to the framebuffer corresponding to
        // the one used by |view|.
        [self.glRenderer drawFrame:self.videoFrame withViewport:view.frame];
    }
    [self.frameLock unlock];
}

@end

#pragma mark - OTDisplayLinkProxy -

// We need this in a separate class, otherwise a circular retain keeps the owner
// from deallocating.
@implementation TBDisplayLinkProxy

- (id)initWithGLKView:(GLKView*)view delegate:(TBExampleVideoRender*)delegate
{
    self = [super init];
    if (self) {
        _glkView = view;
        _delegate = delegate;
    }
    return self;
}

#pragma mark - DisplayLink delegate

// Frames are received on a separate thread, so we poll for current frame
// using a refresh rate proportional to screen refresh frequency. This occurs
// on the main thread.
- (void)displayLinkDidFire:(CADisplayLink*)displayLink {
    // Don't render if frame hasn't changed.
    // This tells the GLKView that it's dirty, which will then call the the
    // GLKViewDelegate method implemented above.
    if ([self.delegate needsRendererUpdate]) {
        [self.glkView setNeedsDisplay];
    }
}

@end