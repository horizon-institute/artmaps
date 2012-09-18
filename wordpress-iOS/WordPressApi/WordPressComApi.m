//
//  WordPressComApi.m
//  WordPress
//
//  Created by Jorge Bernal on 6/4/12.
//  Copyright (c) 2012 WordPress. All rights reserved.
//

#import "WordPressComApi.h"
#import "SFHFKeychainUtils.h"
#import "WordPressAppDelegate.h"
#import "Constants.h"

@interface WordPressComApi ()
@property (readwrite, nonatomic, retain) NSString *username;
@property (readwrite, nonatomic, retain) NSString *password;
@end

@implementation WordPressComApi
@dynamic username;
@dynamic password;

+ (WordPressComApi *)sharedApi {
    static WordPressComApi *_sharedApi = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        NSString *username = [[NSUserDefaults standardUserDefaults] objectForKey:@"wpcom_username_preference"];
        NSString *password = nil;
        if (username) {
            NSError *error = nil;
            password = [SFHFKeychainUtils getPasswordForUsername:username
                                                  andServiceName:@"WordPress.com"
                                                           error:&error];
        }
        _sharedApi = [[self alloc] initWithXMLRPCEndpoint:[NSURL URLWithString:kWPcomXMLRPCUrl] username:username password:password];
    });
    
    return _sharedApi;

}

- (void)setUsername:(NSString *)username password:(NSString *)password success:(void (^)())success failure:(void (^)(NSError *error))failure {
    if (self.username && ![username isEqualToString:self.username]) {
        [self signOut]; // Only one account supported for now
    }
    self.username = username;
    self.password = password;
    [self authenticateWithSuccess:^{
        NSError *error = nil;
        [SFHFKeychainUtils storeUsername:self.username andPassword:self.password forServiceName:@"WordPress.com" updateExisting:YES error:&error];
        if (error) {
            if (failure) {
                failure(error);
            }
        } else {
            [[NSUserDefaults standardUserDefaults] setObject:self.username forKey:@"wpcom_username_preference"];
            [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:@"wpcom_authenticated_flag"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [WordPressAppDelegate sharedWordPressApp].isWPcomAuthenticated = YES;
            [[WordPressAppDelegate sharedWordPressApp] registerForPushNotifications];
            [[NSNotificationCenter defaultCenter] postNotificationName:WordPressComApiDidLoginNotification object:self.username];
            if (success) success();
        }
    } failure:^(NSError *error) {
        self.username = nil;
        self.password = nil;
        if (failure) failure(error);
    }];
}

- (void)signOut {
#if FALSE
    // Until we have accounts, don't delete the password or any blog with that username will stop working
    NSError *error = nil;
    [SFHFKeychainUtils deleteItemForUsername:self.username andServiceName:@"WordPress.com" error:&error];
#endif
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"wpcom_username_preference"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"wpcom_authenticated_flag"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [WordPressAppDelegate sharedWordPressApp].isWPcomAuthenticated = NO;
    [[WordPressAppDelegate sharedWordPressApp] unregisterApnsToken];
    self.username = nil;
    self.password = nil;

    // Clear reader caches and cookies
    // FIXME: this doesn't seem to log out the reader properly
    NSArray *readerCookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:kMobileReaderURL]];
    for (NSHTTPCookie *cookie in readerCookies) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
    }
    [[NSURLCache sharedURLCache] removeAllCachedResponses];

    // Notify the world
    [[NSNotificationCenter defaultCenter] postNotificationName:WordPressComApiDidLogoutNotification object:nil];
}

@end
