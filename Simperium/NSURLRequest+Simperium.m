#import "NSURLRequest+Simperium.h"
#import "JSONKit+Simperium.h"
#import "SPEnvironment.h"


@interface NSURLRequest (Internal)
+ (NSURLRequest *)sp_requestWithURL:(NSURL *)url
                              appID:(NSString *)appID
                             apiKey:(NSString *)apiKey
                           provider:(NSString *)provider
                           username:(NSString *)username
                           password:(NSString *)password;
@end


@implementation NSURLRequest (Simperium)

+ (NSURLRequest *)sp_loginRequestWithAppID:(NSString *)appID
                                    apiKey:(NSString *)apiKey
                                  provider:(NSString *)provider
                                  username:(NSString *)username
                                  password:(NSString *)password {
    NSParameterAssert(appID);
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/authorize/", SPAuthURL, appID]];
    return [self sp_requestWithURL:requestURL appID:appID apiKey:apiKey provider:provider username:username password:password];
}

+ (NSURLRequest *)sp_signupRequestWithAppID:(NSString *)appID
                                     apiKey:(NSString *)apiKey
                                   provider:(NSString *)provider
                                   username:(NSString *)username
                                   password:(NSString *)password {
    NSParameterAssert(appID);
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/create/", SPAuthURL, appID]];
    return [self sp_requestWithURL:requestURL appID:appID apiKey:apiKey provider:provider username:username password:password];
}

+ (NSURLRequest *)sp_requestWithURL:(NSURL *)url
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

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];

    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:apiKey forHTTPHeaderField:@"X-Simperium-API-Key"];

    request.HTTPMethod = @"POST";
    request.HTTPBody = [[body sp_JSONString] dataUsingEncoding:NSUTF8StringEncoding];

    return request;
}

@end
