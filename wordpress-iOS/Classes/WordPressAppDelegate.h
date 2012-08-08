#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
//#import "CrashReporter.h"
#import "Constants.h"
#import "UIDevice-Hardware.h"
#import "Blog.h"
#import "CrashReportViewController.h"
#import "HelpViewController.h"
#import "Reachability.h"
#import "WPComOAuthController.h"
#import "PanelNavigationController.h"
#import "FBConnect.h"

@class AutosaveManager;

@interface WordPressAppDelegate : NSObject <UIApplicationDelegate, UIAlertViewDelegate, WPComOAuthDelegate, FBSessionDelegate> {
	Blog *currentBlog;
    //Connection Reachability variables
    Reachability *internetReachability;
    Reachability *wpcomReachability;
    Reachability *currentBlogReachability;
    BOOL connectionAvailable, wpcomAvailable, currentBlogAvailable;
    Facebook *facebook;
@private
    IBOutlet UIWindow *window;
    IBOutlet UINavigationController *navigationController;

	CrashReportViewController *crashReportView;
    BOOL alertRunning, passwordAlertRunning;
    BOOL isUploadingPost;
	BOOL isWPcomAuthenticated;

	NSMutableData *statsData;
	NSString *postID;
    UITextField *passwordTextField;
    NSString *oauthCallback;
	    
	// Core Data
    NSManagedObjectContext *managedObjectContext_;
    NSManagedObjectModel *managedObjectModel_;
    NSPersistentStoreCoordinator *persistentStoreCoordinator_;
    
    //Background tasks
    UIBackgroundTaskIdentifier bgTask;
    
    // Push notifications
    NSDictionary *lastNotificationInfo;
    PanelNavigationController *panelNavigationController;

}

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) UINavigationController *navigationController;
@property (nonatomic, retain) CrashReportViewController *crashReportView;
@property (nonatomic, getter = isAlertRunning) BOOL alertRunning;
@property (nonatomic, assign) BOOL isWPcomAuthenticated;
@property (nonatomic, assign) BOOL isUploadingPost;
@property (nonatomic, retain) Blog *currentBlog;
@property (nonatomic, retain) NSString *postID;
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, retain) Facebook *facebook;
@property (nonatomic, retain) PanelNavigationController *panelNavigationController;

//Connection Reachability variables
@property (nonatomic, retain) Reachability *internetReachability, *wpcomReachability, *currentBlogReachability;
@property (nonatomic, assign) BOOL connectionAvailable, wpcomAvailable, currentBlogAvailable;

- (NSString *)applicationDocumentsDirectory;
- (NSString *)applicationUserAgent;

+ (WordPressAppDelegate *)sharedWordPressApp;

- (void)handleCrashReport;
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message;
- (void)showNotificationErrorAlert:(NSNotification *)notification;
- (BOOL)isWPcomAuthenticated;
- (void)checkWPcomAuthentication;
- (void)showContentDetailViewController:(UIViewController *)viewController;
- (void)deleteLocalDraft:(NSNotification *)notification;
- (void)dismissCrashReporter:(NSNotification *)notification;
- (void)registerForPushNotifications;
- (void)sendApnsToken;
- (void)unregisterApnsToken;
- (void)sendPushNotificationBlogsList;
- (void)openNotificationScreenWithOptions:(NSDictionary *)remoteNotif;

@end
