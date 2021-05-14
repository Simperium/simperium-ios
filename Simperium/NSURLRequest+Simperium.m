#import "NSURLRequest+Simperium.h"
#import "JSONKit+Simperium.h"
#import "SPEnvironment.h"


@interface NSURLRequest (Private)
- (void)addHTTPHeaders:(NSDictionary *)HTTPHeaders;
@end


@implementation NSMutableURLRequest (Private)

- (void)addHTTPHeaders:(NSDictionary *)HTTPHeaders {
    for (NSString *key in HTTPHeaders.allKeys) {
        [self setValue:HTTPHeaders[key] forHTTPHeaderField:key];
    }
}

@end


@implementation NSURLRequest (Simperium)

+ (NSURLRequest *)sp_requestWithURL:(NSURL *)url
                  customHTTPHeaders:(NSDictionary *)customHTTPHeaders
                              appID:(NSString *)appID
                             apiKey:(NSString *)apiKey
                           provider:(NSString *)provider
                           username:(NSString *)username
                           password:(NSString *)password {
    NSAssert(appID, @"Simperium Error: Missing AppID");
    NSAssert(apiKey, @"Simperium Error: Missing APIKey");
    NSAssert(url, @"Simperium Error: Missing URL");

    NSDictionary *body = @{
        @"username" : username,
        @"password" : password,
        @"provider" : provider ?: @""
    };

    NSDictionary *authHTTPHeaders = @{
        @"Content-Type"         : @"application/json",
        @"X-Simperium-API-Key"  : apiKey
    };

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];

    [request addHTTPHeaders:authHTTPHeaders];
    [request addHTTPHeaders:customHTTPHeaders];

    request.HTTPMethod = @"POST";
    request.HTTPBody = [[body sp_JSONString] dataUsingEncoding:NSUTF8StringEncoding];

    return request;
}

+ (NSURLRequest *)sp_loginRequestWithBaseURL:(NSString *)baseURL
                           customHTTPHeaders:(NSDictionary *)customHTTPHeaders
                                       appID:(NSString *)appID
                                      apiKey:(NSString *)apiKey
                                    provider:(NSString *)provider
                                    username:(NSString *)username
                                    password:(NSString *)password {
    NSParameterAssert(appID);
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/authorize/", baseURL, appID]];
    return [self sp_requestWithURL:requestURL
                 customHTTPHeaders:customHTTPHeaders
                             appID:appID
                            apiKey:apiKey
                          provider:provider
                          username:username
                          password:password];
}

+ (NSURLRequest *)sp_signupRequestWithBaseURL:(NSString *)baseURL
                            customHTTPHeaders:(NSDictionary *)customHTTPHeaders
                                        appID:(NSString *)appID
                                       apiKey:(NSString *)apiKey
                                     provider:(NSString *)provider
                                     username:(NSString *)username
                                     password:(NSString *)password {
    NSParameterAssert(appID);
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/create/", baseURL, appID]];
    return [self sp_requestWithURL:requestURL
                 customHTTPHeaders:customHTTPHeaders
                             appID:appID
                            apiKey:apiKey
                          provider:provider
                          username:username
                          password:password];
}

@end

