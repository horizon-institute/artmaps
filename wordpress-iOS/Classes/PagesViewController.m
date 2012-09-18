//
//  PagesViewController.m
//  WordPress
//
//  Created by Janakiram on 01/11/08.
//

#import "PagesViewController.h"
#import "PageViewController.h"
#import "EditPageViewController.h"
#import "WPTableViewControllerSubclass.h"

#define TAG_OFFSET 1010

@interface PagesViewController (PrivateMethods)
- (void)syncFinished;
- (void)syncPosts;
- (BOOL)isSyncing;
@end

@implementation PagesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Pages", @"");
}

- (void)refreshHandler {
    if ([self isSyncing])
        return;
    [self syncPosts];
}

- (void)syncPosts {
    [self.blog syncPagesWithSuccess:^{
        [self syncFinished];
    } failure:^(NSError *error) {
        [WPError showAlertWithError:error title:NSLocalizedString(@"Couldn't sync pages", @"")];
        [self syncFinished];
    } loadMore:NO];
}

// For iPhone
- (void)editPost:(AbstractPost *)apost {
    self.postDetailViewController = [[[EditPageViewController alloc] initWithNibName:@"EditPostViewController" bundle:nil] autorelease];
    self.postDetailViewController.apost = [apost createRevision];
    self.postDetailViewController.editMode = kEditPost;
    [self.postDetailViewController refreshUIForCurrentPost];
    
    UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController:self.postDetailViewController] autorelease];
    navController.modalPresentationStyle = UIModalPresentationPageSheet;
    [self.panelNavigationController presentModalViewController:navController animated:YES];
}

// For iPad
- (void)showSelectedPost {
    Page *page = nil;
    NSIndexPath *indexPath = self.selectedIndexPath;

    @try {
        page = [self.resultsController objectAtIndexPath:indexPath];
        WPLog(@"Selected page at indexPath: (%i,%i)", indexPath.section, indexPath.row);
    }
    @catch (NSException *e) {
        NSLog(@"Can't select page at indexPath (%i,%i)", indexPath.section, indexPath.row);
        NSLog(@"sections: %@", self.resultsController.sections);
        NSLog(@"results: %@", self.resultsController.fetchedObjects);
        page = nil;
    }
    
    self.postReaderViewController = [[PageViewController alloc] initWithPost:page];
    [self.panelNavigationController pushViewController:self.postReaderViewController fromViewController:self animated:YES];
}

- (void)showAddPostView {
    Page *post = [Page newDraftForBlog:self.blog];
    EditPageViewController *editPostViewController = [[[EditPageViewController alloc] initWithPost:[post createRevision]] autorelease];
    editPostViewController.editMode = kNewPost;
    [editPostViewController refreshUIForCompose];
    UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController:editPostViewController] autorelease];
    navController.modalPresentationStyle = UIModalPresentationPageSheet;
    [self.panelNavigationController presentModalViewController:navController animated:YES];
    [post release];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.resultsController sections] objectAtIndex:section];
    NSString *sectionName = [sectionInfo name];
    
    return [Page titleForRemoteStatus:[sectionName numericValue]];
}

#pragma mark -
#pragma mark Syncs methods

- (BOOL)isSyncing {
	return self.blog.isSyncingPages;
}

-(NSDate *) lastSyncDate {
	return self.blog.lastPagesSync;
}

- (BOOL) hasOlderItems {
	return [self.blog.hasOlderPages boolValue];
}

- (BOOL)refreshRequired {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"refreshPagesRequired"]) { 
		[defaults setBool:false forKey:@"refreshPagesRequired"];
		return YES;
	}
	
	return NO;
}

- (void)loadMoreItemsWithBlock:(void (^)())block {
	[self.blog syncPagesWithSuccess:block failure:^(NSError *error) {
        if (block) block();
    } loadMore:YES];
}

#pragma mark -
#pragma mark Fetched results controller

- (NSString *)entityName {
    return @"Page";
}

@end
