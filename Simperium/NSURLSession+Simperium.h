#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLSession (Simperium)

- (void)performURLRequest:(NSURLRequest *)request
        completionHandler:(void (^)(NSInteger statusCode, NSString * _Nullable responseString, NSError * _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
