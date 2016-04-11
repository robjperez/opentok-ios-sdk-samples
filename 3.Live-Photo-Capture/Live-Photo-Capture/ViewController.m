//
//  ViewController.m
//  Live-Photo-Capture
//
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "ViewController.h"
#import <OpenTok/OpenTok.h>
#import "TBExamplePublisher.h"
#import "TBExampleSubscriber.h"
#import "TBExamplePhotoVideoCapture.h"

static double kWidgetHeight = 120;
static double kWidgetWidth = 160;

@interface ViewController ()
<OTSessionDelegate, OTSubscriberKitDelegate, OTPublisherDelegate>
@property(strong, nonatomic) OTSession* session;
@property(strong, nonatomic) TBExamplePublisher* publisher;
@property(strong, nonatomic) TBExampleSubscriber* subscriber;
@property(strong, nonatomic) TBExamplePhotoVideoCapture* myPhotoVideoCaptureModule;
@property(strong, nonatomic) UIImageView* myImageView;
@end

@implementation ViewController

// *** Fill the following variables using your own Project info  ***
// ***          https://dashboard.tokbox.com/projects            ***
// Replace with your OpenTok API key
static NSString* const kApiKey = @"";
// Replace with your generated session ID
static NSString* const kSessionId = @"";
// Replace with your generated token
static NSString* const kToken = @"";

// Change to NO to subscribe to streams other than your own.
static bool subscribeToSelf = YES;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Make a UIImageView to hold the output of the photo snapshot
    self.myImageView = [[UIImageView alloc]
                    initWithFrame:CGRectMake(kWidgetWidth, 0, kWidgetHeight,
                                             kWidgetWidth)];
    [self.view addSubview:self.myImageView];
    
    // Bind the whole screen to a gesture recognizer - tap on the screen and
    //  we'll take a picture!
    UITapGestureRecognizer *singleFingerTap =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(handleSingleTap:)];
    [self.view addGestureRecognizer:singleFingerTap];
    
    self.session = [[OTSession alloc] initWithApiKey:kApiKey
                                       sessionId:kSessionId
                                           delegate:self];
    [self doConnect];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:
(UIInterfaceOrientation)interfaceOrientation
{
    return YES; 
}

#pragma mark - Gesture recognizer

/**
 * Fired if the end user taps on the screen. We'll invoke the capture module
 * to take a picture, then display the results.
 */
- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
    if (self.myPhotoVideoCaptureModule.isTakingPhoto) {
        return;
    }
    [self.myPhotoVideoCaptureModule takePhotoWithCompletionHandler:
     ^(UIImage* image) {
        [self.myImageView setImage:image];
        [self.myImageView setNeedsDisplay];
    }];
}

#pragma mark - OpenTok methods

/**
 * Asynchronously begins the session connect process. Some time later, we will
 * expect a delegate method to call us back with the results of this action.
 */
- (void)doConnect
{
    OTError *error = nil;
    [self.session connectWithToken:kToken error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
}

/**
 * Sets up an instance of OTPublisher to use with this session. OTPubilsher
 * binds to the device camera and microphone, and will provide A/V streams
 * to the OpenTok session.
 */
- (void)doPublish
{
    // In this example, we'll be using our own video capture module that can
    // also support photo-quality image capture.
    self.myPhotoVideoCaptureModule = [[TBExamplePhotoVideoCapture alloc] init];
    self.publisher = [[TBExamplePublisher alloc]
                  initWithDelegate:self
                  name:[[UIDevice currentDevice] name]];
    [self.publisher setVideoCapture:self.myPhotoVideoCaptureModule];
    
    OTError *error = nil;
    [self.session publish:self.publisher error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }

    [self.publisher.view setFrame:CGRectMake(0, 0, kWidgetWidth, kWidgetHeight)];
    [self.view addSubview:self.publisher.view];
}

/**
 * Cleans up the publisher and its view. At this point, the publisher should not
 * be attached to the session any more.
 */
- (void)cleanupPublisher {
    [self.publisher.view removeFromSuperview];
    self.publisher = nil;
    // this is a good place to notify the end-user that publishing has stopped.
}

/**
 * Instantiates a subscriber for the given stream and asynchronously begins the
 * process to begin receiving A/V content for this stream. Unlike doPublish,
 * this method does not add the subscriber to the view hierarchy. Instead, we
 * add the subscriber only after it has connected and begins receiving data.
 */
- (void)doSubscribe:(OTStream*)stream
{
    self.subscriber = [[TBExampleSubscriber alloc] initWithStream:stream
                                                     delegate:self];
    OTError *error = nil;;
    [self.session subscribe:self.subscriber error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }

}

/**
 * Cleans the subscriber from the view hierarchy, if any.
 * NB: You do *not* have to call unsubscribe in your controller in response to
 * a streamDestroyed event. Any subscribers (or the publisher) for a stream will
 * be automatically removed from the session during cleanup of the stream.
 */
- (void)cleanupSubscriber
{
    [self.subscriber.view removeFromSuperview];
    self.subscriber = nil;
}

# pragma mark - OTSession delegate callbacks

- (void)sessionDidConnect:(OTSession*)session
{
    NSLog(@"sessionDidConnect (%@)", session.sessionId);
    
    [self doPublish];
}

- (void)sessionDidDisconnect:(OTSession*)session
{
    NSString* alertMessage =
    [NSString stringWithFormat:@"Session disconnected: (%@)",
     session.sessionId];
    NSLog(@"sessionDidDisconnect (%@)", alertMessage);
}


- (void)session:(OTSession*)mySession
  streamCreated:(OTStream *)stream
{
    NSLog(@"session streamCreated (%@)", stream.streamId);
    
    if (nil == self.subscriber && !subscribeToSelf)
    {
        [self doSubscribe:stream];
    }
}

- (void)session:(OTSession*)session
streamDestroyed:(OTStream *)stream
{
    NSLog(@"session streamDestroyed (%@)", stream.streamId);
    
    if ([self.subscriber.stream.streamId isEqualToString:stream.streamId])
    {
        [self cleanupSubscriber];
    }
}

- (void)  session:(OTSession *)session
connectionCreated:(OTConnection *)connection
{
    NSLog(@"session connectionCreated (%@)", connection.connectionId);
}

- (void)    session:(OTSession *)session
connectionDestroyed:(OTConnection *)connection
{
    NSLog(@"session connectionDestroyed (%@)", connection.connectionId);
    if ([self.subscriber.stream.connection.connectionId
         isEqualToString:connection.connectionId])
    {
        [self cleanupSubscriber];
    }
}

- (void) session:(OTSession*)session
didFailWithError:(OTError*)error
{
    NSLog(@"didFailWithError: (%@)", error);
}

# pragma mark - OTSubscriber delegate callbacks

- (void)subscriberDidConnectToStream:(OTSubscriberKit*)subscriber
{
    NSLog(@"subscriberDidConnectToStream (%@)",
          subscriber.stream.connection.connectionId);
    [self.subscriber.view setFrame:CGRectMake(0, kWidgetHeight, kWidgetWidth,
                                          kWidgetHeight)];
    [self.view addSubview:self.subscriber.view];
}

- (void)subscriber:(OTSubscriberKit*)subscriber
  didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@",
          subscriber.stream.streamId,
          error);
}

# pragma mark - OTPublisher delegate callbacks

- (void)publisher:(OTPublisherKit *)publisher
    streamCreated:(OTStream *)stream
{
    if (nil == self.subscriber && subscribeToSelf)
    {
        [self doSubscribe:stream];
    }
}

- (void)publisher:(OTPublisherKit*)publisher
  streamDestroyed:(OTStream *)stream
{
    if ([self.subscriber.stream.streamId isEqualToString:stream.streamId])
    {
        [self cleanupSubscriber];
    }
}

- (void)publisher:(OTPublisherKit*)publisher
 didFailWithError:(OTError*) error
{
    NSLog(@"publisher didFailWithError %@", error);
}

- (void)showAlert:(NSString *)string
{
    // show alertview on main UI
	dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Message from video session"
                                                        message:string
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    });
}

@end
