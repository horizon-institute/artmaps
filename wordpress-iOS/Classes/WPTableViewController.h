//
//  WPTableViewController.h
//  WordPress
//
//  Created by Brad Angelcyk on 5/22/12.
//

#import <UIKit/UIKit.h>
#import "Blog.h"

@interface WPTableViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (nonatomic, retain) Blog *blog;

- (id)initWithBlog:(Blog *)blog;

@end
