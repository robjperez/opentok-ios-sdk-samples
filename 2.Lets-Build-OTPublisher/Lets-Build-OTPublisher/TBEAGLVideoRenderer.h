//
//  TBEAGLVideoRenderer.h
//  Lets-Build-OTPublisher
//
//  Copyright © 2016 TokBox, Inc. All rights reserved.
//

#import <OpenTok/OpenTok.h>

@interface TBEAGLVideoRenderer : NSObject

@property (readonly) int64_t lastFrameTime;

- (instancetype)initWithContext:(EAGLContext*)context;

// Draws |frame| onto the currently bound OpenGL framebuffer. |setupGL| must be
// called before this function will succeed.
- (BOOL)drawFrame:(OTVideoFrame*)frame withViewport:(CGRect)viewport;

// Clears the render buffer, discarding any image data that was being displayed.
- (BOOL)clearFrame;

// The following methods are used to manage OpenGL resources. On iOS
// applications should release resources when placed in background for use in
// the foreground application. In fact, attempting to call OpenGLES commands
// while in background will result in application termination.

// Sets up the OpenGL state needed for rendering.
- (void)setupGL;
// Tears down the OpenGL state created by |setupGL|.
- (void)teardownGL;

@property (nonatomic, assign) BOOL mirroring;

@end

