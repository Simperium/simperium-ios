#import "NSURLSession+Simperium.h"
#import "NSURLResponse+Simperium.h"

@implementation NSURLSession (Simperium)

- (void)performURLRequest:(NSURLRequest *)request
        completionHandler:(void (^)(NSInteger statusCode, NSString * _Nullable responseString, NSError * _Nullable error))completionHandler
{
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSString *responseString = nil;
        if ([data isKindOfClass:[NSData class]]) {
            responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(response.sp_statusCode, responseString, error);
        });
    }];

    [task resume];
}

@end
