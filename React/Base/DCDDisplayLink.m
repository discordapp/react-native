//
//  RCTDisplayLink.m
//  React
//
//  Created by Stanislav Vishnevskiy on 6/8/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "DCDDisplayLink.h"
#import <UIKit/UIKit.h>

@interface DCDDisplayLink ()

@property(nonatomic) NSRunLoop *runloop;
@property(nonatomic) NSString *mode;
@property(nonatomic) id target;
@property(nonatomic) SEL selector;
@property(nonatomic) NSTimer *timer;
@property(nonatomic) CADisplayLink *displayLink;

// CADisplayLink is not thread safe.
// Add a flag to avoid the crash of removing invalidated CADisplayLink from the run loop.
@property(nonatomic) BOOL resourcesLoaded;

@end

@implementation DCDDisplayLink

+ (DCDDisplayLink *)displayLinkWithTarget:(id)target selector:(SEL)sel {
  return [[self alloc] initWithTarget:target selector:sel];
}

- (instancetype)initWithTarget:(id)target selector:(SEL)sel {
  if (self = [super init]) {
    _target = target;
    _selector = sel;
    _displayLink = [CADisplayLink displayLinkWithTarget:target selector:sel];
    _resourcesLoaded = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(switchToTimer)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(switchToDisplayLink)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)switchToDisplayLink {
  if (_timer) {
    [_timer invalidate];
    _timer = nil;
    [self setPaused:_paused];
    if (_runloop) {
      [_displayLink addToRunLoop:_runloop forMode:_mode];
    }
  }
}

- (void)switchToTimer {
  if (!_timer) {
    [self maybeResetTimer];
    [self setPaused:_paused];
    if (_runloop && _resourcesLoaded) {
      [_displayLink removeFromRunLoop:_runloop forMode:_mode];
      [_runloop addTimer:_timer forMode:_mode];
    }
  }
}

- (void)addToRunLoop:(NSRunLoop *)runloop forMode:(NSString *)mode {
  _runloop = runloop;
  _mode = mode;
  if (_timer) {
    [self maybeResetTimer];
    [runloop addTimer:_timer forMode:mode];
  }
  else {
    [_displayLink addToRunLoop:runloop forMode:mode];
  }
}

- (void)removeFromRunLoop:(NSRunLoop *)runloop forMode:(NSString *)mode {
  _runloop = nil;
  _mode = nil;
  if (_timer) {
    [_timer invalidate];
  }
  else {
    [_displayLink removeFromRunLoop:runloop forMode:mode];
  }
}

- (void)invalidate {
  _resourcesLoaded = NO;
  if (_timer) {
    [_timer invalidate];
  }
  else {
    [_displayLink invalidate];
  }
}

- (void)setPaused:(BOOL)paused {
  _paused = paused;
  if (_timer) {
    if (paused) {
      [_timer invalidate];
    }
    else {
      [self maybeResetTimer];
      if (_runloop) {
        [_runloop addTimer:_timer forMode:_mode];
      }
    }
  }
  else {
    _displayLink.paused = paused;
  }
}

- (CFTimeInterval)timestamp {
  if (_timer) {
    // TODO: Does React Native actually need this?
    return 0;
  }
  return _displayLink.timestamp;
}

- (CFTimeInterval)duration {
  if (_timer) {
    // TODO: Does React Native actually need this?
    return 0;
  }
  return _displayLink.duration;
}

- (void)maybeResetTimer {
  if (!_timer || ![_timer isValid]) {
    _timer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(timerLoop) userInfo:nil repeats:YES];
  }
}

- (void)timerLoop {
  if (_target) {
    IMP imp = [_target methodForSelector:_selector];
    void (*func)(id, SEL, DCDDisplayLink *) = (void *)imp;
    func(_target, _selector, self);
  }
}

@end
