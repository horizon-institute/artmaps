//
//  SidebarViewController.m
//  WordPress
//
//  Created by Jorge Bernal on 5/21/12.
//  Copyright (c) 2012 WordPress. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "SidebarViewController.h"
#import "WordPressAppDelegate.h"
#import "UIImageView+Gravatar.h"
#import "SidebarSectionHeaderView.h"
#import "SidebarTableViewCell.h"
#import "SectionInfo.h"
#import "PostsViewController.h"
#import "PagesViewController.h"
#import "CommentsViewController.h"
#import "WPReaderViewController.h"
#import "WPTableViewController.h"
#import "SettingsViewController.h"
#import "StatsWebViewController.h"
#import "PanelNavigationConstants.h"
#import "WPWebViewController.h"
#import "WordPressComApi.h"
#import "WelcomeViewController.h"
#import "CameraPlusPickerManager.h"
#import "QuickPhotoViewController.h"
#import "QuickPhotoButtonView.h"

// Height for reader/notification/blog cells
#define SIDEBAR_CELL_HEIGHT 51.0f
// Height for secondary cells (posts/pages/comments/... inside a blog)
#define SIDEBAR_CELL_SECONDARY_HEIGHT 48.0f
#define SIDEBAR_BGCOLOR [UIColor colorWithWhite:0.921875f alpha:1.0f];
#define HEADER_HEIGHT 48
#define DEFAULT_ROW_HEIGHT 48
#define NUM_ROWS 6

@interface SidebarViewController () <NSFetchedResultsControllerDelegate, QuickPhotoButtonViewDelegate> {
    QuickPhotoButtonView *quickPhotoButton;
    BOOL selectionRestored;
    NSUInteger wantedSection;
}

@property (nonatomic, retain) Post *currentQuickPost;
@property (nonatomic, retain) QuickPhotoButtonView *quickPhotoButton;
@property (nonatomic, retain) NSFetchedResultsController *resultsController;
@property (nonatomic, assign) SectionInfo *openSection;
@property (nonatomic, strong) NSMutableArray *sectionInfoArray;
@property (readonly) NSInteger topSectionRowCount;

- (SectionInfo *)sectionInfoForBlog:(Blog *)blog;
- (void)addSectionInfoForBlog:(Blog *)blog;
- (void)insertSectionInfoForBlog:(Blog *)blog atIndex:(NSUInteger)index;
- (void)showWelcomeScreenIfNeeded;
- (void)selectFirstAvailableItem;
- (void)selectFirstAvailableBlog;
- (void)selectBlogWithSection:(NSUInteger)index;

- (void)showQuickPhoto:(UIImagePickerControllerSourceType)sourceType useCameraPlus:(BOOL)useCameraPlus withImage:(UIImage *)image;
- (void)showQuickPhoto:(UIImagePickerControllerSourceType)sourceType useCameraPlus:(BOOL)useCameraPlus;
- (void)showQuickPhoto:(UIImagePickerControllerSourceType)sourceType;
- (void)postDidUploadSuccessfully:(NSNotification *)notification;
- (void)postUploadFailed:(NSNotification *)notification;
- (void)setupQuickPhotoButton;
- (void)tearDownQuickPhotoButton;
- (void)handleCameraPlusImages:(NSNotification *)notification;
- (void)presentContent;

@end

@implementation SidebarViewController

@synthesize resultsController = _resultsController, openSection=_openSection, sectionInfoArray=_sectionInfoArray;
@synthesize tableView, settingsButton, quickPhotoButton;
@synthesize currentQuickPost = _currentQuickPost;
@synthesize utililtyView;

- (void)dealloc {
    self.resultsController.delegate = nil;
    self.resultsController = nil;
    self.utililtyView = nil;
    self.tableView = nil;
    self.settingsButton = nil;
    self.quickPhotoButton = nil;
    
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"sidebar_bg"]];

    utililtyView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"sidebar_footer_bg"]];
    utililtyView.layer.shadowRadius = 10.0f;
    utililtyView.layer.shadowOpacity = 0.8f;
    utililtyView.layer.shadowColor = [[UIColor blackColor] CGColor];
    utililtyView.layer.shadowOffset = CGSizeMake(0.0f, 5.0f);
    utililtyView.layer.shadowPath = [[UIBezierPath bezierPathWithRoundedRect:utililtyView.bounds cornerRadius:PANEL_CORNER_RADIUS] CGPath];
        
    //self.view.backgroundColor = SIDEBAR_BGCOLOR;
    self.openSection = nil;
    
    // create the sectionInfoArray, stores data for collapsing/expanding sections in the tableView
	if (self.sectionInfoArray == nil) {
        self.sectionInfoArray = [[[NSMutableArray alloc] initWithCapacity:[[self.resultsController fetchedObjects] count]] autorelease];
        // For each play, set up a corresponding SectionInfo object to contain the default height for each row.
		for (Blog *blog in [self.resultsController fetchedObjects]) {
            [self addSectionInfoForBlog:blog];
		}
	}
    
    self.settingsButton.backgroundColor = [UIColor clearColor];
    [self.settingsButton setBackgroundImage:[[UIImage imageNamed:@"SidebarToolbarButton"] stretchableImageWithLeftCapWidth:5.0 topCapHeight:0.0] forState:UIControlStateNormal];

    if ([[self.resultsController fetchedObjects] count] > 0) {
        [self setupQuickPhotoButton];
    }
    
    void (^wpcomNotificationBlock)(NSNotification *) = ^(NSNotification *note) {
        NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
        if (selectedIndexPath == nil || (selectedIndexPath.section == 0 && selectedIndexPath.row == 1)) {
            [self selectFirstAvailableItem];
        }
    };
    [[NSNotificationCenter defaultCenter] addObserverForName:WordPressComApiDidLoginNotification object:nil queue:nil usingBlock:wpcomNotificationBlock];
    [[NSNotificationCenter defaultCenter] addObserverForName:WordPressComApiDidLogoutNotification object:nil queue:nil usingBlock:wpcomNotificationBlock];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleCameraPlusImages:) name:kCameraPlusImagesNotification object:nil];

    selectionRestored = NO; // incase the view was previously loaded and later unloaded.    
}

- (void)viewDidUnload {
    [super viewDidUnload];

    self.tableView = nil;
    self.settingsButton = nil;
    self.utililtyView = nil;
    self.quickPhotoButton.delegate = nil;
    self.quickPhotoButton = nil;
    
    self.sectionInfoArray = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];


        // In iOS 5, the first detailViewController that we load during launch does not
        // see its viewWillAppear and viewDidAppear methods fire. As a work around, we can
        // present our content with a slight delay, and then the events fire.
        // TODO: Find a true fix and remove this workaround.
        // See http://ios.trac.wordpress.org/ticket/1114
        [self performSelector:@selector(presentContent) withObject:self afterDelay:0.01];

}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated]; 

    if (!IS_IPAD) {
        // Called here to ensure the section is opened after launch on the iPad.
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [self restorePreservedSelection];
        });
    }
}

#pragma mark - Custom methods

- (void)presentContent {
    [self showWelcomeScreenIfNeeded];
    if (!selectionRestored) {
        [self restorePreservedSelection];
        selectionRestored = YES;
    }
}

- (NSInteger)topSectionRowCount {
    if ([WordPressComApi sharedApi].username) {
        return 1;
    } else {
        return 0;
    }
}

- (SectionInfo *)sectionInfoForBlog:(Blog *)blog {
    SectionInfo *sectionInfo = [[SectionInfo alloc] init];			
    sectionInfo.blog = blog;
    sectionInfo.open = NO;

    NSNumber *defaultRowHeight = [NSNumber numberWithInteger:DEFAULT_ROW_HEIGHT];
    for (NSInteger i = 0; i < NUM_ROWS; i++) {
        [sectionInfo insertObject:defaultRowHeight inRowHeightsAtIndex:i];
    }

    return sectionInfo;
}

- (void)addSectionInfoForBlog:(Blog *)blog {    
    [self.sectionInfoArray addObject:[self sectionInfoForBlog:blog]];
}

- (void)insertSectionInfoForBlog:(Blog *)blog atIndex:(NSUInteger)index {
    [self.sectionInfoArray insertObject:[self sectionInfoForBlog:blog] atIndex:index];
}

- (void)showWelcomeScreenIfNeeded {
     WPFLogMethod();
    if ( [[self.resultsController fetchedObjects] count] == 0 ) {
        //ohh poor boy, no blogs yet?
        if ( ! [WordPressComApi sharedApi].username ) {
            //ohh auch! no .COM account? 
            WelcomeViewController *welcomeViewController = nil;
            welcomeViewController = [[WelcomeViewController alloc] initWithNibName:@"WelcomeViewController" bundle:[NSBundle mainBundle]];
            [welcomeViewController automaticallyDismissOnLoginActions];
            
            UINavigationController *aNavigationController = [[[UINavigationController alloc] initWithRootViewController:welcomeViewController] autorelease];
            aNavigationController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
            aNavigationController.modalPresentationStyle = UIModalPresentationFormSheet;

            [self.panelNavigationController presentModalViewController:aNavigationController animated:YES];
            [welcomeViewController release];
        }
    }
}

- (void)selectFirstAvailableItem {
    if ([self.tableView indexPathForSelectedRow] != nil) {
        return;
    }

    if ([self.tableView numberOfRowsInSection:0] > 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        [self processRowSelectionAtIndexPath:indexPath];
        [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    } else {
        [self selectFirstAvailableBlog];
    }
}

- (void)selectFirstAvailableBlog {
    if ([self.sectionInfoArray count] > 0) {
        [self selectBlogWithSection:1];
    }
}

- (void)selectBlogWithSection:(NSUInteger)index {
    SectionInfo *sectionInfo = [self.sectionInfoArray objectAtIndex:index - 1];
    if (!sectionInfo.open) {
        [sectionInfo.headerView toggleOpenWithUserAction:YES];
    }
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:index];
    [self processRowSelectionAtIndexPath:indexPath closingSidebar:NO];
    [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
}

- (void)showCommentWithId:(NSNumber *)itemId blogId:(NSNumber *)blogId {
    __block SectionInfo *targetSection;
    __block NSUInteger sectionNumber;
    [self.sectionInfoArray enumerateObjectsUsingBlock:^(SectionInfo *obj, NSUInteger idx, BOOL *stop) {
        if ([obj.blog.blogID isEqualToNumber:blogId]) {
            targetSection = obj;
            sectionNumber = idx;
            *stop = YES;
        }
    }];
    
    if (targetSection) {
        if (!targetSection.open) {
            [targetSection.headerView toggleOpenWithUserAction:YES];
        }
        NSIndexPath *commentsPath = [NSIndexPath indexPathForRow:2 inSection:sectionNumber+1];
        [self processRowSelectionAtIndexPath:commentsPath];
        [self.tableView selectRowAtIndexPath:commentsPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        if ([self.panelNavigationController.detailViewController respondsToSelector:@selector(setWantedCommentId:)]) {
            [self.panelNavigationController.detailViewController performSelector:@selector(setWantedCommentId:) withObject:itemId];
        }
    }
}

- (IBAction)showSettings:(id)sender {
    SettingsViewController *settingsViewController = [[[SettingsViewController alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
    UINavigationController *aNavigationController = [[[UINavigationController alloc] initWithRootViewController:settingsViewController] autorelease];
    aNavigationController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    aNavigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    
    [self.panelNavigationController presentModalViewController:aNavigationController animated:YES];
}


- (void)restorePreservedSelection {
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"kSelectedSidebarIndexDictionary"];
    NSIndexPath *preservedIndexPath = [NSIndexPath indexPathForRow:[[dict objectForKey:@"row"] integerValue] inSection:[[dict objectForKey:@"section"] integerValue]];
    
    if (preservedIndexPath.section > 0 && ((preservedIndexPath.section - 1) < [self.resultsController.fetchedObjects count] )) {
        if ([self.sectionInfoArray count] > (preservedIndexPath.section - 1)) {
            SectionInfo *sectionInfo = [self.sectionInfoArray objectAtIndex:(preservedIndexPath.section -1)];
            if (!sectionInfo.open) {
                [sectionInfo.headerView toggleOpenWithUserAction:YES];
            }
            
            [self processRowSelectionAtIndexPath:preservedIndexPath closingSidebar:NO];
            [self.tableView selectRowAtIndexPath:preservedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }        
    } else {
        [self selectFirstAvailableItem];
    }
}

#pragma mark - Quick Photo Methods

- (void)quickPhotoButtonViewTapped:(QuickPhotoButtonView *)sender {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
    
	UIActionSheet *actionSheet = nil;
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        if ([[CameraPlusPickerManager sharedManager] cameraPlusPickerAvailable]) {
            actionSheet = [[UIActionSheet alloc] initWithTitle:@"" 
                                                      delegate:self 
                                             cancelButtonTitle:NSLocalizedString(@"Cancel", @"") 
                                        destructiveButtonTitle:nil 
                                             otherButtonTitles:NSLocalizedString(@"Add Photo from Library", @""),NSLocalizedString(@"Take Photo", @""),NSLocalizedString(@"Add Photo from Camera+", @""), NSLocalizedString(@"Take Photo with Camera+", @""),nil];
        } else {
            actionSheet = [[UIActionSheet alloc] initWithTitle:@"" 
                                                      delegate:self 
                                             cancelButtonTitle:NSLocalizedString(@"Cancel", @"") 
                                        destructiveButtonTitle:nil 
                                             otherButtonTitles:NSLocalizedString(@"Add Photo from Library", @""),NSLocalizedString(@"Take Photo", @""),nil];            
        }
	} else {
        [self showQuickPhoto:UIImagePickerControllerSourceTypePhotoLibrary useCameraPlus:NO withImage:nil];
        return;
	}
    
    actionSheet.actionSheetStyle = UIActionSheetStyleDefault;
    [actionSheet showInView:self.panelNavigationController.view];
    [actionSheet release];
    
//    [appDelegate setAlertRunning:YES];
}

- (void)showQuickPhoto:(UIImagePickerControllerSourceType)sourceType {
    [self showQuickPhoto:sourceType useCameraPlus:NO withImage:nil];
}

- (void)showQuickPhoto:(UIImagePickerControllerSourceType)sourceType useCameraPlus:(BOOL)useCameraPlus {
    if (useCameraPlus) {
        CameraPlusPickerManager *picker = [CameraPlusPickerManager sharedManager];
        picker.callbackURLProtocol = @"wordpress";
        picker.maxImages = 1;
        picker.imageSize = 4096;
        CameraPlusPickerMode mode = (sourceType == UIImagePickerControllerSourceTypeCamera) ? CameraPlusPickerModeShootOnly : CameraPlusPickerModeLightboxOnly;
        [picker openCameraPlusPickerWithMode:mode];
    } else {
        [self showQuickPhoto:sourceType useCameraPlus:useCameraPlus withImage:nil];
    }
}

- (void)showQuickPhoto:(UIImagePickerControllerSourceType)sourceType useCameraPlus:(BOOL)useCameraPlus withImage:(UIImage *)image {
    QuickPhotoViewController *quickPhotoViewController = [[QuickPhotoViewController alloc] init];
    quickPhotoViewController.sidebarViewController = self;
    quickPhotoViewController.photo = image;
    if (!image) {
        quickPhotoViewController.sourceType = sourceType;
    }
    quickPhotoViewController.isCameraPlus = useCameraPlus;

    Blog *startingBlog = nil;
    if ([self openSection]) {
        startingBlog = [self.resultsController objectAtIndexPath:[NSIndexPath indexPathForRow:openSectionIdx-1 inSection:0]];
    } else {
        startingBlog = [self.resultsController objectAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    }
    quickPhotoViewController.startingBlog = startingBlog;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:quickPhotoViewController];
    if (IS_IPAD) {
        // TODO: Figure out the best way to present this on the ipad.
        navController.modalPresentationStyle = UIModalPresentationFormSheet;
        navController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        [self.panelNavigationController presentModalViewController:navController animated:YES];
    } else {
        navController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        [self.panelNavigationController presentModalViewController:navController animated:YES];
    }
    [quickPhotoViewController release];
    [navController release];
}

- (void)uploadQuickPhoto:(Post *)post {
    if (post != nil) {
        self.currentQuickPost = post;
        [quickPhotoButton showProgress:YES animated:YES];
    }
}

- (void)postDidUploadSuccessfully:(NSNotification *)notification {
//    appDelegate.isUploadingPost = NO;
    self.currentQuickPost = nil;
    [quickPhotoButton showSuccess];
}

- (void)postUploadFailed:(NSNotification *)notification {
//    appDelegate.isUploadingPost = NO;
    self.currentQuickPost = nil;
    [quickPhotoButton showProgress:NO animated:YES];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Quick Photo Failed", @"")
                                                    message:NSLocalizedString(@"Sorry, the photo publish failed. The post has been saved as a Local Draft.", @"")
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                          otherButtonTitles:nil];
    [alert show];
    [alert release];
}

- (void)setCurrentQuickPost:(Post *)currentQuickPost {
    if (currentQuickPost != _currentQuickPost) {
        if (_currentQuickPost) {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:@"PostUploaded" object:_currentQuickPost];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:@"PostUploadFailed" object:_currentQuickPost];
            [_currentQuickPost release];
        }
        _currentQuickPost = [currentQuickPost retain];
        if (_currentQuickPost) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postDidUploadSuccessfully:) name:@"PostUploaded" object:currentQuickPost];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postUploadFailed:) name:@"PostUploadFailed" object:currentQuickPost];
        }
    }
}

- (void)setupQuickPhotoButton {    
    if (quickPhotoButton) return;
    
    CGFloat availableWidth = self.view.frame.size.width;    
    CGFloat buttonWidth = (availableWidth - 30.0f)/2; // 10px margins + 10px gap

    // Make room for the photo button
    CGRect settingsFrame = settingsButton.frame;
    settingsFrame.size.width = buttonWidth;
    settingsFrame.origin.x = availableWidth - (buttonWidth + 10.0f);
    settingsButton.frame = settingsFrame;
    
    // Match the height and y of the settings Button.
    CGRect frame = CGRectMake(10.0f, settingsFrame.origin.y, buttonWidth, settingsFrame.size.height);
    self.quickPhotoButton = [[[QuickPhotoButtonView alloc] initWithFrame:frame] autorelease];
    quickPhotoButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    quickPhotoButton.delegate = self;
    
    [self.view addSubview:quickPhotoButton];
}

- (void)tearDownQuickPhotoButton {
    if (!quickPhotoButton) return;

    [quickPhotoButton removeFromSuperview];
    quickPhotoButton.delegate = nil;
    self.quickPhotoButton = nil;
    
    CGRect frame = settingsButton.frame;
    frame.origin.x = 10.0f;
    settingsButton.frame = frame;
}

- (void)handleCameraPlusImages:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    UIImage *image = [userInfo objectForKey:@"image"];
    // The source type isn't really important since we're also passing an image.
    [self showQuickPhoto:UIImagePickerControllerSourceTypePhotoLibrary useCameraPlus:YES withImage:image];
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if(buttonIndex == 0) {
        [self showQuickPhoto:UIImagePickerControllerSourceTypePhotoLibrary];
    } else if(buttonIndex == 1) {
        [self showQuickPhoto:UIImagePickerControllerSourceTypeCamera];
    } else if(buttonIndex == 2) {
        [self showQuickPhoto:UIImagePickerControllerSourceTypePhotoLibrary useCameraPlus:YES];
    } else if(buttonIndex == 3) {
        [self showQuickPhoto:UIImagePickerControllerSourceTypeCamera useCameraPlus:YES];
    }
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of blogs + the top section
    return [[self.resultsController fetchedObjects] count] + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return self.topSectionRowCount;
    } else {
        SectionInfo *sectionInfo = [self.sectionInfoArray objectAtIndex:section - 1];
        return sectionInfo.open ? NUM_ROWS : 0;
    }
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0)
        return 0.0f;
    else 
        return HEADER_HEIGHT;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return SIDEBAR_CELL_SECONDARY_HEIGHT;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0)
        return nil;
    Blog *blog = [self.resultsController objectAtIndexPath:[NSIndexPath indexPathForRow:(section - 1) inSection:0]];
    SectionInfo *sectionInfo = [self.sectionInfoArray objectAtIndex:section - 1];
    if (!sectionInfo.headerView) {
        sectionInfo.headerView = [[[SidebarSectionHeaderView alloc] initWithFrame:CGRectMake(0.0, 0.0, SIDEBAR_WIDTH, HEADER_HEIGHT) blog:blog sectionInfo:sectionInfo delegate:self] autorelease];
    }

    return sectionInfo.headerView;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"SideBarCell";
    SidebarTableViewCell *cell = (SidebarTableViewCell *)[aTableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[SidebarTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        cell.textLabel.shadowOffset = CGSizeMake(0, 1.1f);
        cell.textLabel.shadowColor = [UIColor blackColor];
        cell.textLabel.textColor = [UIColor colorWithRed:221.0f/255.0f green:221.0f/255.0f blue:221.0f/255.0f alpha:1.0f];
        cell.textLabel.font = [UIFont systemFontOfSize:17.0];
        cell.backgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sidebar_cell_bg"]] autorelease];
        cell.selectedBackgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sidebar_cell_bg_selected"]] autorelease];
        
    }
    
    NSString *title = nil;
      
    if (indexPath.section == 0) {
        title = NSLocalizedString(@"Read", @"");
        cell.imageView.image = [UIImage imageNamed:@"sidebar_read"];
    } else {
        switch (indexPath.row) {
            case 0:
                title = NSLocalizedString(@"Posts", @"");
                cell.imageView.image = [UIImage imageNamed:@"sidebar_posts"];
                break;
            case 1:
                title = NSLocalizedString(@"Pages", @"");
                cell.imageView.image = [UIImage imageNamed:@"sidebar_pages"];
                break;
            case 2:
                title = NSLocalizedString(@"Comments", @"");
                Blog *blog = [self.resultsController objectAtIndexPath:[NSIndexPath indexPathForRow:(indexPath.section - 1) inSection:0]];
                cell.blog = blog;
                cell.imageView.image = [UIImage imageNamed:@"sidebar_comments"];
                break;
            case 3:
                title = NSLocalizedString(@"Stats", @"");
                cell.imageView.image = [UIImage imageNamed:@"sidebar_stats"];
                break;
            case 4:
                title = NSLocalizedString(@"View Site", @"");
                cell.imageView.image = [UIImage imageNamed:@"sidebar_view"];
                break;
            case 5:
                title = NSLocalizedString(@"Dashboard", @"Button to load the dashboard in a web view");
                cell.imageView.image = [UIImage imageNamed:@"sidebar_dashboard"];
                break;
            default:
                break;
        }
    }
    
    cell.textLabel.text = title;
    cell.textLabel.backgroundColor = SIDEBAR_BGCOLOR;
    
    return cell;
}

#pragma mark Section header delegate

-(void)sectionHeaderView:(SidebarSectionHeaderView*)sectionHeaderView sectionOpened:(SectionInfo *)sectionOpened {
	sectionOpened.open = YES;
    NSUInteger sectionNumber = [self.sectionInfoArray indexOfObject:sectionOpened] + 1;
    openSectionIdx = sectionNumber;
    
    /*
     Create an array containing the index paths of the rows to insert: These correspond to the rows for each quotation in the current section.
     */
    NSMutableArray *indexPathsToInsert = [NSMutableArray array];
    for (NSInteger i = 0; i < NUM_ROWS; i++) {
        [indexPathsToInsert addObject:[NSIndexPath indexPathForRow:i inSection:sectionNumber]];
    }
    
    /*
     Create an array containing the index paths of the rows to delete: These correspond to the rows for each quotation in the previously-open section, if there was one.
     */
    NSMutableArray *indexPathsToDelete = [NSMutableArray array];
    
    SectionInfo *previousOpenSection = self.openSection;
    NSUInteger previousOpenSectionIndex = NSNotFound;
    if (previousOpenSection) {
        previousOpenSection.open = NO;
        [previousOpenSection.headerView toggleOpenWithUserAction:NO];
        previousOpenSectionIndex = [self.sectionInfoArray indexOfObject:previousOpenSection] + 1;
        for (NSInteger i = 0; i < NUM_ROWS; i++) {
            [indexPathsToDelete addObject:[NSIndexPath indexPathForRow:i inSection:previousOpenSectionIndex]];
        }
    }
    
    // Style the animation so that there's a smooth flow in either direction.
    UITableViewRowAnimation insertAnimation;
    UITableViewRowAnimation deleteAnimation;
    if (previousOpenSectionIndex == NSNotFound || sectionNumber < previousOpenSectionIndex) {
        insertAnimation = UITableViewRowAnimationTop;
        deleteAnimation = UITableViewRowAnimationBottom;
    }
    else {
        insertAnimation = UITableViewRowAnimationBottom;
        deleteAnimation = UITableViewRowAnimationTop;
    }
    
    // Apply the updates.
    [self.tableView beginUpdates];
    [self.tableView insertRowsAtIndexPaths:indexPathsToInsert withRowAnimation:insertAnimation];
    [self.tableView deleteRowsAtIndexPaths:indexPathsToDelete withRowAnimation:deleteAnimation];
    [self.tableView endUpdates];
    self.openSection = sectionOpened;
    // select the first row in the section
    // if we don't, a) you lose the current selection, b) the sidebar doesn't open on iPad
    [self.tableView selectRowAtIndexPath:[indexPathsToInsert objectAtIndex:0] animated:NO scrollPosition:UITableViewScrollPositionNone];    
    [self processRowSelectionAtIndexPath:[indexPathsToInsert objectAtIndex:0] closingSidebar:NO];
}


-(void)sectionHeaderView:(SidebarSectionHeaderView*)sectionHeaderView sectionClosed:(SectionInfo *)sectionClosed {    
    NSUInteger sectionNumber = [self.sectionInfoArray indexOfObject:sectionClosed] + 1;
	sectionClosed.open = NO;

    NSMutableArray *indexPathsToDelete = [[NSMutableArray alloc] init];
    for (NSInteger i = 0; i < NUM_ROWS; i++) {
        [indexPathsToDelete addObject:[NSIndexPath indexPathForRow:i inSection:sectionNumber]];
    }
    [self.tableView deleteRowsAtIndexPaths:indexPathsToDelete withRowAnimation:UITableViewRowAnimationTop];
    self.openSection = nil;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self processRowSelectionAtIndexPath:indexPath];
}

- (void) processRowSelectionAtIndexPath: (NSIndexPath *) indexPath {
    [self processRowSelectionAtIndexPath:indexPath closingSidebar:YES];
}



- (void) processRowSelectionAtIndexPath:(NSIndexPath *)indexPath closingSidebar:(BOOL)closingSidebar {
    WPFLog(@"%@ %@ %@", self, NSStringFromSelector(_cmd), indexPath);
    
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:indexPath.row], @"row", [NSNumber numberWithInteger:indexPath.section], @"section", nil];
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:@"kSelectedSidebarIndexDictionary"];
    [NSUserDefaults resetStandardUserDefaults];
    
    UIViewController *detailViewController = nil;  
    if (indexPath.section == 0) { //Reader
        
        if ([self.panelNavigationController.detailViewController isMemberOfClass:[WPReaderViewController class]]) {
            // Reader was already selected
            if (IS_IPAD) {
                [self.panelNavigationController showSidebar];
            } else {
                [self.panelNavigationController popToRootViewControllerAnimated:NO];
                [self.panelNavigationController closeSidebar];
            }
            return;
        }
        // Reader
        WPReaderViewController *readerViewController = [[[WPReaderViewController alloc] init] autorelease];
        detailViewController = readerViewController;

    } else {
        Blog *blog = [self.resultsController objectAtIndexPath:[NSIndexPath indexPathForRow:(indexPath.section - 1) inSection:0]];

        Class controllerClass = nil;
        //did user select the same item, but for a different blog? If so then just update the data in the view controller.
        switch (indexPath.row) {
            case 0:
                 controllerClass = [PostsViewController class];
                break;
            case 1:
                controllerClass = [PagesViewController class];
                break;
            case 2:
                controllerClass = [CommentsViewController class];
                break;
            case 3:
                controllerClass =  [StatsWebViewController class];//IS_IPAD ? [StatsWebViewController class] : [StatsTableViewController class];
                break;
            case 4:
                controllerClass = [WPWebViewController class];
                NSString *blogURL = blog.url;
                if(![blogURL hasPrefix:@"http"])
                    blogURL = [NSString stringWithFormat:@"http://%@", blogURL];
                //check if the same site already loaded
                if ([self.panelNavigationController.detailViewController isMemberOfClass:[WPWebViewController class]]
                    &&
                    [((WPWebViewController*)self.panelNavigationController.detailViewController).url.absoluteString isEqual:blogURL]
                    ) {
                    if (IS_IPAD) {
                        [self.panelNavigationController showSidebar];
                    } else {
                        [self.panelNavigationController popToRootViewControllerAnimated:NO];
                        [self.panelNavigationController closeSidebar];
                    }
                } else {
                    WPWebViewController *webViewController;
                    if ( IS_IPAD ) {
                        webViewController = [[[WPWebViewController alloc] initWithNibName:@"WPWebViewController-iPad" bundle:nil] autorelease];
                    }
                    else {
                        webViewController = [[[WPWebViewController alloc] initWithNibName:@"WPWebViewController" bundle:nil] autorelease];
                    }
                    
                    [webViewController setUrl:[NSURL URLWithString:blogURL]];
                    if( [blog isPrivate] ) {
                        [webViewController setUsername:blog.username];
                        [webViewController setPassword:[blog fetchPassword]];
                        [webViewController setWpLoginURL:[NSURL URLWithString:blog.loginURL]];
                    }
                    [self.panelNavigationController setDetailViewController:webViewController closingSidebar:closingSidebar];
                }        
                return;
            case 5:
                controllerClass = [WPWebViewController class];
                 NSString *dashboardURL = [blog.xmlrpc stringByReplacingOccurrencesOfString:@"xmlrpc.php" withString:@"wp-admin/"];
                //dashboard already selected
                if ([self.panelNavigationController.detailViewController isMemberOfClass:[WPWebViewController class]] 
                    && 
                    [((WPWebViewController*)self.panelNavigationController.detailViewController).url.absoluteString isEqual:dashboardURL]
                    ) {
                    if (IS_IPAD) {
                        [self.panelNavigationController showSidebar];
                    } else {
                        [self.panelNavigationController popToRootViewControllerAnimated:NO];
                        [self.panelNavigationController closeSidebar];
                    }
                } else {
                    
                    WPWebViewController *webViewController;
                    if ( IS_IPAD ) {
                        webViewController = [[[WPWebViewController alloc] initWithNibName:@"WPWebViewController-iPad" bundle:nil] autorelease];
                    }
                    else {
                        webViewController = [[[WPWebViewController alloc] initWithNibName:@"WPWebViewController" bundle:nil] autorelease];
                    }
                    [webViewController setUrl:[NSURL URLWithString:dashboardURL]];
                    [webViewController setUsername:blog.username];
                    [webViewController setPassword:[blog fetchPassword]];
                    [webViewController setWpLoginURL:[NSURL URLWithString:blog.loginURL]];
                    [self.panelNavigationController setDetailViewController:webViewController closingSidebar:closingSidebar];
                }                
                return;
            default:
                controllerClass = [PostsViewController class];
                break;
        }
        
        //Check if the controller is already on the screen
        if ([self.panelNavigationController.detailViewController isMemberOfClass:controllerClass] && [self.panelNavigationController.detailViewController respondsToSelector:@selector(setBlog:)]) {
            [self.panelNavigationController.detailViewController performSelector:@selector(setBlog:) withObject:blog];
            if (IS_IPAD) {
                [self.panelNavigationController showSidebar];
            } else {
                [self.panelNavigationController popToRootViewControllerAnimated:NO];
                if ( closingSidebar )
                    [self.panelNavigationController closeSidebar];
            }
            return;
        } else {
            detailViewController = (UIViewController *)[[[controllerClass alloc] init] autorelease];
            if ([detailViewController respondsToSelector:@selector(setBlog:)]) {
                [detailViewController performSelector:@selector(setBlog:) withObject:blog];
            }
        }
    } 

    if (detailViewController) {
        [self.panelNavigationController setDetailViewController:detailViewController closingSidebar:closingSidebar];
    }
}

#pragma mark - Accessor methods

- (NSFetchedResultsController *)resultsController {
    if (_resultsController != nil) return _resultsController;

    NSManagedObjectContext *moc = [[WordPressAppDelegate sharedWordPressApp] managedObjectContext];

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Blog" inManagedObjectContext:moc]];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"blogName" ascending:YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // For some reasons, the cache sometimes gets corrupted
    // Since we don't really use sections we skip the cache here
    _resultsController = [[NSFetchedResultsController alloc]
                          initWithFetchRequest:fetchRequest
                          managedObjectContext:moc
                          sectionNameKeyPath:nil
                          cacheName:nil];
    _resultsController.delegate = self;

    [sortDescriptors release];
    [sortDescriptor release];
    [fetchRequest release];

    NSError *error = nil;
    if (![_resultsController performFetch:&error]) {
        WPFLog(@"Couldn't fecth blogs: %@", [error localizedDescription]);
        [_resultsController release];
        _resultsController = nil;
    }
    
    return _resultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
    if (indexPath) {
        wantedSection = indexPath.section;
    } else {
        wantedSection = 0;
    }
    [self.tableView beginUpdates];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
    if (indexPath) {
        if (indexPath.section != wantedSection) {
            if (wantedSection > 0) {
                [self selectBlogWithSection:wantedSection];
            } else {
                [self selectFirstAvailableItem];
            }
        }
    } else {
        [self selectFirstAvailableItem];
    }
    if([[self.resultsController fetchedObjects] count] > 0){
        [self setupQuickPhotoButton];
    } else {
        [self tearDownQuickPhotoButton];
    }
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    
    if (NSFetchedResultsChangeUpdate == type && newIndexPath != nil) {
        // Seriously, Apple?
        // http://developer.apple.com/library/ios/#releasenotes/iPhone/NSFetchedResultsChangeMoveReportedAsNSFetchedResultsChangeUpdate/_index.html
        type = NSFetchedResultsChangeMove;
    }
    
    switch (type) {
        case NSFetchedResultsChangeInsert:
            NSLog(@"Inserting row %d: %@", newIndexPath.row, anObject);
            [self insertSectionInfoForBlog:anObject atIndex:newIndexPath.row];
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:newIndexPath.row + 1] withRowAnimation:UITableViewRowAnimationFade];
            wantedSection = newIndexPath.row + 1;
            break;
        case NSFetchedResultsChangeDelete:
            NSLog(@"Deleting row %d: %@", indexPath.row, anObject);
            SectionInfo *sectionInfo = [self.sectionInfoArray objectAtIndex:indexPath.row];
            if (sectionInfo.open) {
                NSMutableArray *indexPathsToDelete = [[NSMutableArray alloc] init];                
                for (NSInteger i = 0; i < NUM_ROWS; i++) {
                    [indexPathsToDelete addObject:[NSIndexPath indexPathForRow:i inSection:indexPath.row + 1]];
                }
                [self.tableView deleteRowsAtIndexPaths:indexPathsToDelete withRowAnimation:UITableViewRowAnimationFade];
                [indexPathsToDelete release];
            }
            if (self.openSection == sectionInfo) {
                self.openSection = nil;
                wantedSection = 0;
            }
            [self.sectionInfoArray removeObjectAtIndex:indexPath.row];
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.row + 1] withRowAnimation:UITableViewRowAnimationFade];
            //[self showWelcomeScreenIfNeeded];
            break;
    }
}

@end
