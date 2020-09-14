#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLSession (Simperium)

// Performs a given NSURLRequest, and invokes the completionHandler on completion.
// - Important: `completionHandler` will be invoked in the main thread, for convenience
//
- (void)performURLRequest:(NSURLRequest *)request
        completionHandler:(void (^)(NSInteger statusCode, NSString * _Nullable responseString, NSError * _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
