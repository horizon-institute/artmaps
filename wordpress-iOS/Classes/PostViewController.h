//
//  PostViewController.h
//  WordPress
//
//  Created by Jorge Bernal on 12/30/10.
//  Copyright 2010 WordPress. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EditPostViewController.h"
#import "Post.h"

@interface PostViewController : UIViewController <UITextFieldDelegate, UITextViewDelegate, UIWebViewDelegate> {

}

@property (nonatomic, retain) IBOutlet UILabel *titleTitleLabel, *tagsTitleLabel, *categoriesTitleLabel;
@property (nonatomic, retain) IBOutlet UILabel *titleLabel, *tagsLabel, *categoriesLabel;
@property (nonatomic, retain) IBOutlet UITextView *contentView;
@property (nonatomic, retain) IBOutlet UIWebView *contentWebView;
@property (nonatomic, retain) IBOutlet AbstractPost *apost;
@property (nonatomic, assign) Post *post;
@property (nonatomic, assign) Blog * blog;

- (id)initWithPost:(AbstractPost *)aPost;
- (void)showModalEditor;
- (void)refreshUI;
- (void)checkForNewItem;
- (EditPostViewController *) getPostOrPageController: (AbstractPost *)revision;
- (void)deletePost:(id)sender;
- (void)refreshUI;
- (NSString *)formatString:(NSString *)str;

@end
