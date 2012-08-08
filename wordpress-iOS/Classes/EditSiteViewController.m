//
//  EditBlogViewController.m
//  WordPress
//
//  Created by Chris Boyd on 7/23/10.

#import "EditSiteViewController.h"
#import "NSURL+IDN.h"
#import "WordPressApi.h"
#import "SFHFKeychainUtils.h"

@interface EditSiteViewController (PrivateMethods)
- (void)validateFields;
- (void)validationSuccess:(NSString *)xmlrpc;
- (void)validationDidFail:(id)wrong;
- (void)handleKeyboardWillShow:(NSNotification *)notification;
- (void)handleKeyboardWillHide:(NSNotification *)notification;
- (void)handleViewTapped;
@end

@implementation EditSiteViewController

@synthesize password, username, url, geolocationEnabled;
@synthesize blog, tableView, savingIndicator;
@synthesize urlCell, usernameCell, passwordCell;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
    [super viewDidLoad];
    if (blog) {
        if([blog isWPcom] == YES) {
            self.navigationItem.title = NSLocalizedString(@"Edit Blog", @"");
        }
        else {
            self.navigationItem.title = NSLocalizedString(@"Edit Site", @"");
        }
		self.tableView.backgroundColor = [UIColor clearColor];
		if (IS_IPAD){
			self.tableView.backgroundView = nil;
			self.tableView.backgroundColor = [UIColor clearColor];
		}
        self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"welcome_bg_pattern.png"]];
        
        NSError *error = nil;
        self.url = blog.url;
        self.username = blog.username;
        self.password = [SFHFKeychainUtils getPasswordForUsername:blog.username andServiceName:blog.hostURL error:&error];
        self.geolocationEnabled = blog.geolocationEnabled;
    }
    
    saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(save:)];
    
    self.navigationItem.rightBarButtonItem = saveButton;
    
    if (!IS_IPAD){
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
        
        UITapGestureRecognizer *tgr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleViewTapped)];
        [tableView addGestureRecognizer:tgr];
        [tgr release];
        
    }
}

- (void)viewDidUnload {
    [super viewDidUnload];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	if(IS_IPAD == YES)
		return YES;
	else
		return NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    self.username = nil;
    self.password = nil;
    self.url = nil;
    self.urlCell = nil;
    self.usernameCell = nil;
    self.passwordCell = nil;
    self.tableView = nil;
    self.blog = nil;
    [subsites release]; subsites = nil;
    [saveButton release]; saveButton = nil;
    [switchCell release]; switchCell = nil;
    [urlTextField release]; urlTextField = nil;
    [usernameTextField release]; usernameTextField = nil;
    [passwordTextField release]; passwordTextField = nil;
    [lastTextField release]; lastTextField = nil;
	[savingIndicator release];
    [super dealloc];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    switch (section) {
		case 0:
            return 3;	// URL, username, password
		case 1:
            return 1;	// Settings
		default:
			break;
	}
	return 0;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {    
    if ([indexPath section] == 0) {
        if (indexPath.row == 0) {
            self.urlCell = (UITableViewTextFieldCell *)[tableView dequeueReusableCellWithIdentifier:@"UrlCell"];
            if (self.urlCell == nil) {
                self.urlCell = [[[UITableViewTextFieldCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"UrlCell"] autorelease];
				self.urlCell.textLabel.text = NSLocalizedString(@"URL", @"");
				urlTextField = [self.urlCell.textField retain];
				urlTextField.placeholder = NSLocalizedString(@"http://example.com", @"");
				urlTextField.keyboardType = UIKeyboardTypeURL;
				urlTextField.returnKeyType = UIReturnKeyNext;
                urlTextField.delegate = self;
				if(blog.url != nil)
					urlTextField.text = blog.url;
            }
            
            return self.urlCell;
        }
        else if(indexPath.row == 1) {
            self.usernameCell = (UITableViewTextFieldCell *)[tableView dequeueReusableCellWithIdentifier:@"UsernameCell"];
            if (self.usernameCell == nil) {
                self.usernameCell = [[[UITableViewTextFieldCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"UsernameCell"] autorelease];
				self.usernameCell.textLabel.text = NSLocalizedString(@"Username", @"");
				usernameTextField = [self.usernameCell.textField retain];
				usernameTextField.placeholder = NSLocalizedString(@"WordPress username", @"");
				usernameTextField.keyboardType = UIKeyboardTypeDefault;
				usernameTextField.returnKeyType = UIReturnKeyNext;
                usernameTextField.autocorrectionType = UITextAutocorrectionTypeNo;
                usernameTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
                usernameTextField.delegate = self;
				if(blog.username != nil)
					usernameTextField.text = blog.username;
			}
            
            return self.usernameCell;
        }
        else if(indexPath.row == 2) {
            self.passwordCell = (UITableViewTextFieldCell *)[tableView dequeueReusableCellWithIdentifier:@"PasswordCell"];
            if (self.passwordCell == nil) {
                self.passwordCell = [[[UITableViewTextFieldCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"PasswordCell"] autorelease];
				self.passwordCell.textLabel.text = NSLocalizedString(@"Password", @"");
				passwordTextField = [self.passwordCell.textField retain];
				passwordTextField.placeholder = NSLocalizedString(@"WordPress password", @"");
				passwordTextField.keyboardType = UIKeyboardTypeDefault;
				passwordTextField.secureTextEntry = YES;
                passwordTextField.autocorrectionType = UITextAutocorrectionTypeNo;
                passwordTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
                passwordTextField.delegate = self;
				if(password != nil)
					passwordTextField.text = password;
			}            
            return self.passwordCell;
        }				        
    } else if(indexPath.section == 1) {
        if(switchCell == nil) {
            NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"UITableViewSwitchCell" owner:nil options:nil];
            for(id currentObject in topLevelObjects)
            {
                if([currentObject isKindOfClass:[UITableViewSwitchCell class]])
                {
                    switchCell = (UITableViewSwitchCell *)currentObject;
                    break;
                }
            }
        }
        [switchCell retain];
        switchCell.textLabel.text = NSLocalizedString(@"Geotagging", @"Enables geotagging in blog settings (short label)");
        switchCell.selectionStyle = UITableViewCellSelectionStyleNone;
        switchCell.cellSwitch.on = self.geolocationEnabled;
        [switchCell.cellSwitch addTarget:self action:@selector(toggleGeolocation:) forControlEvents:UIControlEventValueChanged];
        return switchCell;
	}
    
    // We shouldn't reach this point, but return an empty cell just in case
    return [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"NoCell"] autorelease];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	NSString *result = nil;
	switch (section) {
		case 0:
			result = blog.blogName;
			break;
        case 1:
            result = NSLocalizedString(@"Settings", @"");
            break;
        case 2:
            result = NSLocalizedString(@"Advanced", @"");
            break;
		default:
			break;
	}
	return result;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tv cellForRowAtIndexPath:indexPath];
	if (indexPath.section == 0) {
        for(UIView *subview in cell.subviews) {
            if(subview.class == [UITextField class]) {
                [subview becomeFirstResponder];
                break;
            }
        }
	} 
    [tv deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark -
#pragma mark UITextField methods

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if (lastTextField) {
        [lastTextField release];
        lastTextField = nil;
    }
    lastTextField = [textField retain];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField.returnKeyType == UIReturnKeyNext) {
        UITableViewCell *cell = (UITableViewCell *)[textField superview];
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        NSIndexPath *nextIndexPath = [NSIndexPath indexPathForRow:(indexPath.row + 1) inSection:indexPath.section];
        UITableViewCell *nextCell = [self.tableView cellForRowAtIndexPath:nextIndexPath];
        if (nextCell) {
            for (UIView *subview in [nextCell subviews]) {
                if ([subview isKindOfClass:[UITextField class]]) {
                    [subview becomeFirstResponder];
                    break;
                }
            }
        }
    }
	[textField resignFirstResponder];
	return NO;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    UITableViewCell *cell = (UITableViewCell *)[textField superview];
    NSMutableString *result = [NSMutableString stringWithString:textField.text];
    [result replaceCharactersInRange:range withString:string];

    if ([result length] == 0) {
        cell.textLabel.textColor = WRONG_FIELD_COLOR;
    } else {
        cell.textLabel.textColor = GOOD_FIELD_COLOR;        
    }
    
    return YES;
}

#pragma mark -
#pragma mark UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex { 
	switch(buttonIndex) {
		case 0: {
            if ( alertView.tag == 20 ) {
                //Domain Error or malformed response
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString: @"http://ios.wordpress.org/faq/#faq_3"]];
            } else {
                HelpViewController *helpViewController = [[HelpViewController alloc] init];
                WordPressAppDelegate *appDelegate = (WordPressAppDelegate *)[[UIApplication sharedApplication] delegate];
                
                if (IS_IPAD) {
                    helpViewController.isBlogSetup = YES;
                    [self.navigationController pushViewController:helpViewController animated:YES];
                }
                else
                    [appDelegate.navigationController presentModalViewController:helpViewController animated:YES];
                
                [helpViewController release];
            }
			break;
		}
		case 1:
			//ok
			break;
		default:
			break;
	}
}

#pragma mark -
#pragma mark Custom methods

- (void)toggleGeolocation:(id)sender {
    self.geolocationEnabled = switchCell.cellSwitch.on;
}

- (void)refreshTable {
	[self.tableView reloadData];
}

- (void)checkURL {	
	NSString *urlToValidate = self.url;
	
    if(![urlToValidate hasPrefix:@"http"])
        urlToValidate = [NSString stringWithFormat:@"http://%@", url];
	
    NSError *error = NULL;
    
    NSRegularExpression *wplogin = [NSRegularExpression regularExpressionWithPattern:@"/wp-login.php$" options:NSRegularExpressionCaseInsensitive error:&error];
    NSRegularExpression *wpadmin = [NSRegularExpression regularExpressionWithPattern:@"/wp-admin/?$" options:NSRegularExpressionCaseInsensitive error:&error];
    NSRegularExpression *trailingslash = [NSRegularExpression regularExpressionWithPattern:@"/?$" options:NSRegularExpressionCaseInsensitive error:&error];
    
    urlToValidate = [wplogin stringByReplacingMatchesInString:urlToValidate options:0 range:NSMakeRange(0, [urlToValidate length]) withTemplate:@""];
    urlToValidate = [wpadmin stringByReplacingMatchesInString:urlToValidate options:0 range:NSMakeRange(0, [urlToValidate length]) withTemplate:@""];
    urlToValidate = [trailingslash stringByReplacingMatchesInString:urlToValidate options:0 range:NSMakeRange(0, [urlToValidate length]) withTemplate:@""];
    
    [FileLogger log:@"%@ %@ %@", self, NSStringFromSelector(_cmd), urlToValidate];
    // FIXME: add HTTP Auth support back
    // Currently on https://github.com/AFNetworking/AFNetworking/tree/experimental-authentication-challenge
    [WordPressApi guessXMLRPCURLForSite:urlToValidate success:^(NSURL *xmlrpcURL) {
        WordPressApi *api = [WordPressApi apiWithXMLRPCEndpoint:xmlrpcURL username:usernameTextField.text password:passwordTextField.text];
        [api getBlogsWithSuccess:^(NSArray *blogs) {
            subsites = [blogs retain];
            [self validationSuccess:[xmlrpcURL absoluteString]];
        } failure:^(NSError *error) {
            [self validationDidFail:error];
        }];
    } failure:^(NSError *error){
        if ([error.domain isEqual:NSURLErrorDomain] && error.code == NSURLErrorUserCancelledAuthentication) {
            [self validationDidFail:nil];
        } else {
            // FIXME: find a better error
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      NSLocalizedString(@"Unable to read the WordPress site on that URL. Tap Need Help? to learn more and resolve this error.", @""),NSLocalizedDescriptionKey,
                                      nil];
            NSError *err = [NSError errorWithDomain:@"org.wordpress.iphone" code:NSURLErrorBadURL userInfo:userInfo];
            [self validationDidFail:err];
        }
    }];
}

- (void)validationSuccess:(NSString *)xmlrpc {
	[savingIndicator stopAnimating];
	[savingIndicator setHidden:YES];
    blog.url = self.url;
    blog.xmlrpc = xmlrpc;
    blog.username = self.username;
    blog.geolocationEnabled = self.geolocationEnabled;
	NSError *error = nil;
	//check if the blog is a WP.COM blog
	if(blog.isWPcom) {
		[SFHFKeychainUtils storeUsername:blog.username
                             andPassword:self.password
                          forServiceName:@"WordPress.com"
                          updateExisting:YES
                                   error:&error];
	} else {
		[SFHFKeychainUtils storeUsername:blog.username
							 andPassword:self.password
						  forServiceName:blog.hostURL
						  updateExisting:YES
								   error:&error];
	}
	
    if (error) {
		[FileLogger log:@"%@ %@ Error saving password for %@: %@", self, NSStringFromSelector(_cmd), blog.url, error];
    } else {
		[FileLogger log:@"%@ %@ %@", self, NSStringFromSelector(_cmd), blog.url];
	}
    [self.navigationController popToRootViewControllerAnimated:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BlogsRefreshNotification" object:nil];

    saveButton.enabled = YES;
	[self.navigationItem setHidesBackButton:NO animated:NO];
}

- (void)validationDidFail:(id)wrong {
	[savingIndicator stopAnimating];
	[savingIndicator setHidden:YES];
    if (wrong) {
        if ([wrong isKindOfClass:[UITableViewCell class]]) {
            ((UITableViewCell *)wrong).textLabel.textColor = WRONG_FIELD_COLOR;
        } else if ([wrong isKindOfClass:[NSError class]]) {
            NSError *error = (NSError *)wrong;
			NSString *message;
			if ([error code] == 403) {
				message = NSLocalizedString(@"Please update your credentials and try again.", @"");
			} else {
				message = [error localizedDescription];
			}

            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Sorry, can't log in", @"")
																message:message
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"Need Help?", @"")
                                                      otherButtonTitles:NSLocalizedString(@"OK", @""), nil];
            if ( [error code] == NSURLErrorBadURL ) {
                alertView.tag = 20; // take the user to the FAQ page when hit "Need Help"
            } else {
                alertView.tag = 10;
            }
            [alertView show];
            [alertView release];            
        }
    }    

    saveButton.enabled = YES;
	[self.navigationItem setHidesBackButton:NO animated:NO];
}

- (void)validateFields {
    self.url = [NSURL IDNEncodedURL:urlTextField.text];
    NSLog(@"blog url: %@", self.url);
    self.username = usernameTextField.text;
    self.password = passwordTextField.text;
    
    saveButton.enabled = NO;
	[self.navigationItem setHidesBackButton:YES animated:NO];
    BOOL validFields = YES;
    if ([urlTextField.text isEqualToString:@""]) {
        validFields = NO;
        self.urlCell.textLabel.textColor = WRONG_FIELD_COLOR;
    }
    if ([usernameTextField.text isEqualToString:@""]) {
        validFields = NO;
        self.usernameCell.textLabel.textColor = WRONG_FIELD_COLOR;
    }
    if ([passwordTextField.text isEqualToString:@""]) {
        validFields = NO;
        self.passwordCell.textLabel.textColor = WRONG_FIELD_COLOR;
    }
    
    if (validFields) {
        [self checkURL];
    } else {
        [self validationDidFail:nil];
    }
}

- (void)save:(id)sender {
    [urlTextField resignFirstResponder];
    [usernameTextField resignFirstResponder];
    [passwordTextField resignFirstResponder];
	
	if (savingIndicator == nil) {
		savingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		[savingIndicator setFrame:CGRectMake(0,0,20,20)];
		[savingIndicator setCenter:CGPointMake(tableView.center.x, savingIndicator.center.y)];
		UIView *aView = [[UIView alloc] init];
		[aView addSubview:savingIndicator];
		
		[self.tableView setTableFooterView:aView];
        [aView release];
	}
	[savingIndicator setHidden:NO];
	[savingIndicator startAnimating];

    if (blog) {
        blog.geolocationEnabled = self.geolocationEnabled;
        [blog dataSave];
    }
	
	if(blog == nil || blog.username == nil) {
		[self validateFields];
	} else 
		if ([self.username isEqualToString:usernameTextField.text]
			&& [self.password isEqualToString:passwordTextField.text]
			&& [self.url isEqualToString:urlTextField.text]) {
			// No need to check if nothing changed
            [self.navigationController popToRootViewControllerAnimated:YES];
		} else {
			[self validateFields];
		}
}

- (void)cancel:(id)sender {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)handleKeyboardWillShow:(NSNotification *)notification {
    CGRect rect = [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, rect.size.height, 0.0);
    tableView.contentInset = contentInsets;
    tableView.scrollIndicatorInsets = contentInsets;
    
    CGRect frame = self.view.frame;
    frame.size.height -= rect.size.height;
    if (!CGRectContainsPoint(frame, lastTextField.frame.origin)) {
        CGPoint scrollPoint = CGPointMake(0.0, lastTextField.frame.origin.y - rect.size.height/2.0);
        [tableView setContentOffset:scrollPoint animated:YES];
    }
}

- (void)handleKeyboardWillHide:(NSNotification *)notification {
    [UIView animateWithDuration:0.3 animations:^{
        tableView.contentInset = UIEdgeInsetsZero;
        tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
    }];
}

- (void)handleViewTapped {
    [lastTextField resignFirstResponder];
}

@end

