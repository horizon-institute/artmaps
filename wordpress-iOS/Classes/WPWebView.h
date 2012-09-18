//
//  WPWebView.h
//
//  Created by Eric Johnson on 5/23/12.
//

#import <UIKit/UIKit.h>
#import "EGORefreshTableHeaderView.h"

extern NSString *refreshedWithOutValidRequestNotification;

@protocol WPWebViewDelegate;

@interface WPWebView : UIView <UIWebViewDelegate, UIAlertViewDelegate, EGORefreshTableHeaderDelegate, UIScrollViewDelegate> {
    id <WPWebViewDelegate>delegate;
    NSURL *baseURLFallback;
}

@property(nonatomic, assign) IBOutlet id<WPWebViewDelegate> delegate;
@property(nonatomic, readonly, getter=canGoBack) BOOL canGoBack;
@property(nonatomic, readonly, getter=canGoForward) BOOL canGoForward;
@property(nonatomic, readonly, getter=isLoading) BOOL loading;
@property(nonatomic, readonly, getter=request) NSURLRequest *request;
@property(nonatomic) BOOL scalesPageToFit;

- (void)goBack;
- (void)goForward;
- (void)loadData:(NSData *)data MIMEType:(NSString *)MIMEType textEncodingName:(NSString *)encodingName baseURL:(NSURL *)baseURL;
- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;
- (void)loadRequest:(NSURLRequest *)request;
- (void)loadPath:(NSString *)path;
- (void)reload;
- (void)stopLoading;
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script;
- (void)showAlertWithTitle:(NSString *)title andMessage:(NSString *)message;
- (void)showRefreshingState;
- (NSURL *)currentURL;

@end

@protocol WPWebViewDelegate <NSObject>
@optional
- (BOOL)wpWebView:(WPWebView *)wpWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;
- (void)webViewDidStartLoad:(WPWebView *)wpWebView;
- (void)webViewDidFinishLoad:(WPWebView *)wpWebView;
- (void)webView:(WPWebView *)wpWebView didFailLoadWithError:(NSError *)error;

@end
