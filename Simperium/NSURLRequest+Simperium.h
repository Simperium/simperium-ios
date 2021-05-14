#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLRequest (Simperium)

+ (NSURLRequest *)sp_loginRequestWithBaseURL:(NSString *)baseURL
                           customHTTPHeaders:(NSDictionary *)customHTTPHeaders
                                       appID:(NSString *)appID
                                      apiKey:(NSString *)apiKey
                                    provider:(NSString *)provider
                                    username:(NSString *)username
                                    password:(NSString *)password;

+ (NSURLRequest *)sp_signupRequestWithBaseURL:(NSString *)baseURL
                            customHTTPHeaders:(NSDictionary *)customHTTPHeaders
                                        appID:(NSString *)appID
                                       apiKey:(NSString *)apiKey
                                     provider:(NSString *)provider
                                     username:(NSString *)username
                                     password:(NSString *)password;

@end

NS_ASSUME_NONNULL_END
