#import "EditPostViewController.h"
#import "WordPressAppDelegate.h"
#import "WPSegmentedSelectionTableViewController.h"
#import "CPopoverManager.h"
#import "NSString+XMLExtensions.h"

//Horizon code
#import "HIOoIViewController.h"
#import "RestAPIConnector.h"
#import "PostMapLocation.h"
#import "NSString+HTML.h"

NSTimeInterval kAnimationDuration = 0.3f;


@interface EditPostViewController (Private)
- (BOOL) isMediaInUploading;
- (void) showMediaInUploadingalert;
- (void)restoreText:(NSString *)text withRange:(NSRange)range;
- (void)populateSelectionsControllerWithCategories;
- (void)displayPOIMapViewController;
@end

@implementation EditPostViewController

@synthesize selectionTableViewController, segmentedTableViewController;
@synthesize infoText, urlField, bookMarksArray, selectedLinkRange, currentEditingTextField, isEditing, initialLocation;
@synthesize editingDisabled, editCustomFields, statuses, isLocalDraft;
@synthesize textView, contentView, subView, textViewContentView, statusTextField, categoriesButton, titleTextField;
@synthesize tagsTextField, textViewPlaceHolderField, tagsLabel, statusLabel, categoriesLabel, titleLabel, customFieldsEditButton;
@synthesize locationButton, locationSpinner, createCategoryBarButtonItem, hasLocation;
@synthesize editMode, apost;
@synthesize hasSaved, isVisible, isPublishing;
@synthesize toolbar;
@synthesize photoButton, movieButton;
@synthesize undoButton, redoButton;

//Horizon code
@synthesize postMapLocation;
NSString *IFrame_Format = @"<iframe src=\"%@\" width=\"%d\" height=\"%d\"/>"; 

#pragma mark -
#pragma mark LifeCycle Methods

- (void)dealloc {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
	self.hasLocation = nil;
    //	[statuses release];
    [postMediaViewController release];
	[postPreviewViewController release];
    [postSettingsController release];
    [writeButton release];
    [settingsButton release];
	[textView release];
	[contentView release];
	[subView release];
	[textViewContentView release];
	[statusTextField release];
	[categoriesButton release];
	[titleTextField release];
	[tagsTextField release];
	[textViewPlaceHolderField release];
	[tagsLabel release];
	[statusLabel release];
	[categoriesLabel release];
	[titleLabel release];
	[customFieldsEditButton release];
	[locationButton release];
	[locationSpinner release];
	[createCategoryBarButtonItem release];
    [infoText release];
    [urlField release];
    [bookMarksArray release];
    [segmentedTableViewController release];
    [editorToolbar release];
    //Horizon code.
    [postMapLocation release];
    
    [super dealloc];
}


- (id)initWithPost:(AbstractPost *)aPost {
    NSString *nib;
    if (IS_IPAD) {
        nib = @"EditPostViewController-iPad";
    } else {
        nib = @"EditPostViewController";
    }
    
    if (self = [super initWithNibName:nib bundle:nil]) {
        self.apost = aPost;
    }
    
    return self;
}

- (void)viewDidUnload {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];

    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [postSettingsController release]; postSettingsController = nil;
    [postMediaViewController release]; postMediaViewController = nil;
    [postPreviewViewController release]; postPreviewViewController = nil;
    [statuses release]; statuses = nil;
    [spinner release]; spinner = nil;
    self.textView.inputAccessoryView = nil;
    [editorToolbar release];
    editorToolbar = nil;
    
    // Release IBOutlets
    self.locationButton = nil;
    self.locationSpinner = nil;
    self.textView = nil;
    self.toolbar = nil;
    self.contentView = nil;
    self.subView = nil;
    self.textViewContentView = nil;
    self.statusTextField = nil;
    self.categoriesButton = nil;
    self.titleTextField = nil;
    self.tagsTextField = nil;
    self.textViewPlaceHolderField = nil;
    self.tagsLabel = nil;
    self.statusLabel = nil;
    self.categoriesLabel = nil;
    self.titleLabel = nil;
    self.createCategoryBarButtonItem = nil;
    self.hasLocation = nil;
    self.photoButton = nil;
    self.movieButton = nil;
    self.undoButton = nil;
    self.redoButton = nil;
    //Horizon code
    self.postMapLocation = nil;

    [super viewDidUnload];
}

- (void)viewDidLoad {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
    [super viewDidLoad];

    titleLabel.text = NSLocalizedString(@"Title:", @"Label for the title of the post field. Should be the same as WP core.");
    tagsLabel.text = NSLocalizedString(@"Tags:", @"Label for the tags field. Should be the same as WP core.");
    tagsTextField.placeholder = NSLocalizedString(@"Separate tags with commas", @"Placeholder text for the tags field. Should be the same as WP core.");
    categoriesLabel.text = NSLocalizedString(@"Categories:", @"Label for the categories field. Should be the same as WP core.");
    textViewPlaceHolderField.placeholder = NSLocalizedString(@"Tap here to begin writing", @"Placeholder for the main body text. Should hint at tapping to enter text (not specifying body text).");
	textViewPlaceHolderField.textAlignment = UITextAlignmentCenter; 

    if ([textView respondsToSelector:@selector(setInputAccessoryView:)]) {
        CGRect frame;
        if (IS_IPAD) {
            frame = CGRectMake(0, 0, self.view.frame.size.width, WPKT_HEIGHT_IPAD_PORTRAIT);
        } else {
            frame = CGRectMake(0, 0, self.view.frame.size.width, WPKT_HEIGHT_IPHONE_PORTRAIT);
        }
        if (editorToolbar == nil) {
            editorToolbar = [[WPKeyboardToolbar alloc] initWithFrame:frame];
            editorToolbar.delegate = self;
        }
        textView.inputAccessoryView = editorToolbar;
    }

    postSettingsController = [[PostSettingsViewController alloc] initWithNibName:@"PostSettingsViewController" bundle:nil];
    postSettingsController.postDetailViewController = self;
    postSettingsController.view.frame = editView.frame;
    
    postMediaViewController = [[PostMediaViewController alloc] initWithNibName:@"PostMediaViewController" bundle:nil];
    postMediaViewController.postDetailViewController = self;
    postMediaViewController.view.frame = editView.frame;
	
	postPreviewViewController = [[PostPreviewViewController alloc] initWithNibName:@"PostPreviewViewController" bundle:nil];
    postPreviewViewController.postDetailViewController = self;
    postPreviewViewController.view.frame = editView.frame;
    
	self.title = NSLocalizedString(@"Write", @"Post Editor screen title.");
	statuses = [[NSArray arrayWithObjects:NSLocalizedString(@"Local Draft", @"Post status label in the posts list if the post has not yet been synced to the remote server."), NSLocalizedString(@"Draft", @"Post status label in the posts list if the post is a draft."), NSLocalizedString(@"Private", @"Post status label in the posts list if the post is marked as private. Should be the same as WP core."), NSLocalizedString(@"Pending review", @"Post status label in the post list if the post is pending review. Should be the same as WP core."), NSLocalizedString(@"Published", @"Post status to indicate that the post is live and published. Should be the same as WP core."), nil] retain];
	
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceDidRotate:) name:@"UIDeviceOrientationDidChangeNotification" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(save) name:@"EditPostViewShouldSave" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publish) name:@"EditPostViewShouldPublish" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newCategoryCreatedNotificationReceived:) name:WPNewCategoryCreatedAndUpdatedInBlogNotificationName object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(insertMediaAbove:) name:@"ShouldInsertMediaAbove" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(insertMediaBelow:) name:@"ShouldInsertMediaBelow" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeMedia:) name:@"ShouldRemoveMedia" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismissAlertViewKeyboard:) name:@"DismissAlertViewKeyboard" object:nil];
	
	
    isTextViewEditing = NO;
    spinner = [[WPProgressHUD alloc] initWithLabel:NSLocalizedString(@"Saving...", @"Status message to indicate that content is saving (use an ellipsis (...) towards the end)")];
	hasSaved = NO;
    
    currentView = editView;
	writeButton.enabled = NO;
	if ([self.apost.media count]) attachmentButton.enabled = YES;
	else attachmentButton.enabled = NO;

    self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
	
	if (![postMediaViewController isDeviceSupportVideo]){
		//no video icon for older devices
		NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:toolbar.items];
		NSLog(@"toolbar items: %@", toolbarItems);
		
		[toolbarItems removeObjectAtIndex:5];
		[toolbar setItems:toolbarItems];
	}
	
	if (self.post && self.post.geolocation != nil && self.post.blog.geolocationEnabled) {
		self.hasLocation.enabled = YES;
	} else {
		self.hasLocation.enabled = NO;
	}

    if(self.editMode == kEditPost)
        [self refreshUIForCurrentPost];
	else if(self.editMode == kNewPost)
        [self refreshUIForCompose];
	else if (self.editMode == kAutorecoverPost) {
        [self refreshUIForCurrentPost];
	}
    
    if ([writeButton respondsToSelector:@selector(setTintColor:)]) {
        UIColor *color = [UIColor UIColorFromHex:0x464646];
        writeButton.tintColor = color;
        settingsButton.tintColor = color;
        previewButton.tintColor = color;
        attachmentButton.tintColor = color;
        photoButton.tintColor = color;
        movieButton.tintColor = color;
    }
    
    // TODO: remove this when sunset support for iOS 4 and either
    // fix the positioning in the xibs or use a different image for the pointer.
    // This moves the pointer up 1 pixel to fix its appearance on iOS 5, while preserving
    // its appearance on iOS 4.
    if ([[UIToolbar class] respondsToSelector:@selector(appearance)]) {
        CGRect frame = tabPointer.frame;
        frame.origin.y = frame.origin.y - 1;
        tabPointer.frame = frame;
    }
    
}

- (void)viewWillAppear:(BOOL)animated {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
    [super viewWillAppear:animated];
	postSettingsController.view.frame = editView.frame;
    postMediaViewController.view.frame = editView.frame;
    postPreviewViewController.view.frame = editView.frame;

    if(self.editMode != kNewPost)
		self.editMode = kRefreshPost;
	
	isVisible = YES;
		
	[self refreshButtons];
	
    textView.frame = self.normalTextFrame;
    CGRect frame = self.normalTextFrame;
    frame.origin.x += 7;
    frame.origin.y += 7;
	frame.size.width -= 14;
	frame.size.height = 200;
    textViewPlaceHolderField.frame = frame;
	textViewPlaceHolderField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	CABasicAnimation *animateWiggleIt;	
	animateWiggleIt=[CABasicAnimation animationWithKeyPath:@"transform.rotation"];
	animateWiggleIt.duration=0.15;
	animateWiggleIt.repeatCount=3;
	animateWiggleIt.autoreverses=YES;
	animateWiggleIt.fromValue=[NSNumber numberWithFloat:-0.06];
	animateWiggleIt.toValue=[NSNumber numberWithFloat:0.06];
	[textViewPlaceHolderField.layer addAnimation:animateWiggleIt forKey:@"textViewPlaceHolderField"];
	
	self.title = NSLocalizedString(@"Write", @"Post Editor screen title.");
}

- (void)viewWillDisappear:(BOOL)animated {	
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
	if(self.editMode != kNewPost)
		self.editMode = kRefreshPost;
	isVisible = NO;
	
	[titleTextField resignFirstResponder];
	[textView resignFirstResponder];
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	if(IS_IPAD) {
		return YES;
	}else if (toInterfaceOrientation == UIInterfaceOrientationPortrait) { 
		return YES; 
	}
	else if ((toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) || (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight)) {
		if (self.interfaceOrientation != toInterfaceOrientation) {
			if (isEditing)
				return YES;
			else
				return NO;
		}
	}
	
	return NO;	
}


#pragma mark -
#pragma mark Instance Methods

- (Post *)post {
    if ([self.apost isKindOfClass:[Post class]]) {
        return (Post *)self.apost;
    } else {
        return nil;
    }
}

- (void)setPost:(Post *)aPost {
    self.apost = aPost;
}

- (void)switchToView:(UIView *)newView {
	if([currentView isEqual:postPreviewViewController.view])
		[postPreviewViewController viewWillDisappear:YES];
	else if ([currentView isEqual:postSettingsController.view])
		[postSettingsController viewWillDisappear:YES];
	else if ([currentView isEqual:postMediaViewController.view])
		[postMediaViewController viewWillDisappear:YES];
    
    if ([newView isEqual:postSettingsController.view])
        [postSettingsController viewWillAppear:YES];
    else if ([newView isEqual:postPreviewViewController.view])
		[postPreviewViewController viewWillAppear:YES];
    else if ([newView isEqual:postMediaViewController.view])
		[postMediaViewController viewWillAppear:YES];
	
    if ([newView isEqual:editView]) {
		writeButton.enabled = NO;
		settingsButton.enabled = YES;
		previewButton.enabled = YES;
		if ([self.apost.media count]) attachmentButton.enabled = YES;
		else attachmentButton.enabled = NO;
    } else if ([newView isEqual:postSettingsController.view]) {
		writeButton.enabled = YES;
		settingsButton.enabled = NO;
		previewButton.enabled = YES;
		if ([self.apost.media count]) attachmentButton.enabled = YES;
		else attachmentButton.enabled = NO;
    } else if ([newView isEqual:postPreviewViewController.view]) {
		writeButton.enabled = YES;
		settingsButton.enabled = YES;
		previewButton.enabled = NO;
		if ([self.apost.media count]) attachmentButton.enabled = YES;
		else attachmentButton.enabled = NO;
	} else if ([newView isEqual:postMediaViewController.view]) {
		writeButton.enabled = YES;
		settingsButton.enabled = YES;
		previewButton.enabled = YES;
		attachmentButton.enabled = NO;
	}
	
    newView.frame = currentView.frame;
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.3];
    
	CGRect pointerFrame = tabPointer.frame;
    if ([newView isEqual:editView]) {
		pointerFrame.origin.x = 22;
    } else if ([newView isEqual:postSettingsController.view]) {
		pointerFrame.origin.x = 61;
    } else if ([newView isEqual:postPreviewViewController.view]) {
		pointerFrame.origin.x = 101;
	} else if ([newView isEqual:postMediaViewController.view]) {
		if (IS_IPAD) {
			if ([postMediaViewController isDeviceSupportVideo])
				pointerFrame.origin.x = 646;
			else
				pointerFrame.origin.x = 688;
		}
		else {
			if ([postMediaViewController isDeviceSupportVideo])
				pointerFrame.origin.x = 198;
			else
				pointerFrame.origin.x = 240;
		}
	}
	tabPointer.frame = pointerFrame;
    [currentView removeFromSuperview];
    [contentView addSubview:newView];
    
    [UIView commitAnimations];
    
	UIView *oldView = currentView;
    currentView = newView;
    
	if([oldView isEqual:postPreviewViewController.view])
		[postPreviewViewController viewDidDisappear:YES];
	else if ([oldView isEqual:postSettingsController.view])
		[postSettingsController viewDidDisappear:YES];
	else if ([oldView isEqual:postMediaViewController.view])
		[postMediaViewController viewDidDisappear:YES];
	
    if ([newView isEqual:postSettingsController.view])
        [postSettingsController viewDidAppear:YES];
    else if ([newView isEqual:postPreviewViewController.view])
		[postPreviewViewController viewDidAppear:YES];
    else if ([newView isEqual:postMediaViewController.view])
		[postMediaViewController viewDidAppear:YES];
}

- (IBAction)switchToEdit {
    if (currentView != editView) {
        [self switchToView:editView];
    }
	self.navigationItem.title = NSLocalizedString(@"Write", @"Post Editor screen title.");
}

- (IBAction)switchToSettings {
    if (currentView != postSettingsController.view) {
        [self switchToView:postSettingsController.view];
    }
	self.navigationItem.title = NSLocalizedString(@"Settings", @"Post Editor / Settings screen title.");
}

- (IBAction)switchToMedia {
    if (currentView != postMediaViewController.view) {
        [self switchToView:postMediaViewController.view];
    }
	self.navigationItem.title = NSLocalizedString(@"Media", @"Post Editor / Media screen title.");
}

- (IBAction)switchToPreview {
    if (currentView != postPreviewViewController.view) {
        [self switchToView:postPreviewViewController.view];
    }
	self.navigationItem.title = NSLocalizedString(@"Preview", @"Post Editor / Preview screen title.");
}

- (IBAction)addVideo:(id)sender {
    [postMediaViewController showVideoPickerActionSheet:sender];
}

- (IBAction)addPhoto:(id)sender {
    [postMediaViewController showPhotoPickerActionSheet:sender];
}

- (IBAction)showCategories:(id)sender {
    [self populateSelectionsControllerWithCategories];
}

- (IBAction)showMap:(id)sender {
    [self displayPOIMapViewController];
}

- (IBAction)touchTextView:(id)sender {
    [textView becomeFirstResponder];
}


- (CGRect)normalTextFrame {
    if (IS_IPAD)
        if ((self.interfaceOrientation == UIDeviceOrientationLandscapeLeft)
            || (self.interfaceOrientation == UIDeviceOrientationLandscapeRight)) // Landscape
            return CGRectMake(0, 143, 768, 517);
        else // Portrait
            return CGRectMake(0, 143, 768, 753);
		else if ((self.interfaceOrientation == UIDeviceOrientationLandscapeLeft)
				 || (self.interfaceOrientation == UIDeviceOrientationLandscapeRight)) // Landscape
			return CGRectMake(0, 136, 480, 236);
		else // Portrait
			return CGRectMake(0, 136, 320, 236);
}


- (void)disableInteraction {
	editingDisabled = YES;
}

- (void)displayPOIMapViewController{
    HIOoIViewController *poiViewController = [[HIOoIViewController alloc] initWithNibName:@"HIOoIViewController" bundle:nil];
    [self.navigationController pushViewController:poiViewController animated:YES];
    [poiViewController release];
}

#pragma mark -

- (void)dismissEditView {
    [self dismissModalViewControllerAnimated:YES];
    //[self.navigationController popToRootViewControllerAnimated:YES];
	[postSettingsController release]; postSettingsController = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PostEditorDismissed" object:self];
}


- (void)refreshButtons {
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                  target:self
                                                                                  action:@selector(cancelView:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    [cancelButton release];
    
    NSString *buttonTitle;
    if(![self.apost hasRemote]) {
        if ([self.apost.status isEqualToString:@"publish"] && ([self.apost.dateCreated compare:[NSDate date]] == NSOrderedDescending)) {
            buttonTitle = NSLocalizedString(@"Schedule", @"Schedule button, this is what the Publish button changes to in the Post Editor if the post has been scheduled for posting later.");
		} else if ([self.apost.status isEqualToString:@"publish"]){
            buttonTitle = NSLocalizedString(@"Publish", @"Publish button label.");
		} else {
            buttonTitle = NSLocalizedString(@"Save", @"Save button label (saving content, ex: Post, Page, Comment).");
        }
    } else {
        buttonTitle = NSLocalizedString(@"Update", @"Update button label (saving content, ex: Post, Page, Comment).");
    }
    
    // Check if we're on iOS 4
    if (![self.editButtonItem respondsToSelector:@selector(setTintColor:)]) {
        UIBarButtonItem *saveButton = [[[UIBarButtonItem alloc] initWithTitle:buttonTitle style:UIBarButtonItemStyleBordered target:self action:@selector(saveAction:)] autorelease];
        self.navigationItem.rightBarButtonItem = saveButton;
    } else {
        //set up the blue button for nav bar
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom]; 
        UIFont *titleFont = [UIFont boldSystemFontOfSize:12];
        CGSize titleSize = [buttonTitle sizeWithFont:titleFont];
        CGFloat buttonWidth = titleSize.width + 20;
        button.frame = CGRectMake(0, 0, buttonWidth, 30);
        
        [button setTitle:buttonTitle forState:UIControlStateNormal];
        button.titleLabel.font = titleFont;
        button.titleLabel.shadowColor = [UIColor blackColor];
        button.titleLabel.shadowOffset = CGSizeMake(0.0, 1.0);
        [button addTarget:self action:@selector(saveAction:) forControlEvents:UIControlEventTouchUpInside];
        
        UIImage *backgroundImage = [[UIImage imageNamed:@"navbar_button_bg_active"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
        [button setBackgroundImage:backgroundImage forState:UIControlStateNormal];
        
        UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithCustomView:button];
        self.navigationItem.rightBarButtonItem = saveButton;
        [saveButton release];
    }
}

- (void)refreshUIForCompose {
	self.navigationItem.title = NSLocalizedString(@"Write", @"Post Editor screen title.");
    titleTextField.text = @"";
    textView.text = @"";
    textViewPlaceHolderField.hidden = NO;
	self.isLocalDraft = YES;
}

- (void)refreshUIForCurrentPost {
    if ([self.apost.postTitle length] > 0) {
        self.navigationItem.title = self.apost.postTitle;
    }
    self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", @"Back button label.")
																			 style:UIBarButtonItemStyleBordered target:nil action:nil] autorelease];
	
    titleTextField.text = self.apost.postTitle;
    if (self.post) {
        // FIXME: tags should be an array/set of Tag objects
        tagsTextField.text = self.post.tags;
        [categoriesButton setTitle:[NSString decodeXMLCharactersIn:[self.post categoriesText]] forState:UIControlStateNormal];
    }
    
    if(self.apost.content == nil || [self.apost.content isEmpty]) {
        textViewPlaceHolderField.hidden = NO;
        textView.text = @"";
    }
    else {
        textViewPlaceHolderField.hidden = YES;
        if ((self.apost.mt_text_more != nil) && ([self.apost.mt_text_more length] > 0))
			textView.text = [NSString stringWithFormat:@"%@\n<!--more-->\n%@", self.apost.content, self.apost.mt_text_more];
		else	
			textView.text = self.apost.content;
		
    }
	
	// workaround for odd text view behavior on iPad
	[textView setContentOffset:CGPointZero animated:NO];
}

- (void)populateSelectionsControllerWithCategories {
    WPFLogMethod();
    if (segmentedTableViewController == nil)
        segmentedTableViewController = [[WPSegmentedSelectionTableViewController alloc] initWithNibName:@"WPSelectionTableViewController" bundle:nil];
	
	NSArray *cats = [self.post.blog sortedCategories];

	NSArray *selObject;
	
    selObject = [self.post.categories allObjects];
	
    [segmentedTableViewController populateDataSource:cats    //datasource
									   havingContext:kSelectionsCategoriesContext
									 selectedObjects:selObject
									   selectionType:kCheckbox
										 andDelegate:self];
	
    segmentedTableViewController.title = NSLocalizedString(@"Categories", @"");
    segmentedTableViewController.navigationItem.rightBarButtonItem = createCategoryBarButtonItem;
	
    if (isNewCategory != YES) {
		if (IS_IPAD == YES) {
            UINavigationController *navController;
            if (segmentedTableViewController.navigationController) {
                navController = segmentedTableViewController.navigationController;
            } else {
                navController = [[[UINavigationController alloc] initWithRootViewController:segmentedTableViewController] autorelease];
            }
 			UIPopoverController *popover = [[[NSClassFromString(@"UIPopoverController") alloc] initWithContentViewController:navController] autorelease];
            popover.delegate = self;			CGRect popoverRect = [self.view convertRect:[categoriesButton frame] fromView:[categoriesButton superview]];
			popoverRect.size.width = MIN(popoverRect.size.width, 100); // the text field is actually really big
			[popover presentPopoverFromRect:popoverRect inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
			[[CPopoverManager instance] setCurrentPopoverController:popover];
		}
		else {
			self.editMode = kEditPost;
			[self.navigationController pushViewController:segmentedTableViewController animated:YES];
		}
    }
	
	isNewCategory = NO;
}

- (void)refreshStatus {
	if(isLocalDraft == YES) {
		statusTextField.text = NSLocalizedString(@"Local Draft", @"");
	}
	else {
		statusTextField.text = self.apost.statusTitle;
	}
}

- (void)populateSelectionsControllerWithStatuses {
    if (selectionTableViewController == nil)
        selectionTableViewController = [[WPSelectionTableViewController alloc] initWithNibName:@"WPSelectionTableViewController" bundle:nil];
	
    NSArray *dataSource = [self.apost availableStatuses];
	
    NSString *curStatus = self.apost.statusTitle;
	
    NSArray *selObject = (curStatus == nil ? [NSArray array] : [NSArray arrayWithObject:curStatus]);
	
    [selectionTableViewController populateDataSource:dataSource
									   havingContext:kSelectionsStatusContext
									 selectedObjects:selObject
									   selectionType:kRadio
										 andDelegate:self];
	
    selectionTableViewController.title = NSLocalizedString(@"Status", @"");
    selectionTableViewController.navigationItem.rightBarButtonItem = nil;
	if (IS_IPAD == YES) {
		UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController:selectionTableViewController] autorelease];
		UIPopoverController *popover = [[[NSClassFromString(@"UIPopoverController") alloc] initWithContentViewController:navController] autorelease];
		CGRect popoverRect = [self.view convertRect:[statusTextField frame] fromView:[statusTextField superview]];
		popoverRect.size.width = MIN(popoverRect.size.width, 100);
		[popover presentPopoverFromRect:popoverRect inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
		[[CPopoverManager instance] setCurrentPopoverController:popover];
	}
	else {
		WordPressAppDelegate *delegate = (WordPressAppDelegate *)[[UIApplication sharedApplication] delegate];
		[delegate.navigationController pushViewController:selectionTableViewController animated:YES];
	}
    [selectionTableViewController release], selectionTableViewController = nil;
}

- (void)selectionTableViewController:(WPSelectionTableViewController *)selctionController completedSelectionsWithContext:(void *)selContext selectedObjects:(NSArray *)selectedObjects haveChanges:(BOOL)isChanged {
    WPFLogMethod();
    if (!isChanged) {
        [selctionController clean];
        return;
    }

    if (selContext == kSelectionsStatusContext) {
        NSString *curStatus = [selectedObjects lastObject];
        self.apost.statusTitle = curStatus;
        statusTextField.text = curStatus;
    }
    
    if (selContext == kSelectionsCategoriesContext) {
        NSLog(@"selected categories: %@", selectedObjects);
        NSLog(@"post: %@", self.post);
        self.post.categories = [NSMutableSet setWithArray:selectedObjects];
        [categoriesButton setTitle:[NSString decodeXMLCharactersIn:[self.post categoriesText]] forState:UIControlStateNormal];
    }
	
    [selctionController clean];
	[self refreshButtons];
}


- (void)newCategoryCreatedNotificationReceived:(NSNotification *)notification {
    WPFLogMethod();
    if ([segmentedTableViewController curContext] == kSelectionsCategoriesContext) {
        isNewCategory = YES;
        [self populateSelectionsControllerWithCategories];
    }
}


- (IBAction)showAddNewCategoryView:(id)sender
{
    WPFLogMethod();
    WPAddCategoryViewController *addCategoryViewController = [[WPAddCategoryViewController alloc] initWithNibName:@"WPAddCategoryViewController" bundle:nil];
    addCategoryViewController.blog = self.post.blog;
	if (IS_IPAD == YES) {
        [segmentedTableViewController pushViewController:addCategoryViewController animated:YES];
 	} else {
		UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:addCategoryViewController];
		[segmentedTableViewController presentModalViewController:nc animated:YES];
		[nc release];
	}
    [addCategoryViewController release];
}

- (void)endEditingAction:(id)sender {
    [titleTextField resignFirstResponder];
    [tagsTextField resignFirstResponder];
    [textView resignFirstResponder];
}


- (BOOL)isAFreshlyCreatedDraft {
	if( [self.apost.original.postID isEqualToNumber:[NSNumber numberWithInteger:-1]] ) 
		if( self.apost.original.postTitle == nil )
			return YES;
	
	return NO;
}

- (void)discard {
    [self.apost.original deleteRevision];

	//remove the original post in case of local draft unsaved
	if([self isAFreshlyCreatedDraft]) 
		[self.apost.original deletePostWithSuccess:nil failure:nil]; //we can pass nil because this is a local draft. no remote errors.
	
	self.apost = nil; // Just in case
    [self dismissEditView];
}

- (IBAction)saveAction:(id)sender {
	if( [self isMediaInUploading] ) {
		[self showMediaInUploadingalert];
		return;
	}
	[self savePost:YES];
}

- (void)savePost: (BOOL)upload{
    self.apost.postTitle = titleTextField.text;
    
    //Horizon code.
    //NSString* postContent = [self getPostMapLocationIFrame:self.postMapLocation];
    //postContent = [postContent stringByEncodingHTMLEntities];
    //postContent = [postContent stringByAppendingString:textView.text];
    //self.apost.content = postContent;
    //code ends.
    
    //Horizon code. Commented to replace with above code to append iframe string.
    self.apost.content = textView.text;
    
	if ([self.apost.content rangeOfString:@"<!--more-->"].location != NSNotFound)
		self.apost.mt_text_more = @"";
    
    [self.view endEditing:YES];
    
    if ( self.apost.original.password != nil ) { //original post was password protected
        if ( self.apost.password == nil || [self.apost.password isEqualToString:@""] ) { //removed the password
            self.apost.password = @"";
        }
    }
            
    [self.apost.original applyRevision];
	if (upload){
		NSString *postTitle = self.apost.postTitle;
        [self.apost.original uploadWithSuccess:^{
            NSLog(@"post uploaded: %@", postTitle);
        } failure:^(NSError *error) {
            NSLog(@"post failed: %@", [error localizedDescription]);
        }];
	} else {
		[self.apost.original save];
	}

    [self dismissEditView];
}

//Horizon code
-(NSString*)getPostMapLocationIFrame:(PostMapLocation*)inputPostMapLocation{
    NSString* frameUrlWithParameter = [[RestAPIConnector sharedInstance] getEmbeddedMapURLWithCenterCoordinate:inputPostMapLocation.center zoomLevel:inputPostMapLocation.zoomLevel];
    frameUrlWithParameter = [frameUrlWithParameter stringByEncodingHTMLEntities];
    NSString *map_iframe = [NSString stringWithFormat:IFrame_Format,frameUrlWithParameter,640,480];
    return map_iframe;
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if ([actionSheet tag] == 201) {
        if (buttonIndex == 0) {
            [self discard];
        }
        
        if (buttonIndex == 1) {  
			if ([actionSheet numberOfButtons] == 2)
				[actionSheet dismissWithClickedButtonIndex:0 animated:YES];
			else {
				if (![self.apost hasRemote])
					[self savePost:NO];
				else
					[self savePost:YES];
			}
        }
    }
    
    WordPressAppDelegate *appDelegate = (WordPressAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate setAlertRunning:NO];
}

//check if there are media in uploading status
-(BOOL) isMediaInUploading {
	
	BOOL isMediaInUploading = NO;
	
	NSSet *mediaFiles = self.apost.media;
	for (Media *media in mediaFiles) {
		if(media.remoteStatus == MediaRemoteStatusPushing) {
			isMediaInUploading = YES;
			break;
		}
	}
	mediaFiles = nil;

	return isMediaInUploading;
}

-(void) showMediaInUploadingalert {
	//the post is using the network connection and cannot be stoped, show a message to the user
	UIAlertView *blogIsCurrentlyBusy = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Info", @"Info alert title")
																  message:NSLocalizedString(@"A Media file is currently in uploading. Please try later.", @"")
																 delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];
	[blogIsCurrentlyBusy show];
	[blogIsCurrentlyBusy release];
}

- (IBAction)cancelView:(id)sender {
    [textView resignFirstResponder];
    [titleTextField resignFirstResponder];
    [tagsTextField resignFirstResponder];
    if (!self.hasChanges) {
		[postSettingsController endEditingAction:nil];
        [self discard];
        return;
    }
	[postSettingsController endEditingAction:nil];
	[self endEditingAction:nil];
    
	if( [self isMediaInUploading] ) {
		[self showMediaInUploadingalert];
		return;
	}
		
	UIActionSheet *actionSheet;
	if (![self.apost hasRemote]) {
        if ([self isAFreshlyCreatedDraft]) {
            actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"You have unsaved changes.", @"Title of message with options that shown when there are unsaved changes and the author is trying to move away from the post.")
                                                      delegate:self cancelButtonTitle:NSLocalizedString(@"Keep editing", @"Button shown if there are unsaved changes and the author is trying to move away from the post.") destructiveButtonTitle:NSLocalizedString(@"Discard", @"Button shown if there are unsaved changes and the author is trying to move away from the post.")
                                             otherButtonTitles:NSLocalizedString(@"Save Draft", @"Button shown if there are unsaved changes and the author is trying to move away from the post."), nil];
        } else {
            actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"You have unsaved changes.", @"Title of message with options that shown when there are unsaved changes and the author is trying to move away from the post.")
                                                      delegate:self cancelButtonTitle:NSLocalizedString(@"Keep editing", @"Button shown if there are unsaved changes and the author is trying to move away from the post.") destructiveButtonTitle:NSLocalizedString(@"Discard", @"Button shown if there are unsaved changes and the author is trying to move away from the post.")
                                             otherButtonTitles:NSLocalizedString(@"Update Draft", @"Button shown if there are unsaved changes and the author is trying to move away from an already published/saved post."), nil];
        }
	} else {
		actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"You have unsaved changes.", @"Title of message with options that shown when there are unsaved changes and the author is trying to move away from the post.")
												  delegate:self cancelButtonTitle:NSLocalizedString(@"Keep editing", @"Button shown if there are unsaved changes and the author is trying to move away from the post.") destructiveButtonTitle:NSLocalizedString(@"Discard", @"Button shown if there are unsaved changes and the author is trying to move away from the post.")
										 otherButtonTitles:nil];
    }

    actionSheet.tag = 201;
    actionSheet.actionSheetStyle = UIActionSheetStyleAutomatic;
    [actionSheet showInView:self.view];
    WordPressAppDelegate *appDelegate = (WordPressAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate setAlertRunning:YES];
    
    [actionSheet release];
}

- (IBAction)endTextEnteringButtonAction:(id)sender {
    [textView resignFirstResponder];
	if (IS_IPAD == NO) {
		if((self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft) || (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)) {
			//#615 -- trick to rotate the interface back to portrait. 
				UIViewController *garbageController = [[[UIViewController alloc] init] autorelease]; 
				[self.navigationController pushViewController:garbageController animated:NO]; 
				[self.navigationController popViewControllerAnimated:NO];
		}
	}
}

/*
- (IBAction)showCategoriesViewAction:(id)sender {
	//[self showEditPostModalViewWithAnimation:YES];
    [self populateSelectionsControllerWithCategories];
}

- (IBAction)showStatusViewAction:(id)sender {
    [self populateSelectionsControllerWithStatuses];
}
*/
- (void)resignTextView {
	[textView resignFirstResponder];
}

//code to append http:// if protocol part is not there as part of urlText.
- (NSString *)validateNewLinkInfo:(NSString *)urlText {
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[\\w]+:" options:0 error:&error];

    if ([regex numberOfMatchesInString:urlText options:0 range:NSMakeRange(0, [urlText length])] > 0) {
        return urlText;
    } else {
        return [NSString stringWithFormat:@"http://%@", urlText];
    }
}

- (void)showLinkView {
    UIAlertView *addURLSourceAlert = [[UIAlertView alloc] init];
	if (IS_IPAD || [[UIDevice currentDevice] orientation] == UIInterfaceOrientationPortrait) {
		infoText = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 46.0, 260.0, 31.0)];
		urlField = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 82.0, 260.0, 31.0)];
	}
	else {
		infoText = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 33.0, 260.0, 28.0)];
		urlField = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 65.0, 260.0, 28.0)];
	}

    infoText.placeholder = NSLocalizedString(@"Text to be linked", @"Popup to aid in creating a Link in the Post Editor.");
    urlField.placeholder = NSLocalizedString(@"Link URL", @"Popup to aid in creating a Link in the Post Editor, URL field (where you can type or paste a URL that the text should link.");
	infoText.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	urlField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    
    NSRange range = textView.selectedRange;
    
    if (range.length > 0)
        infoText.text = [textView.text substringWithRange:range];
    
    //infoText.enabled = YES;
	
    infoText.autocapitalizationType = UITextAutocapitalizationTypeNone;
    urlField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    infoText.borderStyle = UITextBorderStyleRoundedRect;
    urlField.borderStyle = UITextBorderStyleRoundedRect;
    infoText.keyboardAppearance = UIKeyboardAppearanceAlert;
    urlField.keyboardAppearance = UIKeyboardAppearanceAlert;
	infoText.keyboardType = UIKeyboardTypeDefault;
	urlField.keyboardType = UIKeyboardTypeURL;
    [addURLSourceAlert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button")];
    [addURLSourceAlert addButtonWithTitle:NSLocalizedString(@"Insert", @"Insert content (link, media) button")];
    addURLSourceAlert.title = NSLocalizedString(@"Make a Link\n\n\n\n", @"Title of the Link Helper popup to aid in creating a Link in the Post Editor. DON'T REMOVE the line breaks!");
    addURLSourceAlert.delegate = self;
    [addURLSourceAlert addSubview:infoText];
    [addURLSourceAlert addSubview:urlField];
    [infoText becomeFirstResponder];
	
    isShowingLinkAlert = YES;
    [addURLSourceAlert setTag:2];
    [addURLSourceAlert show];
    [addURLSourceAlert release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    WordPressAppDelegate *delegate = (WordPressAppDelegate*)[[UIApplication sharedApplication] delegate];
	
    if ([alertView tag] == 2) {
        isShowingLinkAlert = NO;
        if (buttonIndex == 1) {
            if ((urlField.text == nil) || ([urlField.text isEqualToString:@""])) {
                [delegate setAlertRunning:NO];
                return;
            }
			
            if ((infoText.text == nil) || ([infoText.text isEqualToString:@""]))
                infoText.text = urlField.text;
			
            //NSString *commentsStr = textView.text;
            //NSRange rangeToReplace = [self selectedLinkRange];
            NSString *urlString = [self validateNewLinkInfo:urlField.text];
            NSString *aTagText = [NSString stringWithFormat:@"<a href=\"%@\">%@</a>", urlString, infoText.text];
            
            NSRange range = textView.selectedRange;
            
            //NSString *selection = [textView.text substringWithRange:range];
            NSString *oldText = textView.text;
            NSRange oldRange = textView.selectedRange;
            // Weird. On iOS 4.2.x iPad the selectedRange can be larger than the string's length? #1011-ios 
            if (range.location > [oldText length]) {
                textView.text = [textView.text stringByAppendingString:aTagText];
            } else {
                textView.text = [textView.text stringByReplacingCharactersInRange:range withString:aTagText];
            }
            
            //reset selection back to nothing
            range.length = 0;
            
            if (range.length == 0) {                // If nothing was selected
                range.location += [aTagText length]; // Place selection between tags
                textView.selectedRange = range;
            }
            [[textView.undoManager prepareWithInvocationTarget:self] restoreText:oldText withRange:oldRange];
            [textView.undoManager setActionName:@"link"];            
            
            //textView.text = [commentsStr stringByReplacingOccurrencesOfString:[commentsStr substringWithRange:rangeToReplace] withString:aTagText options:NSCaseInsensitiveSearch range:rangeToReplace];
			self.apost.content = textView.text;
        }
		
        dismiss = NO;
        [delegate setAlertRunning:NO];
        [textView touchesBegan:nil withEvent:nil];
    }
	
    return;
}

- (BOOL)hasChanges {
    return self.apost.hasChanges;
}

#pragma mark TextView & TextField Delegates

- (void)textViewDidChangeSelection:(UITextView *)aTextView {
    if (!isTextViewEditing) {
        isTextViewEditing = YES;
    }
}

- (BOOL)textViewShouldBeginEditing:(UITextView *)aTextView {
    WPFLogMethod();
    isEditing = YES;
    return YES;
}

- (void)textViewDidBeginEditing:(UITextView *)aTextView {
    WPFLogMethod();
    [textViewPlaceHolderField removeFromSuperview];

//	[self positionTextView:nil];
    dismiss = NO;
	
    if (!isTextViewEditing) {
        isTextViewEditing = YES;
    }
}

- (void)textViewDidChange:(UITextView *)aTextView {
    
    //replace character entities with character numbers for trac #871
    
    NSString *str = aTextView.text;
    
    if ([str rangeOfString:@"&nbsp"].location != NSNotFound || [str rangeOfString:@"&gt"].location != NSNotFound || [str rangeOfString:@"&lt"].location != NSNotFound) {
    
        str = [[aTextView text] stringByReplacingOccurrencesOfString: @"&nbsp" withString: @" "];
        str = [str stringByReplacingOccurrencesOfString: @"&lt" withString: @"<"];
        str = [str stringByReplacingOccurrencesOfString: @"&gt" withString: @">"];
    
        aTextView.text = str;
    }
        
    self.undoButton.enabled = [self.textView.undoManager canUndo];
    self.redoButton.enabled = [self.textView.undoManager canRedo];
}

- (void)textViewDidEndEditing:(UITextView *)aTextView {
    WPFLogMethod();
	currentEditingTextField = nil;
	
	if([textView.text isEqualToString:@""] == YES) {
        [editView addSubview:textViewPlaceHolderField];
	}
	
    isEditing = NO;
    dismiss = NO;
	
    if (isTextViewEditing) {
        isTextViewEditing = NO;
//		[self positionTextView:nil];
		
        self.apost.content = textView.text;
		
		if (!IS_IPAD) {
            [self refreshButtons];
		}
    }
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    if (textField == textViewPlaceHolderField) {
        return NO;
    }
	return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
	return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.currentEditingTextField = textField;
	
    if (self.navigationItem.leftBarButtonItem.style == UIBarButtonItemStyleDone) {
        [self textViewDidEndEditing:textView];
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.currentEditingTextField = nil;
#ifdef DEBUGMODE
	if ([textField.text isEqualToString:@"#%#"]) {
		[NSException raise:@"FakeCrash" format:@"Nothing to worry about, textField == #%#"];
	}
#endif
	
    if (textField == titleTextField) {
        self.apost.postTitle = textField.text;
        
        // FIXME: this should be -[PostsViewController updateTitle]
        if ([self.apost.postTitle length] > 0) {
            self.navigationItem.title = self.apost.postTitle;
        } else {
            self.navigationItem.title = NSLocalizedString(@"Write", @"Post Editor screen title.");
        }

    }
	else if (textField == tagsTextField)
        self.post.tags = tagsTextField.text;
    
    [self.apost autosave];
}

- (void)positionTextView:(NSNotification *)notification {
    // Save time: Uncomment this line when you're debugging UITextView positioning
    // textView.backgroundColor = [UIColor blueColor];

    NSDictionary *keyboardInfo = [notification userInfo];

	CGFloat animationDuration = 0.3;
	UIViewAnimationCurve curve = 0.3;
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationCurve:curve];
	[UIView setAnimationDuration:animationDuration];

    CGRect newFrame = self.normalTextFrame;
	if(keyboardInfo != nil) {
		animationDuration = [[keyboardInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
		curve = [[keyboardInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] floatValue];
        [UIView setAnimationCurve:curve];
        [UIView setAnimationDuration:animationDuration];

        BOOL isLandscape = UIDeviceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
        BOOL isShowing = ([notification name] == UIKeyboardWillShowNotification);
        CGRect originalKeyboardFrame = [[keyboardInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
        CGRect keyboardFrame = [self.view convertRect:[self.view.window convertRect:originalKeyboardFrame fromWindow:nil] fromView:nil];

        isExternalKeyboard = keyboardFrame.origin.y + keyboardFrame.size.height > self.view.bounds.size.height;
        /*
         "Full screen" mode for:
         * iPhone Portrait without external keyboard
         * iPhone Landscape
         * iPad Landscape without external keyboard

         Show other fields:
         * iPhone Portrait with external keyboard
         * iPad Portrait
         * iPad Landscape with external keyboard
         */
        BOOL wantsFullScreen = (
                                (!IS_IPAD && !isExternalKeyboard)                  // iPhone without external keyboard
                                || (!IS_IPAD && isLandscape && isExternalKeyboard) // iPhone Landscape with external keyboard
                                || (IS_IPAD && isLandscape && !isExternalKeyboard) // iPad Landscape without external keyboard
                                );
        if (wantsFullScreen && isShowing) {
            [self.navigationController setNavigationBarHidden:YES animated:YES];
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
        } else {
            [self.navigationController setNavigationBarHidden:NO animated:YES];
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
        }
        // If we show/hide the navigation bar, the view frame changes so the converted keyboardFrame is not valid anymore
        keyboardFrame = [self.view convertRect:[self.view.window convertRect:originalKeyboardFrame fromWindow:nil] fromView:nil];

        if (isShowing) {
            if (wantsFullScreen) {
                // Make the text view expand covering other fields
                newFrame.origin.x = 0;
                newFrame.origin.y = 0;
            }
            // Adjust height for keyboard (or format bar on external keyboard)
            newFrame.size.height = keyboardFrame.origin.y - newFrame.origin.y;

            [self.toolbar setHidden:YES];
            [tabPointer setHidden:YES];
        } else {
            [self.toolbar setHidden:NO];
            [tabPointer setHidden:NO];
        }
	}

    [textView setFrame:newFrame];
	
	[UIView commitAnimations];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration {
    WPFLogMethod();
    CGRect frame = editorToolbar.frame;
    if (UIDeviceOrientationIsLandscape(interfaceOrientation)) {
        if (IS_IPAD) {
            frame.size.height = WPKT_HEIGHT_IPAD_LANDSCAPE;
        } else {
            frame.size.height = WPKT_HEIGHT_IPHONE_LANDSCAPE;
        }
    } else {
        if (IS_IPAD) {
            frame.size.height = WPKT_HEIGHT_IPAD_PORTRAIT;
        } else {
            frame.size.height = WPKT_HEIGHT_IPHONE_PORTRAIT;
        }            
    }
    editorToolbar.frame = frame;
}

- (void)deviceDidRotate:(NSNotification *)notification {
    WPFLogMethod();
	//CGRect infoText = self.addURLSourceAlert;
	//infoText.text = "test";
    
    if (IS_IPAD) {
        return;
    }
	
	// This reinforces text field constraints set above, for when the Link Helper is already showing when the device is rotated.
	if (isShowingLinkAlert == TRUE) {
		if ([[UIDevice currentDevice] orientation] == UIInterfaceOrientationPortrait) {
			infoText.frame = CGRectMake(12.0, 46.0, 260.0, 31.0);
			urlField.frame = CGRectMake(12.0, 82.0, 260.0, 31.0);
		}
		else {
			infoText.frame = CGRectMake(12.0, 33.0, 260.0, 28.0);
			urlField.frame = CGRectMake(12.0, 65.0, 260.0, 28.0);
		}
	}
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    self.currentEditingTextField = nil;
    [textField resignFirstResponder];
    return YES;
}

- (void)insertMediaAbove:(NSNotification *)notification {
	Media *media = (Media *)[notification object];
	NSString *prefix = @"<br /><br />";
	
	if(self.apost.content == nil || [self.apost.content isEqualToString:@""]) {
		self.apost.content = @"";
		prefix = @"";
	}
	
	NSMutableString *content = [[[NSMutableString alloc] initWithString:media.html] autorelease];
	NSRange imgHTML = [textView.text rangeOfString: content];
	
	NSRange imgHTMLPre = [textView.text rangeOfString:[NSString stringWithFormat:@"%@%@", @"<br /><br />", content]]; 
 	NSRange imgHTMLPost = [textView.text rangeOfString:[NSString stringWithFormat:@"%@%@", content, @"<br /><br />"]]; 
	
	if (imgHTMLPre.location == NSNotFound && imgHTMLPost.location == NSNotFound && imgHTML.location == NSNotFound) {
		[content appendString:[NSString stringWithFormat:@"%@%@", prefix, self.apost.content]];
        self.apost.content = content;
	}
	else { 
		NSMutableString *processedText = [[[NSMutableString alloc] initWithString:textView.text] autorelease]; 
		if (imgHTMLPre.location != NSNotFound) 
			[processedText replaceCharactersInRange:imgHTMLPre withString:@""];
		else if (imgHTMLPost.location != NSNotFound) 
			[processedText replaceCharactersInRange:imgHTMLPost withString:@""];
		else  
			[processedText replaceCharactersInRange:imgHTML withString:@""];  
		 
		[content appendString:[NSString stringWithFormat:@"<br /><br />%@", processedText]]; 
		self.apost.content = content;
	}
    [self refreshUIForCurrentPost];
}

- (void)insertMediaBelow:(NSNotification *)notification {
	Media *media = (Media *)[notification object];
	NSString *prefix = @"<br /><br />";
	
	if(self.apost.content == nil || [self.apost.content isEqualToString:@""]) {
		self.apost.content = @"";
		prefix = @"";
	}
	
	NSMutableString *content = [[[NSMutableString alloc] initWithString:self.apost.content] autorelease];
	NSRange imgHTML = [content rangeOfString: media.html];
	NSRange imgHTMLPre = [content rangeOfString:[NSString stringWithFormat:@"%@%@", @"<br /><br />", media.html]]; 
 	NSRange imgHTMLPost = [content rangeOfString:[NSString stringWithFormat:@"%@%@", media.html, @"<br /><br />"]];
	
	if (imgHTMLPre.location == NSNotFound && imgHTMLPost.location == NSNotFound && imgHTML.location == NSNotFound) {
		[content appendString:[NSString stringWithFormat:@"%@%@", prefix, media.html]];
        self.apost.content = content;
	}
	else {
		if (imgHTMLPre.location != NSNotFound) 
			[content replaceCharactersInRange:imgHTMLPre withString:@""]; 
		else if (imgHTMLPost.location != NSNotFound) 
			[content replaceCharactersInRange:imgHTMLPost withString:@""];
		else  
			[content replaceCharactersInRange:imgHTML withString:@""];
		[content appendString:[NSString stringWithFormat:@"<br /><br />%@", media.html]];
		self.apost.content = content;
	}
    [self refreshUIForCurrentPost];
}

- (void)removeMedia:(NSNotification *)notification {
	//remove the html string for the media object
	Media *media = (Media *)[notification object];
	textView.text = [textView.text stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"<br /><br />%@", media.html] withString:@""];
	textView.text = [textView.text stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@<br /><br />", media.html] withString:@""];
	textView.text = [textView.text stringByReplacingOccurrencesOfString:media.html withString:@""];
	self.apost.content = textView.text;
}

- (void)readBookmarksFile {
    bookMarksArray = [[NSMutableArray alloc] init];
    //NSDictionary *bookMarksDict=[NSMutableDictionary dictionaryWithContentsOfFile:@"/Users/sridharrao/Library/Safari/Bookmarks.plist"];
    NSDictionary *bookMarksDict = [NSMutableDictionary dictionaryWithContentsOfFile:@"/Users/sridharrao/Library/Application%20Support/iPhone%20Simulator/User/Library/Safari/Bookmarks.plist"];
    NSArray *childrenArray = [bookMarksDict valueForKey:@"Children"];
    bookMarksDict = [childrenArray objectAtIndex:0];
    int count = [childrenArray count];
    childrenArray = [bookMarksDict valueForKey:@"Children"];
	
    for (int i = 0; i < count; i++) {
        bookMarksDict = [childrenArray objectAtIndex:i];
		
        if ([[bookMarksDict valueForKey:@"WebBookmarkType"] isEqualToString:@"WebBookmarkTypeLeaf"]) {
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            [dict setValue:[[bookMarksDict valueForKey:@"URIDictionary"] valueForKey:@"title"] forKey:@"title"];
            [dict setValue:[bookMarksDict valueForKey:@"URLString"] forKey:@"url"];
            [bookMarksArray addObject:dict];
            [dict release];
        }
    }
}

#pragma mark - Keyboard toolbar

- (void)undo {
    [self.textView.undoManager undo];
}

- (void)redo {
    [self.textView.undoManager redo];
}

- (void)restoreText:(NSString *)text withRange:(NSRange)range {
    NSLog(@"restoreText:%@",text);
    NSString *oldText = textView.text;
    NSRange oldRange = textView.selectedRange;
    textView.scrollEnabled = NO;
    textView.text = text;
    textView.scrollEnabled = YES;
    textView.selectedRange = range;
    [[textView.undoManager prepareWithInvocationTarget:self] restoreText:oldText withRange:oldRange];
}

- (void)wrapSelectionWithTag:(NSString *)tag {
    NSRange range = textView.selectedRange;
    NSString *selection = [textView.text substringWithRange:range];
    NSString *prefix, *suffix;
    if ([tag isEqualToString:@"ul"] || [tag isEqualToString:@"ol"]) {
        prefix = [NSString stringWithFormat:@"<%@>\n", tag];
        suffix = [NSString stringWithFormat:@"\n</%@>\n", tag];
    } else if ([tag isEqualToString:@"li"]) {
        prefix = [NSString stringWithFormat:@"\t<%@>", tag];
        suffix = [NSString stringWithFormat:@"</%@>\n", tag];
    } else if ([tag isEqualToString:@"more"]) {
        prefix = @"<!--more-->";
        suffix = @"\n";
    } else if ([tag isEqualToString:@"blockquote"]) {
        prefix = [NSString stringWithFormat:@"\n<%@>", tag];
        suffix = [NSString stringWithFormat:@"</%@>\n", tag];
    } else {
        prefix = [NSString stringWithFormat:@"<%@>", tag];
        suffix = [NSString stringWithFormat:@"</%@>", tag];        
    }
    textView.scrollEnabled = NO;
    textView.text = [textView.text stringByReplacingCharactersInRange:range
                                                           withString:[NSString stringWithFormat:@"%@%@%@",prefix,selection,suffix]];
    textView.scrollEnabled = YES;
    if (range.length == 0) {                // If nothing was selected
        range.location += [prefix length]; // Place selection between tags
    } else {
        range.location += range.length + [prefix length] + [suffix length]; // Place selection after tag
        range.length = 0;
    }
    textView.selectedRange = range;
}

- (void)keyboardToolbarButtonItemPressed:(WPKeyboardToolbarButtonItem *)buttonItem {
    WPFLogMethod();
    if ([buttonItem.actionTag isEqualToString:@"link"]) {
        [self showLinkView];
    } else if ([buttonItem.actionTag isEqualToString:@"done"]) {
        [self endTextEnteringButtonAction:buttonItem];
    } else {
        NSString *oldText = textView.text;
        NSRange oldRange = textView.selectedRange;
        [self wrapSelectionWithTag:buttonItem.actionTag];
        [[textView.undoManager prepareWithInvocationTarget:self] restoreText:oldText withRange:oldRange];
        [textView.undoManager setActionName:buttonItem.actionName];    
    }
}

#pragma mark  -
#pragma mark Table Data Source Methods (for Custom Fields TableView only)

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
	
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 200, 25)];
        label.textAlignment = UITextAlignmentLeft;
        //label.tag = kLabelTag;
        label.font = [UIFont systemFontOfSize:16];
        label.textColor = [UIColor grayColor];
        [cell.contentView addSubview:label];
        [label release];
    }
	
    NSUInteger row = [indexPath row];
	
    //UILabel *label = (UILabel *)[cell viewWithTag:kLabelTag];
	
    if (row == 0) {
        //label.text = @"Edit Custom Fields";
        //label.font = [UIFont systemFontOfSize:16 ];
    } else {
        //do nothing because we've only got one cell right now
    }
	cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    cell.userInteractionEnabled = YES;
    return cell;
}

//- (UITableViewCellAccessoryType)tableView:(UITableView *)tableView accessoryTypeForRowWithIndexPath:(NSIndexPath *)indexPath {
//    return UITableViewCellAccessoryDisclosureIndicator;
//}

#pragma mark -
#pragma mark Table delegate
- (NSIndexPath *)tableView:(UITableView *)tableView
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

#pragma mark -
#pragma mark Custom Fields methods
/*
- (BOOL)checkCustomFieldsMinusMetadata {
    BlogDataManager *dm = [BlogDataManager sharedDataManager];
    NSMutableArray *tempCustomFieldsArray = [dm.currentPost valueForKey:@"custom_fields"];
	
    //if there is anything (>=1) in the array, start proceessing, otherwise return NO
    if (tempCustomFieldsArray.count >= 1) {
        //strip out any underscore-containing NSDicts inside the array, as this is metadata we don't need
        int dictsCount = [tempCustomFieldsArray count];
		
        for (int i = 0; i < dictsCount; i++) {
            NSString *tempKey = [[tempCustomFieldsArray objectAtIndex:i] objectForKey:@"key"];
			
            //if tempKey contains an underscore, remove that object (NSDict with metadata) from the array and move on
            if(([tempKey rangeOfString:@"_"].location != NSNotFound) && ([tempKey rangeOfString:@"geo_"].location == NSNotFound)) {
                [tempCustomFieldsArray removeObjectAtIndex:i];
                //if I remove one, the count goes down and we stop too soon unless we subtract one from i
                //and re-set dictsCount.  Doing this keeps us in sync with the actual array.count
                i--;
                dictsCount = [tempCustomFieldsArray count];
            }
        }
		
        //if the count of everything minus the metedata is one or greater, there is at least one custom field on this post, so return YES
        if (dictsCount >= 1) {
            return YES;
        } else {
            return NO;
        }
    } else {
        return NO;
    }
}

#pragma mark -
#pragma mark Location methods

- (BOOL)isPostGeotagged {
	if([self getPostLocation] != nil) {
		return YES;
	}
	else
		return NO;
}

- (IBAction)showLocationMapView:(id)sender {
	WordPressAppDelegate *delegate = (WordPressAppDelegate *)[[UIApplication sharedApplication] delegate];
	PostLocationViewController *locationView = [[PostLocationViewController alloc] initWithNibName:@"PostLocationViewController" bundle:nil];
	[delegate.navigationController presentModalViewController:locationView animated:YES];
	[locationView release];
}

- (CLLocation *)getPostLocation {
	CLLocation *result = nil;
	double latitude = 0.0;
	double longitude = 0.0;
    NSArray *customFieldsArray = [[[BlogDataManager sharedDataManager] currentPost] valueForKey:@"custom_fields"];
	
	// Loop through the post's custom fields
	for(NSDictionary *dict in customFieldsArray)
	{
		// Latitude
		if([[dict objectForKey:@"key"] isEqualToString:@"geo_latitude"])
			latitude = [[dict objectForKey:@"value"] doubleValue];
		
		// Longitude
		if([[dict objectForKey:@"key"] isEqualToString:@"geo_longitude"])
			longitude = [[dict objectForKey:@"value"] doubleValue];
		
		// If we have both lat and long, we have a geotag
		if((latitude != 0.0) && (longitude != 0.0))
		{
			result = [[[CLLocation alloc] initWithLatitude:latitude longitude:longitude] autorelease];
			break;
		}
		else
			result = nil;
	}
	
	return result;
}
*/

#pragma mark -
#pragma mark Keyboard management 

- (void)keyboardWillShow:(NSNotification *)notification {
    WPFLogMethod();
	isShowingKeyboard = YES;
    if (isEditing) {
        [self positionTextView:notification];
        editorToolbar.doneButton.hidden = IS_IPAD && ! isExternalKeyboard;
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    WPFLogMethod();
	isShowingKeyboard = NO;
    [self positionTextView:notification];
}

#pragma mark -
#pragma mark UIPickerView delegate

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)thePickerView {	
	return 1;
}

- (NSInteger)pickerView:(UIPickerView *)thePickerView numberOfRowsInComponent:(NSInteger)component {
	return [statuses count];
}

- (NSString *)pickerView:(UIPickerView *)thePickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
	return [statuses objectAtIndex:row];
}

- (void)pickerView:(UIPickerView *)thePickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
	self.statusTextField.text = [statuses objectAtIndex:row];
}

#pragma mark -
#pragma mark UIPopoverController delegate

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController {
    if ((popoverController.contentViewController) && ([popoverController.contentViewController class] == [UINavigationController class])) {
        UINavigationController *nav = (UINavigationController *)popoverController.contentViewController;
        if ([nav.viewControllers count] == 2) {
            WPSegmentedSelectionTableViewController *selController = [nav.viewControllers objectAtIndex:0];
            [selController popViewControllerAnimated:YES];
        }
    }
    return YES;
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    WPLog(@"%@ %@", self, NSStringFromSelector(_cmd));
    [super didReceiveMemoryWarning];
}

- (void)dismissAlertViewKeyboard: (NSNotification*)notification {
    if (isShowingLinkAlert) {
        [infoText resignFirstResponder];
        [urlField resignFirstResponder];
    }
}



@end
