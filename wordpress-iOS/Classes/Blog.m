//
//  Blog.m
//  WordPress
//
//  Created by Gareth Townsend on 24/06/09.
//

#import "Blog.h"
#import "Post.h"
#import "Page.h"
#import "Category.h"
#import "Comment.h"
#import "SFHFKeychainUtils.h"
#import "UIImage+Resize.h"
#import "NSURL+IDN.h"
#import "NSString+XMLExtensions.h"

@interface Blog (PrivateMethods)
- (AFXMLRPCRequestOperation *)operationForOptionsWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure;
- (AFXMLRPCRequestOperation *)operationForPostFormatsWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure;
- (AFXMLRPCRequestOperation *)operationForCommentsWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure;
- (AFXMLRPCRequestOperation *)operationForCategoriesWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure;
- (AFXMLRPCRequestOperation *)operationForPostsWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure loadMore:(BOOL)more;
- (AFXMLRPCRequestOperation *)operationForPagesWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure loadMore:(BOOL)more;

- (void)mergeCategories:(NSArray *)newCategories;
- (void)mergeComments:(NSArray *)newComments;
- (void)mergePages:(NSArray *)newPages;
- (void)mergePosts:(NSArray *)newPosts;
@end


@implementation Blog {
    AFXMLRPCClient *_api;
    NSString *_blavatarUrl;
    Reachability *_reachability;
    BOOL _isReachable;
}
@dynamic blogID, blogName, url, username, password, xmlrpc, apiKey;
@dynamic isAdmin, hasOlderPosts, hasOlderPages;
@dynamic posts, categories, comments; 
@dynamic lastPostsSync, lastStatsSync, lastPagesSync, lastCommentsSync;
@synthesize isSyncingPosts, isSyncingPages, isSyncingComments;
@dynamic geolocationEnabled, options, postFormats, isActivated;

- (BOOL)geolocationEnabled 
{
    BOOL tmpValue;
    
    [self willAccessValueForKey:@"geolocationEnabled"];
    tmpValue = [[self primitiveValueForKey:@"geolocationEnabled"] boolValue];
    [self didAccessValueForKey:@"geolocationEnabled"];
    
    return tmpValue;
}

- (void)setGeolocationEnabled:(BOOL)value 
{
    [self willChangeValueForKey:@"geolocationEnabled"];
    [self setPrimitiveValue:[NSNumber numberWithBool:value] forKey:@"geolocationEnabled"];
    [self didChangeValueForKey:@"geolocationEnabled"];
}

#pragma mark -
#pragma mark Custom methods

+ (BOOL)blogExistsForURL:(NSString *)theURL withContext:(NSManagedObjectContext *)moc andUsername:(NSString *)username{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Blog"
                                        inManagedObjectContext:moc]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"url like %@ AND username = %@", theURL, username]];
    NSError *error = nil;
    NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
    [fetchRequest release]; fetchRequest = nil;
    
    return (results.count > 0);
}

+ (Blog *)createFromDictionary:(NSDictionary *)blogInfo withContext:(NSManagedObjectContext *)moc {
    Blog *blog = nil;
    NSString *blogUrl = [[blogInfo objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"http://" withString:@""];
	if([blogUrl hasSuffix:@"/"])
		blogUrl = [blogUrl substringToIndex:blogUrl.length-1];
	blogUrl= [blogUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if (![self blogExistsForURL:blogUrl withContext:moc andUsername: [blogInfo objectForKey:@"username"]]) {
        blog = [[[Blog alloc] initWithEntity:[NSEntityDescription entityForName:@"Blog"
                                                         inManagedObjectContext:moc]
              insertIntoManagedObjectContext:moc] autorelease];
        
        blog.url = blogUrl;
        blog.blogID = [NSNumber numberWithInt:[[blogInfo objectForKey:@"blogid"] intValue]];
        blog.blogName = [[blogInfo objectForKey:@"blogName"] stringByDecodingXMLCharacters];
		blog.xmlrpc = [blogInfo objectForKey:@"xmlrpc"];
        blog.username = [blogInfo objectForKey:@"username"];
        blog.isAdmin = [NSNumber numberWithInt:[[blogInfo objectForKey:@"isAdmin"] intValue]];
        
        NSError *error = nil;
        [SFHFKeychainUtils storeUsername:[blogInfo objectForKey:@"username"]
                             andPassword:[blogInfo objectForKey:@"password"]
                          forServiceName:blog.hostURL
                          updateExisting:TRUE
                                   error:&error ];
        // TODO: save blog settings
	}
    return blog;
}

+ (Blog *)findWithId:(int)blogId withContext:(NSManagedObjectContext *)moc {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"Blog" inManagedObjectContext:moc]];
    [request setPredicate:[NSPredicate predicateWithFormat:@"blogID = %d", blogId]];

    NSError *err = nil;
    NSArray *result = [moc executeFetchRequest:request error:&err];
    [request release];
    Blog *blog = nil;
    if (err == nil && [result count] > 0 ) {
        blog = [result objectAtIndex:0];
    }
    return blog;
}

+ (NSInteger)countWithContext:(NSManagedObjectContext *)moc {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"Blog" inManagedObjectContext:moc]];
    [request setIncludesSubentities:NO];
    
    NSError *err;
    NSUInteger count = [moc countForFetchRequest:request error:&err];
    [request release];
    if(count == NSNotFound) {
        count = 0;
    }
    return count;
}

- (NSString *)blavatarUrl {
	if (_blavatarUrl == nil) {
        NSString *hostUrl = [[NSURL URLWithString:self.xmlrpc] host];
        if (hostUrl == nil) {
            hostUrl = self.xmlrpc;
        }
		
        _blavatarUrl = [hostUrl retain];
    }

    return _blavatarUrl;
}

// used as a key to store passwords, if you change the algorithm, logins will break
- (NSString *)displayURL {
    NSError *error = NULL;
    NSRegularExpression *protocol = [NSRegularExpression regularExpressionWithPattern:@"http(s?)://" options:NSRegularExpressionCaseInsensitive error:&error];
    NSString *result = [NSString stringWithFormat:@"%@", [protocol stringByReplacingMatchesInString:[NSURL IDNDecodedHostname:self.url] options:0 range:NSMakeRange(0, [[NSURL IDNDecodedHostname:self.url] length]) withTemplate:@""]];
    
    if([result hasSuffix:@"/"])
        result = [result substringToIndex:[result length] - 1];
    
    return result;
}

- (NSString *)hostURL {
    return [self displayURL];
}

- (NSString *)hostname {
    NSString *hostname = [[NSURL URLWithString:self.url] host];
    if (hostname == nil) {
        NSError *error = NULL;
        NSRegularExpression *protocol = [NSRegularExpression regularExpressionWithPattern:@"^.*://" options:NSRegularExpressionCaseInsensitive error:&error];
        hostname = [protocol stringByReplacingMatchesInString:self.url options:0 range:NSMakeRange(0, [self.url length]) withTemplate:@""];
    }
    return hostname;
}

- (NSString *)loginURL {
    NSError *error = NULL;
    NSRegularExpression *xmlrpc = [NSRegularExpression regularExpressionWithPattern:@"/xmlrpc.php$" options:NSRegularExpressionCaseInsensitive error:&error];
    return [xmlrpc stringByReplacingMatchesInString:self.xmlrpc options:0 range:NSMakeRange(0, [self.xmlrpc length]) withTemplate:@"/wp-login.php"];
}

- (int)numberOfPendingComments{
    int pendingComments = 0;
    for (Comment *element in self.comments) {
        if ( [@"hold" isEqualToString: element.status] )
            pendingComments++;
    }
    
    return pendingComments;
}

-(NSArray *)sortedCategories {
	NSSortDescriptor *sortNameDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"categoryName" 
																		ascending:YES 
																		 selector:@selector(caseInsensitiveCompare:)] autorelease];
	NSArray *sortDescriptors = [[[NSArray alloc] initWithObjects:sortNameDescriptor, nil] autorelease];
	
	return [[self.categories allObjects] sortedArrayUsingDescriptors:sortDescriptors];
}

- (NSArray *)sortedPostFormatNames {
    NSMutableArray *sortedNames = [NSMutableArray arrayWithCapacity:[self.postFormats count]];
    [sortedNames addObject:[self.postFormats objectForKey:@"standard"]];
    [self.postFormats enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (![key isEqual:@"standard"]) {
            [sortedNames addObject:obj];
        }
    }];
    return [NSArray arrayWithArray:sortedNames];
}

- (BOOL)isWPcom {
    NSRange range = [self.xmlrpc rangeOfString:@"wordpress.com"];
	return (range.location != NSNotFound);
}

//WP.COM private blog. 
- (BOOL)isPrivate {
    if ( [self isWPcom] && [[self getOptionValue:@"blog_public"] isEqual:@"-1"] )
        return YES;
    return NO;
}

- (NSDictionary *) getImageResizeDimensions{
    CGSize smallSize, mediumSize, largeSize;
    int thumbnail_size_w =  ([self getOptionValue:@"thumbnail_size_w"] != nil ? [[self getOptionValue:@"thumbnail_size_w"] intValue] : image_small_size_w);
    int thumbnail_size_h =  [self getOptionValue:@"thumbnail_size_h"] != nil ? [[self getOptionValue:@"thumbnail_size_h"] intValue] : image_small_size_h;
    int medium_size_w =     [self getOptionValue:@"medium_size_w"] != nil ? [[self getOptionValue:@"medium_size_w"] intValue] : image_medium_size_w;
    int medium_size_h =     [self getOptionValue:@"medium_size_h"] != nil ? [[self getOptionValue:@"medium_size_h"] intValue] : image_medium_size_h;
    int large_size_w =      [self getOptionValue:@"large_size_w"] != nil ? [[self getOptionValue:@"large_size_w"] intValue] : image_large_size_w;
    int large_size_h =      [self getOptionValue:@"large_size_h"] != nil ? [[self getOptionValue:@"large_size_h"] intValue] : image_large_size_h;
    
    smallSize = CGSizeMake(thumbnail_size_w, thumbnail_size_h);
    mediumSize = CGSizeMake(medium_size_w, medium_size_h);
    largeSize = CGSizeMake(large_size_w, large_size_h);
    
    return [NSDictionary dictionaryWithObjectsAndKeys: [NSValue valueWithCGSize:smallSize], @"smallSize", 
            [NSValue valueWithCGSize:mediumSize], @"mediumSize", 
            [NSValue valueWithCGSize:largeSize], @"largeSize", 
            nil];
}


- (void)awakeFromFetch {
    [self reachability];
}

- (void)dataSave {
    NSError *error = nil;
    if (![[self managedObjectContext] save:&error]) {
        WPFLog(@"Unresolved Core Data Save error %@, %@", error, [error userInfo]);
        exit(-1);
    }
}

- (void)remove {
    WPFLog(@"<Blog:%@> remove", self.hostURL);
    [self.api cancelAllHTTPOperations];
    [[self managedObjectContext] deleteObject:self];
    [self dataSave];
}

- (void)setXmlrpc:(NSString *)xmlrpc {
    [self willChangeValueForKey:@"xmlrpc"];
    [self setPrimitiveValue:xmlrpc forKey:@"xmlrpc"];
    [self didChangeValueForKey:@"xmlrpc"];
    [_blavatarUrl release]; _blavatarUrl = nil;

    // Reset the api client so next time we use the new XML-RPC URL
    [_api release]; _api = nil;
}

- (NSArray *)getXMLRPCArgsWithExtra:(id)extra {
    NSMutableArray *result = [NSMutableArray array];
    [result addObject:self.blogID];
    [result addObject:self.username];
    [result addObject:[self fetchPassword]];
    
    if ([extra isKindOfClass:[NSArray class]]) {
        [result addObjectsFromArray:extra];
    } else if (extra != nil) {
        [result addObject:extra];
    }
    
    return [NSArray arrayWithArray:result];
}

- (NSString *)fetchPassword {
    NSError *err;
	NSString *password;

	if (self.isWPcom) {
        password = [SFHFKeychainUtils getPasswordForUsername:self.username
                                              andServiceName:@"WordPress.com"
                                                       error:&err];
    } else {
		password = [SFHFKeychainUtils getPasswordForUsername:self.username
                                              andServiceName:self.hostURL
                                                       error:&err];
	}
	if (password == nil)
		password = @""; // FIXME: not good either, but prevents from crashing

	return password;
}

- (NSString *)version {
    return [self getOptionValue:@"software_version"];
}

- (Reachability *)reachability {
    if (_reachability == nil) {
        _reachability = [[Reachability reachabilityWithHostname:self.hostname] retain];
        _reachability.reachableBlock = ^(Reachability *reach) {
            [self willChangeValueForKey:@"reachable"];
            _isReachable = YES;
            [self didChangeValueForKey:@"reachable"];
        };
        _reachability.unreachableBlock = ^(Reachability *reach) {
            [self willChangeValueForKey:@"reachable"];
            _isReachable = NO;
            [self didChangeValueForKey:@"reachable"];
        };
        [_reachability startNotifier];
    }
    
    return _reachability;
}

- (BOOL)reachable {
    // Creates reachability object if it's nil
    [self reachability];
    return _isReachable;
}

#pragma mark -
#pragma mark Synchronization

- (NSArray *)syncedPostsWithEntityName:(NSString *)entityName {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:entityName inManagedObjectContext:[self managedObjectContext]]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(remoteStatusNumber = %@) AND (postID != NULL) AND (original == NULL) AND (blog = %@)",
							  [NSNumber numberWithInt:AbstractPostRemoteStatusSync], self]; 
    [request setPredicate:predicate];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"date_created_gmt" ascending:YES];
    [request setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    [sortDescriptor release];
    
    NSError *error = nil;
    NSArray *array = [[self managedObjectContext] executeFetchRequest:request error:&error];
    [request release];
    if (array == nil) {
        array = [NSArray array];
    }
    return array;
}

- (NSArray *)syncedPosts {
    return [self syncedPostsWithEntityName:@"Post"];
}

- (void)syncPostsWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure loadMore:(BOOL)more {
    if (self.isSyncingPosts) {
        WPLog(@"Already syncing posts. Skip");
        return;
    }
    self.isSyncingPosts = YES;

    AFXMLRPCRequestOperation *operation = [self operationForPostsWithSuccess:success failure:failure loadMore:more];
    [self.api enqueueXMLRPCRequestOperation:operation];
}

- (NSArray *)syncedPages {
    return [self syncedPostsWithEntityName:@"Page"];
}

- (void)syncPagesWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure loadMore:(BOOL)more {
	if (self.isSyncingPages) {
        WPLog(@"Already syncing pages. Skip");
        return;
    }
    self.isSyncingPages = YES;
    AFXMLRPCRequestOperation *operation = [self operationForPagesWithSuccess:success failure:failure loadMore:more];
    [self.api enqueueXMLRPCRequestOperation:operation];
}

- (void)syncCategoriesWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure {
    AFXMLRPCRequestOperation *operation = [self operationForCategoriesWithSuccess:success failure:failure];
    [self.api enqueueXMLRPCRequestOperation:operation];
}

- (void)syncOptionsWithWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure {
    AFXMLRPCRequestOperation *operation = [self operationForOptionsWithSuccess:success failure:failure];
    [self.api enqueueXMLRPCRequestOperation:operation];
}

- (NSString *)getOptionValue:(NSString *) name {
	if ( self.options == nil || (self.options.count == 0) ) {
        return nil;
    }
    NSDictionary *currentOption = [self.options objectForKey:name];
    
    return [currentOption objectForKey:@"value"];
}

- (void)syncCommentsWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure {
	if (self.isSyncingComments) {
        WPLog(@"Already syncing comments. Skip");
        return;
    }
    self.isSyncingComments = YES;
    AFXMLRPCRequestOperation *operation = [self operationForCommentsWithSuccess:success failure:failure];
    [self.api enqueueXMLRPCRequestOperation:operation];
}

- (void)syncPostFormatsWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure {
    AFXMLRPCRequestOperation *operation = [self operationForPostFormatsWithSuccess:success failure:failure];
    [self.api enqueueXMLRPCRequestOperation:operation];
}

- (void)syncBlogWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure {
    AFXMLRPCRequestOperation *operation;
    NSMutableArray *operations = [NSMutableArray arrayWithCapacity:6];
    operation = [self operationForOptionsWithSuccess:nil failure:nil];
    [operations addObject:operation];
    operation = [self operationForPostFormatsWithSuccess:nil failure:nil];
    [operations addObject:operation];
    operation = [self operationForCategoriesWithSuccess:nil failure:nil];
    [operations addObject:operation];
    if (!self.isSyncingComments) {
        operation = [self operationForCommentsWithSuccess:nil failure:nil];
        [operations addObject:operation];
        self.isSyncingComments = YES;
    }
    if (!self.isSyncingPosts) {
        operation = [self operationForPostsWithSuccess:nil failure:nil loadMore:NO];
        [operations addObject:operation];
        self.isSyncingPosts = YES;
    }
    if (!self.isSyncingPages) {
        operation = [self operationForPagesWithSuccess:nil failure:nil loadMore:NO];
        [operations addObject:operation];
        self.isSyncingPages = YES;
    }

    AFHTTPRequestOperation *combinedOperation = [self.api combinedHTTPRequestOperationWithOperations:operations success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (success) {
            success();
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (failure) {
            failure(error);
        }
    }];
    [self.api enqueueHTTPRequestOperation:combinedOperation];
}

- (void)syncBlogPostsWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure {
    AFXMLRPCRequestOperation *operation;
    NSMutableArray *operations = [NSMutableArray arrayWithCapacity:4];
    operation = [self operationForOptionsWithSuccess:nil failure:nil];
    [operations addObject:operation];
    operation = [self operationForPostFormatsWithSuccess:nil failure:nil];
    [operations addObject:operation];
    operation = [self operationForCategoriesWithSuccess:nil failure:nil];
    [operations addObject:operation];
    if (!self.isSyncingPosts) {
        operation = [self operationForPostsWithSuccess:success failure:failure loadMore:NO];
        [operations addObject:operation];
        self.isSyncingPosts = YES;
    }
    
    AFHTTPRequestOperation *combinedOperation = [self.api combinedHTTPRequestOperationWithOperations:operations success:nil failure:nil];
    [self.api enqueueHTTPRequestOperation:combinedOperation];    
}


- (void)checkActivationStatusWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure {
    WPFLogMethod();
    AFXMLRPCClient *api = [AFXMLRPCClient clientWithXMLRPCEndpoint:[NSURL URLWithString:[NSString stringWithFormat: @"%@", kWPcomXMLRPCUrl]]];
    [api callMethod:@"wpcom.getActivationStatus"
         parameters:[NSArray arrayWithObjects:[self hostURL], nil]
            success:^(AFHTTPRequestOperation *operation, id responseObject) {
                NSString *returnData = [responseObject retain];
                if ([returnData isKindOfClass:[NSString class]]) {
                    [self setBlogID:[returnData numericValue]];
                    [self setIsActivated:[NSNumber numberWithBool:YES]];
                    [self dataSave];
                }
                if (success) success();
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSString *errorMessage = [error localizedDescription];
                
                if ([errorMessage isEqualToString:@"Parse Error. Please check your XML-RPC endpoint."])
                {
                    [self setIsActivated:[NSNumber numberWithBool:YES]];
                    [self dataSave];
                    if (success) success();
                } else if ([errorMessage isEqualToString:@"Site not activated."]) {
                    if (failure) failure(error);
                } else if ([errorMessage isEqualToString:@"Blog not found."]) {
                    if (failure) failure(error);
                } else {
                    if (failure) failure(error);
                }
                
            }];
}


#pragma mark - api accessor

- (AFXMLRPCClient *)api {
    if (_api == nil) {
        _api = [[AFXMLRPCClient alloc] initWithXMLRPCEndpoint:[NSURL URLWithString:self.xmlrpc]];
    }
    return _api;
}

#pragma mark -

- (AFXMLRPCRequestOperation *)operationForOptionsWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure {
    NSArray *parameters = [self getXMLRPCArgsWithExtra:nil];
    AFXMLRPCRequest *request = [self.api XMLRPCRequestWithMethod:@"wp.getOptions" parameters:parameters];
    AFXMLRPCRequestOperation *operation = [self.api XMLRPCRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([self isDeleted])
            return;

        self.options = [NSDictionary dictionaryWithDictionary:(NSDictionary *)responseObject];
        if (success) {
            success();
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        WPFLog(@"Error syncing options: %@", [error localizedDescription]);

        if (failure) {
            failure(error);
        }
    }];

    return operation;
}

- (AFXMLRPCRequestOperation *)operationForPostFormatsWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure {
    NSDictionary *dict = [NSDictionary dictionaryWithObject:@"1" forKey:@"show-supported"];
    NSArray *parameters = [self getXMLRPCArgsWithExtra:dict];
    
    AFXMLRPCRequest *request = [self.api XMLRPCRequestWithMethod:@"wp.getPostFormats" parameters:parameters];
    AFXMLRPCRequestOperation *operation = [self.api XMLRPCRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([self isDeleted])
            return;

        NSDictionary *respDict = [NSDictionary dictionaryWithDictionary:(NSDictionary *)responseObject];
        if ([respDict objectForKey:@"supported"]) {
            NSMutableArray *supportedKeys = [NSMutableArray arrayWithArray:[respDict objectForKey:@"supported"]];
            // Standard isn't included in the list of supported formats? Maybe it will be one day?
            if (![supportedKeys containsObject:@"standard"]) {
                [supportedKeys addObject:@"standard"];
            }
            
            NSDictionary *allFormats = [respDict objectForKey:@"all"];
            NSMutableArray *supportedValues = [NSMutableArray array];
            for (NSString *key in supportedKeys) {
                [supportedValues addObject:[allFormats objectForKey:key]];
            }
            respDict = [NSDictionary dictionaryWithObjects:supportedValues forKeys:supportedKeys];
        }
        self.postFormats = respDict;
        if (success) {
            success();
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        WPFLog(@"Error syncing post formats: %@", [error localizedDescription]);

        if (failure) {
            failure(error);
        }
    }];
    
    return operation;
}

- (AFXMLRPCRequestOperation *)operationForCommentsWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure {
    NSDictionary *requestOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:100] forKey:@"number"];
    NSArray *parameters = [self getXMLRPCArgsWithExtra:requestOptions];
    AFXMLRPCRequest *request = [self.api XMLRPCRequestWithMethod:@"wp.getComments" parameters:parameters];
    AFXMLRPCRequestOperation *operation = [self.api XMLRPCRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([self isDeleted])
            return;

        [self mergeComments:responseObject];
        if (success) {
            success();
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kCommentsChangedNotificationName object:self];
        self.isSyncingComments = NO;
        self.lastCommentsSync = [NSDate date];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        WPFLog(@"Error syncing comments: %@", [error localizedDescription]);

        if (failure) {
            failure(error);
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kCommentsChangedNotificationName object:self];
        self.isSyncingComments = NO;
    }];
    
    return operation;
}

- (AFXMLRPCRequestOperation *)operationForCategoriesWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure {
    NSArray *parameters = [self getXMLRPCArgsWithExtra:nil];
    AFXMLRPCRequest *request = [self.api XMLRPCRequestWithMethod:@"wp.getCategories" parameters:parameters];
    AFXMLRPCRequestOperation *operation = [self.api XMLRPCRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([self isDeleted])
            return;

        [self mergeCategories:responseObject];
        if (success) {
            success();
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        WPFLog(@"Error syncing categories: %@", [error localizedDescription]);

        if (failure) {
            failure(error);
        }
    }];
    
    return operation;    
}

- (AFXMLRPCRequestOperation *)operationForPostsWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure loadMore:(BOOL)more {
    int num;

    // Don't load more than 20 posts if we aren't at the end of the table,
    // even if they were previously donwloaded
    // 
    // Blogs with long history can get really slow really fast, 
    // with no chance to go back
    int postBatchSize = 40;
    if (more) {
        num = MAX([self.posts count], postBatchSize);
        if ([self.hasOlderPosts boolValue]) {
            num += postBatchSize;
        }
    } else {
        num = postBatchSize;
    }

    NSArray *parameters = [self getXMLRPCArgsWithExtra:[NSNumber numberWithInt:num]];
    AFXMLRPCRequest *request = [self.api XMLRPCRequestWithMethod:@"metaWeblog.getRecentPosts" parameters:parameters];
    AFXMLRPCRequestOperation *operation = [self.api XMLRPCRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([self isDeleted])
            return;
        
        NSArray *posts = (NSArray *)responseObject;

        // If we asked for more and we got what we had, there are no more posts to load
        if (more && ([posts count] <= [self.posts count])) {
            self.hasOlderPosts = [NSNumber numberWithBool:NO];
        } else if (!more) {
            //we should reset the flag otherwise when you refresh this blog you can't get more than 20 posts
            self.hasOlderPosts = [NSNumber numberWithBool:YES];
        }

        [self mergePosts:posts];

        self.lastPostsSync = [NSDate date];
        self.isSyncingPosts = NO;
        if (success) {
            success();
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        WPFLog(@"Error syncing posts: %@", [error localizedDescription]);
        
        if (failure) {
            failure(error);
        }
        self.isSyncingPosts = NO;
    }];
    
    return operation;        
}

- (AFXMLRPCRequestOperation *)operationForPagesWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure loadMore:(BOOL)more {
    int num;
	
    int syncCount = [[self syncedPages] count];
    // Don't load more than 20 pages if we aren't at the end of the table,
    // even if they were previously donwloaded
    // 
    // Blogs with long history can get really slow really fast, 
    // with no chance to go back
    int pageBatchSize = 40;
    if (more) {
        num = MAX(syncCount, pageBatchSize);
        if ([self.hasOlderPages boolValue]) {
            num += pageBatchSize;
        }
    } else {
        num = pageBatchSize;
    }

    NSArray *parameters = [self getXMLRPCArgsWithExtra:[NSNumber numberWithInt:num]];
    AFXMLRPCRequest *request = [self.api XMLRPCRequestWithMethod:@"wp.getPages" parameters:parameters];
    AFXMLRPCRequestOperation *operation = [self.api XMLRPCRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([self isDeleted])
            return;

        NSArray *pages = (NSArray *)responseObject;

        // If we asked for more and we got what we had, there are no more pages to load
        if (more && ([pages count] <= syncCount)) {
            self.hasOlderPages = [NSNumber numberWithBool:NO];
        } else if (!more) {
            //we should reset the flag otherwise when you refresh this blog you can't get more than 20 pages
            self.hasOlderPages = [NSNumber numberWithBool:YES];
        }

        [self mergePages:pages];
        if (success) {
            success();
        }

        self.lastPagesSync = [NSDate date];
        self.isSyncingPages = NO;
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        WPFLog(@"Error syncing pages: %@", [error localizedDescription]);

        if (failure) {
            failure(error);
        }
        self.isSyncingPages = NO;
    }];

    return operation;
}

#pragma mark -

- (void)mergeCategories:(NSArray *)newCategories {
    // Don't even bother if blog has been deleted while fetching categories
    if ([self isDeleted])
        return;

	NSMutableArray *categoriesToKeep = [NSMutableArray array];
    for (NSDictionary *categoryInfo in newCategories) {
        Category *newCat = [Category createOrReplaceFromDictionary:categoryInfo forBlog:self];
        if (newCat != nil) {
            [categoriesToKeep addObject:newCat];
        } else {
            WPFLog(@"-[Category createOrReplaceFromDictionary:forBlog:] returned a nil category: %@", categoryInfo);
        }
    }

	NSSet *syncedCategories = self.categories;
	if (syncedCategories && (syncedCategories.count > 0)) {
		for (Category *cat in syncedCategories) {
			if(![categoriesToKeep containsObject:cat]) {
				WPLog(@"Deleting Category: %@", cat);
				[[self managedObjectContext] deleteObject:cat];
			}
		}
    }

    [self dataSave];
}

- (void)mergePosts:(NSArray *)newPosts {
    // Don't even bother if blog has been deleted while fetching posts
    if ([self isDeleted])
        return;

    NSMutableArray *postsToKeep = [NSMutableArray array];
    for (NSDictionary *postInfo in newPosts) {
        Post *newPost = [Post createOrReplaceFromDictionary:postInfo forBlog:self];
        if (newPost != nil) {
            [postsToKeep addObject:newPost];
        } else {
            WPFLog(@"-[Post createOrReplaceFromDictionary:forBlog:] returned a nil post: %@", postInfo);
        }
    }

    NSArray *syncedPosts = [self syncedPosts];
    for (Post *post in syncedPosts) {

        if (![postsToKeep containsObject:post]) {  /*&& post.blog.blogID == self.blogID*/
			//the current stored post is not contained "as-is" on the server response

            if (post.revision) { //edited post before the refresh is finished
				//We should check if this post is already available on the blog
				BOOL presence = NO;

				for (Post *currentPostToKeep in postsToKeep) {
					if([currentPostToKeep.postID isEqualToNumber:post.postID]) {
						presence = YES;
						break;
					}
				}
				if( presence == YES ) {
					//post is on the server (most cases), kept it unchanged
				} else {
					//post is deleted on the server, make it local, otherwise you can't upload it anymore
					post.remoteStatus = AbstractPostRemoteStatusLocal;
					post.postID = nil;
					post.permaLink = nil;
				}
			} else {
				//post is not on the server anymore. delete it.
                WPLog(@"Deleting post: %@", post.postTitle);
                WPLog(@"%d posts left", [self.posts count]);
                [[self managedObjectContext] deleteObject:post];
            }
        }
    }

    [self dataSave];
}

- (void)mergePages:(NSArray *)newPages {
    if ([self isDeleted])
        return;

    NSMutableArray *pagesToKeep = [NSMutableArray array];
    for (NSDictionary *pageInfo in newPages) {
        Page *newPage = [Page createOrReplaceFromDictionary:pageInfo forBlog:self];
        if (newPage != nil) {
            [pagesToKeep addObject:newPage];
        } else {
            WPFLog(@"-[Page createOrReplaceFromDictionary:forBlog:] returned a nil page: %@", pageInfo);
        }
    }

    NSArray *syncedPages = [self syncedPages];
    for (Page *page in syncedPages) {
		if (![pagesToKeep containsObject:page]) { /*&& page.blog.blogID == self.blogID*/

			if (page.revision) { //edited page before the refresh is finished
				//We should check if this page is already available on the blog
				BOOL presence = NO;

				for (Page *currentPageToKeep in pagesToKeep) {
					if([currentPageToKeep.postID isEqualToNumber:page.postID]) {
						presence = YES;
						break;
					}
				}
				if( presence == YES ) {
					//page is on the server (most cases), kept it unchanged
				} else {
					//page is deleted on the server, make it local, otherwise you can't upload it anymore
					page.remoteStatus = AbstractPostRemoteStatusLocal;
					page.postID = nil;
					page.permaLink = nil;
				}
			} else {
				//page is not on the server anymore. delete it.
                WPLog(@"Deleting page: %@", page);
                [[self managedObjectContext] deleteObject:page];
            }
        }
    }

    [self dataSave];
}

- (void)mergeComments:(NSArray *)newComments {
    // Don't even bother if blog has been deleted while fetching comments
    if ([self isDeleted])
        return;

	NSMutableArray *commentsToKeep = [NSMutableArray array];
    for (NSDictionary *commentInfo in newComments) {
        Comment *newComment = [Comment createOrReplaceFromDictionary:commentInfo forBlog:self];
        if (newComment != nil) {
            [commentsToKeep addObject:newComment];
        } else {
            WPFLog(@"-[Comment createOrReplaceFromDictionary:forBlog:] returned a nil comment: %@", commentInfo);
        }
    }

	NSSet *syncedComments = self.comments;
    if (syncedComments && (syncedComments.count > 0)) {
		for (Comment *comment in syncedComments) {
			// Don't delete unpublished comments
			if(![commentsToKeep containsObject:comment] && comment.commentID != nil) {
				WPLog(@"Deleting Comment: %@", comment);
				[[self managedObjectContext] deleteObject:comment];
			}
		}
    }

    [self dataSave];
}

#pragma mark -
#pragma mark Dealloc

- (void)dealloc {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
    [_blavatarUrl release]; _blavatarUrl = nil;
    [_api release]; _api = nil;
    [_reachability stopNotifier];
    [_reachability release]; _reachability = nil;
    [super dealloc];
}

@end
