#import <Foundation/Foundation.h>
#import "PostViewController.h"
#import "WPTableViewController.h"

//Horizon code
@class HIOoIViewController;
@class EditPostViewController;

@interface PostsViewController : WPTableViewController <UIAccelerometerDelegate, NSFetchedResultsControllerDelegate> {
@private
    UIActivityIndicatorView *activityFooter;
}

@property (readonly) UIBarButtonItem *composeButtonItem;
@property (nonatomic, retain) EditPostViewController *postDetailViewController;
@property (nonatomic, retain) PostViewController *postReaderViewController;
@property (nonatomic, assign) BOOL anyMorePosts;
@property (nonatomic, retain) NSIndexPath *selectedIndexPath;
@property (nonatomic, retain) NSMutableArray *drafts;

- (void)showAddPostView;
- (void)reselect;
- (BOOL)refreshRequired;

@end
