//  The MIT License (MIT)
//
//  Copyright (c) 2014 Studyplus inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "SPLStudyplusAPIRequest.h"
#import "SPLStudyplusLogger.h"
#import "SPLStudyplusError.h"

@interface SPLStudyplusAPIRequest()
@property (nonatomic, readonly) NSString *accessToken;
@property (nonatomic, readonly) NSInteger apiVersion;
@end

static NSString * const ApiBaseURL = @"https://external-api.studyplus.jp/";
static NSInteger const ApiDefaultVersion = 1;

@implementation SPLStudyplusAPIRequest

- (instancetype)init
{
    if (self = [super init]) {
        _accessToken = nil;
    }
    return self;
}

+ (instancetype)newRequestWithAccessToken:(NSString*)accessToken
                                  options:(NSDictionary*)options
{
    return [[SPLStudyplusAPIRequest alloc] initWithAccessToken:accessToken
                                                       options:options];
}

- (instancetype)initWithAccessToken:(NSString*)accessToken
                            options:(NSDictionary*)options
{
    if (self = [super init]) {
        _accessToken = accessToken;
        _apiVersion = options[@"version"] ? [options[@"version"] integerValue] : ApiDefaultVersion;
    }
    return self;
}

- (void)postRequestWithPath:(NSString *)path
           requestParameter:(NSDictionary *)requestParameter
                  completed:(void(^)(NSDictionary *response))completed
                     failed:(void(^)(NSError *error))failed
{    
    [self sendRequestWithPath:path
                requestParams:requestParameter
                    completed:completed
                       failed:^(NSInteger httpStatusCode, NSError *error) {
                           if (error) {
                               failed(error);
                           } else {
                               failed([SPLStudyplusError errorFromStudyRecordPostStatusCode:httpStatusCode]);
                           }
                       }];
}

- (void)sendRequestWithPath:(NSString*)path
              requestParams:(NSDictionary *)requestParams
                  completed:(void(^)(NSDictionary *response))completed
                     failed:(void(^)(NSInteger httpStatusCode, NSError *error))failed
{
    NSString *urlString = [self buildUrlFromPath:path];
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (!url) {
        NSError *urlError = [NSError errorWithDomain:@"SPLStudyplusAPIRequest"
                                                code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}];
        failed(0, urlError);
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:[NSString stringWithFormat:@"OAuth %@", self.accessToken]
   forHTTPHeaderField:@"HTTP_AUTHORIZATION"];
    
    if (requestParams) {
        NSError *jsonError = nil;
        NSData *bodyData = [NSJSONSerialization dataWithJSONObject:requestParams
                                                           options:0
                                                             error:&jsonError];
        if (jsonError) {
            failed(0, jsonError);
            return;
        }
        request.HTTPBody = bodyData;
    }
    
    NSURLSessionDataTask *task =
    [[NSURLSession sharedSession] dataTaskWithRequest:request
                                    completionHandler:^(NSData * _Nullable data,
                                                        NSURLResponse * _Nullable response,
                                                        NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSInteger statusCode = httpResponse.statusCode;
        
        if (error) {
            StudyplusSDKLog(@"Error: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                failed(statusCode, error);
            });
            return;
        }
        
        NSError *jsonError = nil;
        NSDictionary *json = nil;
        
        if (data.length > 0) {
            id responseObject = [NSJSONSerialization JSONObjectWithData:data
                                                               options:NSJSONReadingAllowFragments
                                                                 error:&jsonError];
            if ([responseObject isKindOfClass:[NSDictionary class]]) {
                json = (NSDictionary *)responseObject;
            }
        }
        
        if (statusCode >= 200 && statusCode < 300) {
            StudyplusSDKLog(@"response: %@", json);
            dispatch_async(dispatch_get_main_queue(), ^{
                completed(json ?: @{});
            });
        } else {
            StudyplusSDKLog(@"HTTP Error: %ld, response: %@", (long)statusCode, json);
            dispatch_async(dispatch_get_main_queue(), ^{
                failed(statusCode, jsonError);
            });
        }
    }];
    
    [task resume];
}

- (NSString *)apiBaseURL
{
#ifdef STUDYPLUS_API_URL
    return STUDYPLUS_API_URL;
#else
    return ApiBaseURL;
#endif
}

- (NSString *)buildUrlFromPath:(NSString *)path
{
    return [NSString stringWithFormat:@"%@v%ld/%@", [self apiBaseURL], (long)self.apiVersion, path];
}

@end
