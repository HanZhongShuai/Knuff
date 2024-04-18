//
//  APNS.m
//  APNS Pusher
//
//  Created by Simon Blommegård on 2011-10-13.
//  Copyright (c) 2011 Simon Blommegård. All rights reserved.
//

#import "SBAPNS.h"
#import <Security/Security.h>
#import "APNSSecIdentityType.h"
#import "APNSItem.h"

@interface SBAPNS () <NSURLSessionDelegate>
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation SBAPNS

#pragma mark - Properties

- (void)setIdentity:(SecIdentityRef)identity {
  
  if (_identity != identity) {
    if (_identity != NULL) {
      CFRelease(_identity);
    }
    if (identity != NULL) {
      _identity = (SecIdentityRef)CFRetain(identity);
      
      // Create a new session
      NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
      self.session = [NSURLSession sessionWithConfiguration:conf
                                                   delegate:self
                                              delegateQueue:[NSOperationQueue mainQueue]];
      
    } else {
      _identity = NULL;
    }
  }
}

#pragma mark - Public

- (void)pushPayload:(NSDictionary *)payload
            toToken:(NSString *)token
          withTopic:(nullable NSString *)topic
           priority:(NSUInteger)priority
         collapseID:(NSString *)collapseID
        payloadType:(NSUInteger)payloadType
          inSandbox:(BOOL)sandbox {

  NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://api%@.push.apple.com/3/device/%@", sandbox?@".development":@"", token]]];
  request.HTTPMethod = @"POST";
  
  request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
  
  if (topic) {
    [request addValue:topic forHTTPHeaderField:@"apns-topic"];
  }
  
  if (collapseID.length > 0) {
    [request addValue:collapseID forHTTPHeaderField:@"apns-collapse-id"];
  }

  [request addValue:[NSString stringWithFormat:@"%lu", (unsigned long)priority] forHTTPHeaderField:@"apns-priority"];

  [request addValue:APNSItemPushTypeToStr(payloadType) forHTTPHeaderField:@"apns-push-type"];
  
  // apns-expiration
  // apns-id
  
  NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;

    if (r == nil && error) {
        if ([self.delegate respondsToSelector:@selector(APNS:didFailWithError:)]) {
            [self.delegate APNS:self didFailWithError:error];
        }
        return;
    }
      
    if (r.statusCode != 200 && data) {
      NSError *error;
      NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
      
      if (error) {return;}
      
      NSString *reason = dict[@"reason"];
      
      // Not implemented?
//      NSString *ID = r.allHeaderFields[@"apns-id"];
        if (self.delegate && [self.delegate respondsToSelector:@selector(APNS:didRecieveStatus:reason:forID:)]) {
            [self.delegate APNS:self didRecieveStatus:r.statusCode reason:reason forID:nil];
        }
    } else if (r.statusCode == 200) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(APNSDidSuccess:)]) {
            [self.delegate APNSDidSuccess:self];
        }
    }
  }];
  [task resume];
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session task:(nonnull NSURLSessionTask *)task didReceiveChallenge:(nonnull NSURLAuthenticationChallenge *)challenge completionHandler:(nonnull void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
  SecCertificateRef certificate;
  
  SecIdentityCopyCertificate(self.identity, &certificate);
  
  NSURLCredential *cred = [[NSURLCredential alloc] initWithIdentity:self.identity
                                                       certificates:@[(__bridge_transfer id)certificate]
                                                        persistence:NSURLCredentialPersistenceForSession];
  
  completionHandler(NSURLSessionAuthChallengeUseCredential, cred);
}

@end
