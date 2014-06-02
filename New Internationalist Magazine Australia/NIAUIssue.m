//
//  NIAUIssue.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 24/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUIssue.h"

NSString *ArticlesDidUpdateNotification = @"ArticlesDidUpdate";
NSString *ArticlesFailedUpdateNotification = @"ArticlesFailedUpdate";

@implementation NIAUIssue

#pragma mark NSCoding

#define kRatingKey      @"Dictionary"

- (void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:dictionary forKey:kRatingKey];
}

- (id)initWithCoder:(NSCoder *)decoder {
    NSDictionary *_dictionary = [decoder decodeObjectForKey:kRatingKey];
    return [self initWithDictionary:_dictionary];
}

-(id)init {
    if (self = [super init]) {
        requestingArticles = false;
        requestingCover = false;
        
        coverCache = [self buildCoverCache];
        coverThumbCache = [self buildCoverThumbCache];
        categoriesSortedCache = [self buildCategoriesSortedCache];
        articlesSortedCache = [self buildArticlesSortedCache];
    }
    return self;
}

- (NSURL *)coverURL
{
    // Get JPG version instead of PNG
    // PNG Version
//    NSString *url = [[[dictionary objectForKey:@"cover"] objectForKey:@"png"] objectForKey:@"url"];
    // JPG Version
    NSString *url = [[dictionary objectForKey:@"cover"] objectForKey:@"url"];
    // online location of cover
    return [NSURL URLWithString:url relativeToURL:[NSURL URLWithString:SITE_URL]];
}

- (NSURL *)coverCacheURL
{
    NSString *coverFileName = [[self coverURL] lastPathComponent];
    // local URL to where the cover is/would be stored
    return [NSURL URLWithString:coverFileName relativeToURL:[self.nkIssue contentURL]];
}

- (NSURL *)categoriesSortedURL
{
    return [NSURL URLWithString:@"categoriesSorted.plist" relativeToURL:[self.nkIssue contentURL]];
}

- (NSURL *)articlesSortedURL
{
    return [NSURL URLWithString:@"articlesSorted.plist" relativeToURL:[self.nkIssue contentURL]];
}

- (NSURL *)coverCacheURLForSize:(CGSize)size
{
    NSString *coverFileName = [[self coverURL] lastPathComponent];
    // local URL to where the cover is/would be stored
    NSString *coverCacheFileName = [coverFileName stringByAppendingPathExtension:[NSString stringWithFormat:@"thumb%dx%d.%@",(int)size.width,(int)size.height,[coverFileName pathExtension]]];
    return [NSURL URLWithString:coverCacheFileName relativeToURL:[self.nkIssue contentURL]];
}

-(UIImage *)attemptToGetCoverThumbFromMemoryForSize:(CGSize)size {
    return [coverThumbCache readWithOptions:@{@"size":[NSValue valueWithCGSize:size]} stoppingAt:@"disk"];
}

- (NIAUCache *)buildCoverCache
{
    __weak NIAUIssue *weakSelf = self;
    
    NIAUCache *cache = [[NIAUCache alloc] init];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"memory" withReadBlock:^id(id options, id state) {
        return state[@"cover"];
    } andWriteBlock:^(id object, id options, id state) {
        state[@"cover"] = object;
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"disk" withReadBlock:^id(id options, id state) {
        // TODO: Pull the CGSize out of the options string.
        NSLog(@"Trying to read cached image from %@",[weakSelf coverCacheURL]);
        NSData *data = [NSData dataWithContentsOfURL:[weakSelf coverCacheURL]];
        return [UIImage imageWithData:data];
    } andWriteBlock:^(id object, id options, id state) {
        [UIImagePNGRepresentation(object) writeToURL:[weakSelf coverCacheURL] atomically:YES];
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"net" withReadBlock:^id(id options, id state) {
        NSLog(@"NET trying to read cached image from %@",[[weakSelf coverURL] absoluteURL]);
        NSData *imageData = [NSData dataWithContentsOfCookielessURL:[weakSelf coverURL]];
        return [UIImage imageWithData:imageData];
    } andWriteBlock:^(id object, id options, id state) {
        // Nothing to do, can't write to the net.
    }]];
    return cache;
}

- (NIAUCache *)buildCoverThumbCache
{
    __weak NIAUIssue *weakSelf = self;
    
    NIAUCache *cache = [[NIAUCache alloc] init];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"memory" withReadBlock:^id(id options, id state) {
        return state[options[@"size"]];
    } andWriteBlock:^(id object, id options, id state) {
        state[options[@"size"]] = object;
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"disk" withReadBlock:^id(id options, id state) {
        CGSize size = [(NSValue *)options[@"size"] CGSizeValue];
        NSLog(@"Trying to read cached thumb image from %@",[weakSelf coverCacheURLForSize:size]);
        return [UIImage imageWithData:[NSData dataWithContentsOfURL:[weakSelf coverCacheURLForSize:size]]];
    } andWriteBlock:^(id object, id options, id state) {
        CGSize size = [(NSValue *)options[@"size"] CGSizeValue];
        [UIImagePNGRepresentation(object) writeToURL:[weakSelf coverCacheURLForSize:size] atomically:YES];
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"generate" withReadBlock:^id(id options, id state) {
        CGSize size = [(NSValue *)options[@"size"] CGSizeValue];
        return [weakSelf generateCoverCacheThumbWithSize:size];
    } andWriteBlock:^(id object, id options, id state) {
        // Nothing to do, can't write to the net.
    }]];
    return cache;
}

- (NIAUCache *)buildCategoriesSortedCache
{
    __weak NIAUIssue *weakSelf = self;
    
    NIAUCache *cache = [[NIAUCache alloc] init];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"memory" withReadBlock:^id(id options, id state) {
        return state[@"categoriesSorted"];
    } andWriteBlock:^(id object, id options, id state) {
        if ([object count] > 0) {
            state[@"categoriesSorted"] = object;
        }
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"disk" withReadBlock:^id(id options, id state) {
        NSLog(@"Trying to read cached sorted categories from %@",[weakSelf categoriesSortedURL]);
        NSData *data = [NSData dataWithContentsOfURL:[weakSelf categoriesSortedURL]];
        NSArray *unarchived = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        if ([unarchived count] > 0) {
            return unarchived;
        } else {
            return nil;
        }
    } andWriteBlock:^(id object, id options, id state) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object];
        // TODO: FIX THIS SEE WHY MULTIPLE WRITES
        BOOL writeSuccessful = [data writeToFile:[[weakSelf categoriesSortedURL] path] atomically:YES];
        if (writeSuccessful) {
            NSLog(@"Categories write successful!");
        } else {
            NSLog(@"Categories write FAILED.");
        }
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"net" withReadBlock:^id(id options, id state) {
        NSLog(@"NET(ish) building sorted categories.");
        return weakSelf.sortedCategories;
    } andWriteBlock:^(id object, id options, id state) {
        // Nothing to do, can't write to the net.
    }]];
    return cache;
}

- (NIAUCache *)buildArticlesSortedCache
{
    __weak NIAUIssue *weakSelf = self;
    
    NIAUCache *cache = [[NIAUCache alloc] init];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"memory" withReadBlock:^id(id options, id state) {
        return state[@"articlesSorted"];
    } andWriteBlock:^(id object, id options, id state) {
        if ([object count] > 0) {
            state[@"articlesSorted"] = object;
        }
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"disk" withReadBlock:^id(id options, id state) {
        NSLog(@"Trying to read cached sorted articles from %@",[weakSelf articlesSortedURL]);
        NSData *data = [NSData dataWithContentsOfURL:[weakSelf articlesSortedURL]];
        NSArray *unarchived = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        if ([unarchived count] > 0) {
            return unarchived;
        } else {
            return nil;
        }
    } andWriteBlock:^(id object, id options, id state) {
        // TODO: FIX THIS SEE WHY MULTIPLE WRITES
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object];
        BOOL writeSuccessful = [data writeToFile:[[weakSelf articlesSortedURL] path] atomically:YES];
        if (writeSuccessful) {
            NSLog(@"Articles write successful!");
        } else {
            NSLog(@"Articles write FAILED.");
        }
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"net" withReadBlock:^id(id options, id state) {
        NSLog(@"NET(ish) building sorted articles.");
        return weakSelf.sortedArticles;
    } andWriteBlock:^(id object, id options, id state) {
        // Nothing to do, can't write to the net.
    }]];
    return cache;
}

-(UIImage *)getCoverImage {
    return [coverCache readWithOptions:nil];
}

-(UIImage *)generateCoverCacheThumbWithSize:(CGSize)thumbSize {
    UIImage *image = [self getCoverImage];
    
    // don't make blank thumbnails ;)
    if(!image) return nil;
    
    UIGraphicsBeginImageContextWithOptions(thumbSize, NO, 0.0f);
    float thumbAspect = thumbSize.width/thumbSize.height;
    float imageAspect = [image size].width/[image size].height;
    CGRect drawRect;
    if(imageAspect > thumbAspect) {
        // image is wider than thumb
        float drawWidth = thumbSize.height*imageAspect;
        drawRect = CGRectMake(-(drawWidth-thumbSize.width)/2.0, 0.0, drawWidth, thumbSize.height);
    } else {
        // image is taller than thumb
        float drawHeight = thumbSize.width/imageAspect;
        drawRect = CGRectMake(0.0, -(drawHeight-thumbSize.height)/2.0, thumbSize.width, drawHeight);
    }
    [image drawInRect:drawRect];
    UIImage *thumb = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return thumb;
}

-(void)getCoverThumbWithSize:(CGSize)size andCompletionBlock:(void (^)(UIImage *))block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                   ^{
                       UIImage *thumb = [self getCoverThumbWithSize:size];
                       // run the block on the main queue so it can do ui stuff
                       dispatch_async(dispatch_get_main_queue(), ^{
                           block(thumb);
                       });
                   });
}

-(UIImage *)getCoverThumbWithSize:(CGSize)size {
    return [coverThumbCache readWithOptions:@{@"size":[NSValue valueWithCGSize:size]}];
}

- (NSArray *)getCategoriesSortedStartingAt:(NSString *)startingAt
{
    return [categoriesSortedCache readWithOptions:nil startingAt:startingAt stoppingAt:nil];
}

- (NSArray *)getCategoriesSorted
{
    return [categoriesSortedCache readWithOptions:nil];
}

- (NSArray *)getArticlesSortedStartingAt:(NSString *)startingAt
{
    return [articlesSortedCache readWithOptions:nil startingAt:startingAt stoppingAt:nil];
}

- (NSArray *)getArticlesSorted
{
    return [articlesSortedCache readWithOptions:nil];
}

//build from dictionary (and write to cache)
// called when downloading issues.json from website

-(NIAUIssue *)initWithDictionary:(NSDictionary *)dict {
    if (self = [self init]) {
        dictionary = dict;
        
        [self addToNewsstand];
        [self writeToCache];
    }
    return self;
}

-(NIAUIssue *)initWithUserInfo:(NSDictionary *)dict {
    if (self = [self init]) {
        dictionary = dict;
        
        [self addToNewsstand];
    }
    return self;
}

+(NIAUIssue *)issueWithDictionary:(NSDictionary *)dict {
    return [[NIAUIssue alloc] initWithDictionary:dict];
}

+(NIAUIssue *)issueWithUserInfo:(NSDictionary *)dict {
    // Make the Issue dictionary from the userInfo
    if (dict) {
        NSMutableDictionary *tmpDict = [[NSMutableDictionary alloc] init];
        [tmpDict setObject:[dict objectForKey:@"name"] forKey:@"name"];
        [tmpDict setObject:[dict objectForKey:@"publication"] forKey:@"release"];
        
        // If the nkIssue already exists for this dict @"name", return that issue, else init
        
        NIAUIssue *issue = [[NIAUPublisher getInstance] issueWithName:[dict objectForKey:@"name"]];
        
        if (issue) {
            return issue;
        } else {
            return [[NIAUIssue alloc] initWithUserInfo:tmpDict];
        }
    } else {
        return nil;
    }
}

//build from NKIssue object (read from cache)
// called when building from cache

-(NIAUIssue *)initWithNKIssue:(NKIssue *)issue {
    if (self = [self init]) {
        NSError *error;
        // local json URL
        NSURL *jsonURL = [NSURL URLWithString:@"issue.json" relativeToURL:[issue contentURL]];
        NSData *data = [NSData dataWithContentsOfURL:jsonURL];
        
        if (data) {
            dictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
            return self;
        } else {
            return nil;
        }
    }
    return self;
}

+(NIAUIssue *)issueWithNKIssue:(NKIssue *)issue {
    return [[NIAUIssue alloc] initWithNKIssue:issue];
}

+(NSArray *)issuesFromNKLibrary {
    NKLibrary *nkLibrary = [NKLibrary sharedLibrary];
    // Q: since we know the size at creation can this be a normal NSArray?
    NSMutableArray *tmpIssues = [NSMutableArray arrayWithCapacity:[[nkLibrary issues] count]];
    [[nkLibrary issues] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NKIssue *nkIssue = (NKIssue *)obj;
        NIAUIssue *issue = [NIAUIssue issueWithNKIssue:nkIssue];
        if (issue) {
            [tmpIssues addObject:issue];
        }
        
    }];
    return tmpIssues;
}


-(NKIssue *)nkIssue {
    return [[NKLibrary sharedLibrary] issueWithName:self.name];
}

-(void)addToNewsstand {
    if(!self.nkIssue) {
        if (self.name && self.publication) {
            [[NKLibrary sharedLibrary] addIssueWithName:self.name date:self.publication];
        } else {
            // CRASH: Crashlytics issue #23 - low disk space, low ram?
            NSLog(@"ERROR: Trying to add issue to library with name '%@' and date '%@' failed.", self.name, self.publication);
        }
    }
}

-(void)writeToCache {
    // write the relevant issue metadata into cache directory
    NSURL *jsonURL = [NSURL URLWithString:@"issue.json" relativeToURL:[[self nkIssue] contentURL]];
    if (jsonURL) {
        NSLog(@"%@",[jsonURL absoluteString]);
        NSOutputStream *os = [NSOutputStream outputStreamWithURL:jsonURL append:FALSE];
        [os open];
        NSError *error;
        if ([NSJSONSerialization writeJSONObject:dictionary toStream:os options:0 error:&error]<=0) {
            NSLog(@"Error writing JSON file");
        }
        [os close];
    } else {
        NSLog(@"ERROR: no jsonURL in writeToCache - %@", jsonURL);
    }
}

-(NSDate *)publication {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZ"];
    NSDate *date = [dateFormatter dateFromString:[dictionary objectForKey:@"release"]];
    return date;
}

-(NSString *)name {
    return [NSString stringWithFormat:@"%@",[dictionary objectForKey:@"number"]];
}

-(NSString *)title {
    return [dictionary objectForKey:@"title"];
}

-(NSString *)editorsLetter {
    return [dictionary objectForKey:@"editors_letter_html"];
}

-(NSString *)editorsName {
    return [dictionary objectForKey:@"editors_name"];
}

-(NSNumber *)railsID {
    return [dictionary objectForKey:@"id"];
}

-(NSArray *)featureArticles
{
    return [self articlesInCategory:@"features"];
}

-(NSArray *)agendaArticles
{
    return [self articlesInCategory:@"agenda"];
}

-(NSArray *)currentsArticles
{
    return [self articlesInCategory:@"currents"];
}

-(NSArray *)mixedMediaArticles
{
    NSMutableArray *mixedMedia = [NSMutableArray array];
    [mixedMedia addObjectsFromArray:[self articlesInCategory:@"media"]];
    [mixedMedia removeObjectsInArray:[self articlesInCategory:@"agenda"]];
    [mixedMedia removeObjectsInArray:[self articlesInCategory:@"currents"]];
    [mixedMedia removeObjectsInArray:[self articlesInCategory:@"viewfrom"]];
    [mixedMedia removeObjectsInArray:[self articlesInCategory:@"mark-engler"]];
    [mixedMedia removeObjectsInArray:[self articlesInCategory:@"steve-parry"]];
    [mixedMedia removeObjectsInArray:[self articlesInCategory:@"finally"]];
    [mixedMedia removeObjectsInArray:[self articlesInCategory:@"features"]];
    return [[NSArray alloc] initWithArray:mixedMedia];
}

-(NSArray *)opinionArticles
{
    NSMutableArray *opinionArticles = [NSMutableArray array];
    [opinionArticles addObjectsFromArray:[self articlesInCategory:@"argument"]];
    [opinionArticles addObjectsFromArray:[self articlesInCategory:@"viewfrom"]];
    [opinionArticles addObjectsFromArray:[self articlesInCategory:@"steve-parry"]];
    [opinionArticles addObjectsFromArray:[self articlesInCategory:@"mark-engler"]];
    return [[NSArray alloc] initWithArray:opinionArticles];
}

-(NSArray *)alternativesArticles
{
    return [self articlesInCategory:@"alternatives"];
}

-(NSArray *)regularArticles
{
    NSMutableArray *regularArticles = [NSMutableArray array];
    [regularArticles addObjectsFromArray:[self articlesInCategory:@"columns"]];
    [regularArticles removeObjectsInArray:[self articlesInCategory:@"columns/currents"]];
    [regularArticles removeObjectsInArray:[self articlesInCategory:@"columns/media"]];
    [regularArticles removeObjectsInArray:[self articlesInCategory:@"columns/viewfrom"]];
    [regularArticles removeObjectsInArray:[self articlesInCategory:@"columns/mark-engler"]];
    [regularArticles removeObjectsInArray:[self articlesInCategory:@"columns/steve-parry"]];
    return [[NSArray alloc] initWithArray:regularArticles];
}

-(NSArray *)uncategorisedArticles
{
    // TODO: calculate these (mostly blog entries)
    return nil;
}

-(NSArray *)sortedCategories
{
    NSMutableArray *sorted = [NSMutableArray array];
    [self addSortedSection:[self sortedCategoryWithSection:self.featureArticles withName:@"Features"] toArray:sorted];
    [self addSortedSection:[self sortedCategoryWithSection:self.agendaArticles withName:@"Agenda"] toArray:sorted];
    [self addSortedSection:[self sortedCategoryWithSection:self.currentsArticles withName:@"Currents"] toArray:sorted];
    [self addSortedSection:[self sortedCategoryWithSection:self.mixedMediaArticles withName:@"Film, Book & Music reviews"] toArray:sorted];
    [self addSortedSection:[self sortedCategoryWithSection:self.opinionArticles withName:@"Opinion"] toArray:sorted];
    [self addSortedSection:[self sortedCategoryWithSection:self.alternativesArticles withName:@"Alternatives"] toArray:sorted];
    [self addSortedSection:[self sortedCategoryWithSection:self.regularArticles withName:@"Regulars"] toArray:sorted];
    [self addSortedSection:[self sortedCategoryWithSection:self.uncategorisedArticles withName:@"Others"] toArray:sorted];
    
    int numberOfArticlesCategorised = 0;
    for (int i = 0; i < sorted.count; i++) {
        numberOfArticlesCategorised += [[sorted[i] objectForKey:@"articles"] count];
        NSLog(@"Category #%d has #%d articles", i, (int)[[sorted[i] objectForKey:@"articles"] count]);
    }
    NSLog(@"Number of articles categorised: %d", numberOfArticlesCategorised);
    NSLog(@"Number of articles in this issue: %d", (int)[self numberOfArticles]);
    return [[NSArray alloc] initWithArray:sorted];
}

-(NSArray *)sortedArticles
{
    NSMutableArray *sorted = [NSMutableArray array];
    NSArray *_sortedCategories = [self getCategoriesSorted];
    for (int i = 0; i < _sortedCategories.count; i++) {
        [sorted addObjectsFromArray:[_sortedCategories[i] objectForKey:@"articles"]];
    }
    return [[NSArray alloc] initWithArray:sorted];
}

-(NSArray *)articlesInCategory:(NSString *)category
{
    NSMutableArray *articlesInThisCategory = [NSMutableArray array];
    for (int a = 0; a < [self numberOfArticles]; a++) {
        NIAUArticle *articleToAdd = [self articleAtIndex:a];
        if ([articleToAdd containsCategoryWithSubstring:category]) {
            [articlesInThisCategory addObject:articleToAdd];
        }
    }
    return [[NSArray alloc] initWithArray:articlesInThisCategory];
}

-(NSDictionary *)sortedCategoryWithSection:(NSArray *)section withName:(NSString *)name
{
    if (section.count > 0) {
        // Sort sections by publish date
        NSArray *sortedArray;
        sortedArray = [section sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
            NSDate *first = [(NIAUArticle *)a publication];
            NSDate *second = [(NIAUArticle *)b publication];
            return [first compare:second];
        }];
        
        NSMutableDictionary *sectionDictionary = [NSMutableDictionary dictionary];
        [sectionDictionary setObject:sortedArray forKey:@"articles"];
        [sectionDictionary setObject:name forKey:@"name"];
        return [[NSDictionary alloc] initWithDictionary:sectionDictionary];
    } else {
        return nil;
    }
}

-(void)addSortedSection:(NSDictionary *)section toArray:(NSMutableArray *)sorted
{
    if (section) {
        [sorted addObject:section];
    }
}

-(NSInteger)numberOfArticles {
    // might not be set yet...
    if(articles) {
        return [articles count];
    } else {
        return 0;
    }
}

-(NIAUArticle *)articleAtIndex:(NSInteger)index {
    if (articles && [articles count] > 0) {
        return [articles objectAtIndex:index];
    } else {
        return nil;
    }
}

-(NIAUArticle *)articleWithRailsID:(NSNumber *)railsID {
    // Catch out of bounds exception when the article doesn't get found.
    NSUInteger articleIndexPath = [articles indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        //        NSLog(@"Object: %@, railsID: %@",[obj railsID], railsID);
        return ([[obj railsID] isEqualToNumber:railsID]);
    }];
    if (articleIndexPath != NSNotFound) {
        return [articles objectAtIndex:articleIndexPath];
    } else {
        // Can't find that article..
        return nil;
    }
}

// TODO: how would we do getCover w/o completion block?
-(void)getCoverWithCompletionBlock:(void(^)(UIImage *img))block {
    if (requestingCover) {
        NSLog(@"Already requesting cover");
    } else {
        requestingCover = true;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                       ^{
                           UIImage *image = [self getCoverImage];
                           NSLog(@"got cover image %@",image);
                           // run the block on the main queue so it can 	do ui stuff
                           dispatch_async(dispatch_get_main_queue(), ^{
                               block(image);
                           });
                           requestingCover = false;
                       });
    }
}

-(void)getEditorsImageWithCompletionBlock:(void(^)(UIImage *img))block {
    
    NSString *url = [[dictionary objectForKey:@"editors_photo"] objectForKey:@"url"];
    // online location of cover
    NSURL *photoURL = [NSURL URLWithString:url relativeToURL:[NSURL URLWithString:SITE_URL]];
    NSString *coverFileName = [photoURL lastPathComponent];
    // local URL to where the cover is/would be stored
    NSURL *photoCacheURL = [NSURL URLWithString:coverFileName relativeToURL:[self.nkIssue contentURL]];
    NSLog(@"trying to read cached editor's image from %@",photoCacheURL);
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:photoCacheURL]];
    
    if(image) {
        // cache hit
        block(image);
    } else {
        // cache miss, download
        NSLog(@"cache miss, downloading image from %@",photoURL);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                       ^{
                           // download image data
                           NSData *imageData = [NSData dataWithContentsOfCookielessURL:photoURL];
                           // what if imageData is nil? - seems to cope
                           UIImage *image = [UIImage imageWithData:imageData];
                           if(image) {
                               [imageData writeToURL:photoCacheURL atomically:YES];
                               block(image);
                           }
                       });
    }
}

-(void)requestArticles {
    NSLog(@"requestArticles called on %@",self);
    if(requestingArticles) {
        NSLog(@"already requesting articles");
    } else {
        requestingArticles = TRUE;
        // put dispatch magic here
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            
            // read from cache first and issue our first update
            
            articles = [NIAUArticle articlesFromIssue:self];		
            
            if ([articles count]>0) {
                NSLog(@"read #%d articles from issue #%@ cache",(int)[articles count], self.name);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:ArticlesDidUpdateNotification object:self];
                });
//                NSLog(@"cache hit. stoppimg");
            } else {
                NSLog(@"no articles found in cache");
                [self downloadArticles];
            }
            requestingArticles = FALSE;
        });
    }
}

-(void)forceDownloadArticles {
    if(requestingArticles) {
        NSLog(@"already requesting articles");
    } else {
        requestingArticles = TRUE;
        [self downloadArticles];
        requestingArticles = FALSE;
    }
}

- (void)downloadArticles {
    NSURL *issueURL = [NSURL URLWithString:[NSString stringWithFormat:@"issues/%@.json", [self railsID]] relativeToURL:[NSURL URLWithString:SITE_URL]];
    NSData *data = [NSData dataWithContentsOfCookielessURL:issueURL];
    if(data) {
        NSError *error;
        NSDictionary *dict = [NSJSONSerialization
                              JSONObjectWithData:data
                              options:kNilOptions
                              error:&error];
        
        [[dict objectForKey:@"articles"] enumerateObjectsUsingBlock:^(id dict, NSUInteger idx, BOOL *stop) {
            
            // discard the returned objects and re-read cache after adding them (will preserve locally cached but remotely deleted data)
            [NIAUArticle articleWithIssue:self andDictionary:dict];
            
        }];
        articles = [NIAUArticle articlesFromIssue:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:ArticlesDidUpdateNotification object:self];
        });
        
    } else {
        
        // only send failure notification if there is nothing in the cache
        if ([articles count]<1) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:ArticlesFailedUpdateNotification object:self];
            });
        }
        
    }

}

- (NSURL *)getWebURL
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"issues/%@", self.railsID] relativeToURL:[NSURL URLWithString:SITE_URL]];
}

- (void)clearCache
{
    // For each article, delete the body and then the images
    if ([articles count] > 0) {
        for (NIAUArticle *article in articles) {
            [article deleteArticleFromCache];
        }
    } else {
        NSLog(@"ERROR CLEARING ISSUE CACHE: NSArray articles is empty.");
    }
}

@end
