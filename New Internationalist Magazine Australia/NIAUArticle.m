//
//  NIAUArticle.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 27/06/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAUArticle.h"
#import "NIAUIssue.h"
#import "NSData+Cookieless.h"
#import "local.h"
#import "NIAUHelper.h"
//#import "UIImage+Resize.h"


NSString *ArticleDidUpdateNotification = @"ArticleDidUpdate";
NSString *ArticleFailedUpdateNotification = @"ArticleFailedUpdate";
NSString *ImageDidSaveToCacheNotification = @"ImageDidSaveToCache";


@implementation NIAUArticle

// AHA: this makes getters/setters for these readonly properties without exposing them publically
@synthesize issue;

#pragma mark NSCoding

#define kTitleKey       @"Issue"
#define kRatingKey      @"Dictionary"

- (void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:issue forKey:kTitleKey];
    [encoder encodeObject:dictionary forKey:kRatingKey];
}

- (id)initWithCoder:(NSCoder *)decoder {
    NIAUIssue *_issue = [decoder decodeObjectForKey:kTitleKey];
    NSDictionary *_dictionary = [decoder decodeObjectForKey:kRatingKey];
    imageCaches = [[NSMutableDictionary alloc] init];
    return [self initWithIssue:_issue andDictionary:_dictionary];
}

-(void)deleteArticleBodyFromCache
{
    // Delete article body from cache
    NSURL *bodyCacheURL = [self bodyCacheURL];
    if (bodyCacheURL) {
        [[NSFileManager defaultManager] removeItemAtURL:bodyCacheURL error:nil];
    }
}

-(void)deleteImageWithID:(NSString *)imageID
{
    // Delete image from cache
    NSURL *imageCacheURL = [self imageCacheURLForId:imageID];
    if (imageCacheURL) {
        [[NSFileManager defaultManager] removeItemAtURL:imageCacheURL error:nil];
    }
    
    // Delete the thumbs too, which all start with the name imageCacheURL
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[self cacheURL] path] error:nil];
    NSArray *thumbs = [files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self BEGINSWITH[cd] %@", [imageCacheURL lastPathComponent]]];
    for (NSString *thumbURL in thumbs) {
        [[NSFileManager defaultManager] removeItemAtURL:[NSURL URLWithString:thumbURL relativeToURL:[self cacheURL]] error:nil];
    }
}

-(void)deleteArticleFromCache
{
    // Delete article body from cache
    [self deleteArticleBodyFromCache];
    
    // Loop through the images, and remove them.
    if ([self.images count] > 0) {
        // Remove image for ID
        for (NSDictionary *image in self.images) {
            [self deleteImageWithID:[[image objectForKey:@"id"] stringValue]];
        }
    }
}

-(void)clearCache {
    [bodyCache readWithOptions:nil startingAt:@"net" stoppingAt:nil];
    [featuredImageCache readWithOptions:nil startingAt:@"net" stoppingAt:nil];
    // would need to do a read for every set options we have received since starting.
    // a good argument for an explicit clear block
    //[featuredImageThumbCache clear];
    DebugLog(@"Article cache cleared for #%@",self.railsID);
}

-(NSString *)author {
    return [dictionary objectForKey:@"author"];
}

-(NSString *)teaser {
    return [dictionary objectForKey:@"teaser"];
}

-(NSString *)title {
    return [dictionary objectForKey:@"title"];
}

-(NSNumber *)railsID {
    return [dictionary objectForKey:@"id"];
}

-(NSArray *)categories {
    return [dictionary objectForKey:@"categories"];
}

-(NSDate *)publication {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZ"];
    NSDate *date = [dateFormatter dateFromString:[dictionary objectForKey:@"publication"]];
    return date;
}

-(BOOL)isKeynote {
    id value = [dictionary objectForKey:@"keynote"];
    return value != nil;
}

-(NIAUArticle *)previousArticle
{
    // Retrieve from cache
    NSArray *sorted = [self.issue getArticlesSorted];
    NSUInteger articleIndex = [self indexInSortedArticles:sorted];
    if ([sorted count] > 0 && articleIndex > 0) {
        return [sorted objectAtIndex:(articleIndex - 1)];
    } else {
        return nil;
    }
    
}

-(NIAUArticle *)nextArticle
{
    // Retrieve from cache
    NSArray *sorted = [self.issue getArticlesSorted];
    NSUInteger articleIndex = [self indexInSortedArticles:sorted];
    if ([sorted count] > 0 && articleIndex < ([sorted count] -1)) {
        return [sorted objectAtIndex:(articleIndex + 1)];
    } else {
        return nil;
    }
}

-(NSUInteger)indexInSortedArticles:(NSArray *)sortedArticles
{
    // Calculate article index
    __block NSUInteger articleIndex;
    __block NIAUArticle *_article = self;
    [sortedArticles enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([[obj railsID] isEqual:[_article railsID]]) {
            articleIndex = idx;
        }
    }];
    return articleIndex;
}

-(NSString *)attemptToGetExpandedBodyFromDisk {
    NSString *body = [self attemptToGetBodyFromDisk];
    if(!body) {
        return nil;
    }
    
    // Expand the [Cover:xx|options] tags
    NSString *newBody = [self expandCoverTagsInBody:body];
    
    // Expand the [File:xxx|option] tags
    newBody = [self expandImageTagsInBody:newBody];
    
    // Only add the un-embedded images if they aren't hidden and don't have a Media ID from bricolage.
    NSMutableArray *imagesToAdd = [[NSMutableArray alloc] init];
    [self.images enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
        BOOL isHidden = [WITH_DEFAULT([obj objectForKey:@"hidden"], false) boolValue];
        BOOL hasMediaID = [WITH_DEFAULT([obj objectForKey:@"media_id"], false) boolValue];
        if ((isHidden == NO) && (hasMediaID == NO)) {
            [imagesToAdd addObject:obj];
        }
    }];
    
    if ([body isEqualToString:newBody] && [imagesToAdd count] > 0) {
        // No images were found, but there are some attached to this article
        // So adding [File:xxx|full] for now and re-running generateNewBodyFromBody:
        
        NSString *modifiedBody = body;
        
        // Check to see if the modifiedBody is blank from the zip file, add article-body div.
        if ([modifiedBody isEqualToString:@""]) {
            modifiedBody = @"<div class=\"article-body\"></div>";
        }
        
        // Sort the images by their position
        NSSortDescriptor *lowestPositionToHighest = [NSSortDescriptor sortDescriptorWithKey:@"position" ascending:NO];
        imagesToAdd = [NSMutableArray arrayWithArray:[imagesToAdd sortedArrayUsingDescriptors:[NSArray arrayWithObject:lowestPositionToHighest]]];
        
        for (int i = 0; i < [imagesToAdd count]; i++) {
            NSError *error = nil;
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<div class=\"article-body\">" options:NSRegularExpressionCaseInsensitive error:&error];
            modifiedBody = [regex stringByReplacingMatchesInString:modifiedBody options:0 range:NSMakeRange(0, [modifiedBody length]) withTemplate:[NSString stringWithFormat:@"<div class=\"article-body\">[File:%@|full|ns]", [imagesToAdd[i] objectForKey:@"id"]]];
//            NSLog(@"%@", modifiedBody);
        }
        
        // Now we have all the lost images in the modifiedBody, lets expand again.
        newBody = [self expandImageTagsInBody:modifiedBody];
    }
    
    return newBody;
}

- (NSString *)expandImageTagsInBody:(NSString *)body {
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"\\[File:(\\d+)(?:\\|([^\\]]*))?]"
                                  options:NSRegularExpressionCaseInsensitive
                                  error:&error];
    // TODO: we will at least want a list of which ID's we need to cache from the site.
    // Pix: Still need this?
    
    // make a copy of the input string. we are going to edit this one as we iterate
    NSMutableString *newBody = [NSMutableString stringWithString:body];
    
    // keep track of how many additional characters we've added
    __block NSUInteger offset = 0;
    
    // TODO: build cache object for each article image? trigger background download?
    
    [regex enumerateMatchesInString:body options:0 range:NSMakeRange(0, [body length]) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop){
        
        // bored? dry this up.
        NSString *fullMatch = [body substringWithRange:match.range];
        NSString *imageId = @"";
        if ([match numberOfRanges]>1 && [match rangeAtIndex:1].length>0) {
            imageId = [body substringWithRange:[match rangeAtIndex:1]];
        }
        NSArray *options = [NSArray array];
        if ([match numberOfRanges]>2 && [match rangeAtIndex:2].length>0) {
            NSString *optionString = [body substringWithRange:[match rangeAtIndex:2]];
            options = [optionString componentsSeparatedByString:@"|"];
        }
        
        // ported from NI:/app/helpers/article-helper.rb:expand-image-tags
        NSString *cssClass = @"article-image";
        NSString *imageWidth = @"300";
        
        if([options containsObject:@"full"]) {
            cssClass = @"all-article-images article-image-cartoon article-image-full";
            imageWidth = @"945";
        } else if([options containsObject:@"cartoon"]) {
            cssClass = @"all-article-images article-image-cartoon";
            imageWidth = @"600";
        } else if([options containsObject:@"centre"]) {
            cssClass = @"all-article-images article-image-cartoon article-image-centre";
            imageWidth = @"300";
        } else if([options containsObject:@"half"]) {
            cssClass = @"all-article-images article-image-half";
            imageWidth = @"472";
        }
        
        if ([options containsObject:@"ns"]) {
            cssClass = [cssClass stringByAppendingString:@" no-shadow"];
        }
        
        if ([options containsObject:@"left"]) {
            cssClass = [cssClass stringByAppendingString:@" article-image-float-none"];
        }
        
        if ([options containsObject:@"small"]) {
            cssClass = [cssClass stringByAppendingString:@" article-image-small"];
            imageWidth = @"150";
        }
        
        // ruby code from articles_helper
        /*
         if media_url
         tag_method = method(:retina_image_tag)
         image_options = {:alt => "#{strip_tags(image.caption)}", :title => "#{strip_tags(image.caption)}", :size => "#{image_width}x#{image_width * image.height / image.width}"}
         if options.include?("full")
         tag_method = method(:image_tag)
         end
         "<div class='#{css_class}'>"+tag_method.call(media_url, image_options)+caption_div+credit_div+"</div>"
         else
         */
        
        // if imageId is blank, replace the tag with nothing.
        NSString *replacement = @"";
        
        if ([imageId length]>0) {
            // TODO: keep track of article images here
            
            NSArray *images = [self->dictionary objectForKey:@"images"];
            // catch missing!
            
            NSUInteger imageIndex = [images indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                return [[obj objectForKey:@"id"] isEqualToNumber:[NSNumber numberWithInteger:[imageId integerValue]]];
            }];
            
            NSDictionary *imageDictionary = nil;
            
            if (imageIndex != NSNotFound) {
                imageDictionary = [images objectAtIndex:imageIndex];
                CGSize size = [[UIScreen mainScreen] bounds].size;
//                NSLog(@"Screen size: %@", NSStringFromCGSize(size));
                
                NSString *imageSource = [[self imageCacheURLForId:imageId andSize:size] path];
                // Get bigImage source if set.
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"bigImages"]) {
                    imageSource = [[self imageCacheURLForId:imageId] path];
                }
                
                if (self->imageCaches == nil) {
                    self->imageCaches = [[NSMutableDictionary alloc] init];
                }
                
                // make entry in imageCaches dictionary if necessary
                if (![self->imageCaches objectForKey:imageId]) {
                    NIAUCache *imageCache = [self buildImageCacheFromDictionary:imageDictionary forSize:size];
                    [self->imageCaches setObject:imageCache forKey:imageId];
                    
                    // If iPhone is 4S or below, don't do this in the background, not enough RAM to handle the multiple javascript updates.
                    if (IS_IPHONE() && IS_IPHONE4S_OR_LOWER()) {
                        // Do this in real time to avoid memory warning crash.
                        [imageCache readWithOptions:nil];
                    } else {
                        // and fire off a background priority cache read
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                            [imageCache readWithOptions:nil];
                            
                            // Send a notification when the image has been read successfully
                            dispatch_async(dispatch_get_main_queue(), ^{
                                NSDictionary *imageInformation = @{@"image":@[imageId,imageSource]};
                                [[NSNotificationCenter defaultCenter] postNotificationName:ImageDidSaveToCacheNotification object:nil userInfo:imageInformation];
                                DebugLog(@"Sent Image saved notification for ID:%@",imageId);
                            });
                        });
                    }
                }
                
                NSString *credit_div = @"";
                NSString *caption_div = @"";
                NSString *imageCredit = [imageDictionary objectForKey:@"credit"];
                NSString *imageCaption = [imageDictionary objectForKey:@"caption"];
                
                if (imageCredit) {
                    credit_div = [NSString stringWithFormat:@"<div class='new-image-credit'>%@</div>", imageCredit];
                }
                
                if (imageCaption) {
                    caption_div = [NSString stringWithFormat:@"<div class='new-image-caption'>%@</div>",imageCaption];
                }
                
                // Check if we already have the image on disk, and show it if we do.
                if ([[NSFileManager defaultManager] fileExistsAtPath:imageSource]) {
                    // Yay, lets use it.
                } else {
                    imageSource = @"loading_image.png";
                }
                
                //TODO: can we dry up the image URL (it's also defined in the buildImageCache method
                replacement = [NSString stringWithFormat:@"<div class='%@'><a href='%@'><img id='image%@' width='%@' src='%@'/></a>%@%@</div>", cssClass, imageSource, imageId, imageWidth, imageSource, caption_div, credit_div];
            }
        }
        
        // every iteration, the output string is getting longer
        // so we need to adjust the range that we are editing
        NSRange newrange = NSMakeRange(match.range.location+offset, match.range.length);
        [newBody replaceCharactersInRange:newrange withString:replacement];
        
        offset+=[replacement length]-[fullMatch length];
        
    }];
    return newBody;
}

- (NSString *)expandCoverTagsInBody:(NSString *)body {
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"\\[Cover:(\\d+)(?:\\|([^\\]]*))?]"
                                  options:NSRegularExpressionCaseInsensitive
                                  error:&error];
    // TODO: we will at least want a list of which ID's we need to cache from the site.
    // Pix: Still need this?
    
    // make a copy of the input string. we are going to edit this one as we iterate
    NSMutableString *newBody = [NSMutableString stringWithString:body];
    
    // keep track of how many additional characters we've added
    __block NSUInteger offset = 0;
    
    // TODO: build cache object for each article image? trigger background download?
    
    [regex enumerateMatchesInString:body options:0 range:NSMakeRange(0, [body length]) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop){
        
        // bored? dry this up.
        NSString *fullMatch = [body substringWithRange:match.range];
        NSString *issueId = @"";
        if ([match numberOfRanges]>1 && [match rangeAtIndex:1].length>0) {
            issueId = [body substringWithRange:[match rangeAtIndex:1]];
        }
        NSArray *options = [NSArray array];
        if ([match numberOfRanges]>2 && [match rangeAtIndex:2].length>0) {
            NSString *optionString = [body substringWithRange:[match rangeAtIndex:2]];
            options = [optionString componentsSeparatedByString:@"|"];
        }
        
        // ported from NI:/app/helpers/article-helper.rb:expand-image-tags
        NSString *cssClass = @"article-image article-image-small";
        NSString *imageWidth = @"200";
        
        if([options containsObject:@"small"]) {
            cssClass = @"article-image article-image-small";
            imageWidth = @"75";
        }
        
        if ([options containsObject:@"ns"]) {
            cssClass = [cssClass stringByAppendingString:@" no-shadow"];
        }
        
        if ([options containsObject:@"left"]) {
            cssClass = [cssClass stringByAppendingString:@" article-image-float-none"];
        }
        
        // ruby code from articles_helper
        /*
         if media_url
         tag_method = method(:retina_image_tag)
         image_options = {:alt => "#{strip_tags(image.caption)}", :title => "#{strip_tags(image.caption)}", :size => "#{image_width}x#{image_width * image.height / image.width}"}
         if options.include?("full")
         tag_method = method(:image_tag)
         end
         "<div class='#{css_class}'>"+tag_method.call(media_url, image_options)+caption_div+credit_div+"</div>"
         else
         */
        
        // if imageId is blank, replace the tag with nothing.
        NSString *replacement = @"";
        
        if ([issueId length]>0) {
            // Find the issue
            
            NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
            NSNumber *issueIdNSNumber = [numberFormatter numberFromString:issueId];
            
            NIAUIssue *issueForCover = [[NIAUPublisher getInstance] issueWithRailsID:issueIdNSNumber];
            
            NSString *imageSource = [[issueForCover coverCacheURL] path];
            
            // Check if we already have the cover on disk, and show it if we do.
            if ([[NSFileManager defaultManager] fileExistsAtPath:imageSource]) {
                // Yay, lets use it.
            } else {
                // Temporary loading image
                imageSource = @"loading_image.png";
                
                // Download the cover in a background thread
                [issueForCover getCoverWithCompletionBlock:^(UIImage *img) {
                    // Send a notification when the cover has been read successfully
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSDictionary *imageInformation = @{@"image":@[issueId,imageSource]};
                        [[NSNotificationCenter defaultCenter] postNotificationName:ImageDidSaveToCacheNotification object:nil userInfo:imageInformation];
                        DebugLog(@"Sent Cover saved notification for ID:%@",issueId);
                    });
                }];
            }
            
            //TODO: can we dry up the image URL (it's also defined in the buildImageCache method
            replacement = [NSString stringWithFormat:@"<div class='%@'><a href='/issues/%@'><img id='image%@' width='%@' src='%@'/></a></div>", cssClass, issueId, issueId, imageWidth, imageSource];
            
        }
        
        // every iteration, the output string is getting longer
        // so we need to adjust the range that we are editing
        NSRange newrange = NSMakeRange(match.range.location+offset, match.range.length);
        [newBody replaceCharactersInRange:newrange withString:replacement];
        
        offset+=[replacement length]-[fullMatch length];
        
    }];
    return newBody;
}

-(NSMutableDictionary *)buildImageCachesDictionary {
    for (NSDictionary *image in [self images]) {
        CGSize size = [NIAUHelper screenSize];
        NIAUCache *imageCache = [self buildImageCacheFromDictionary:image forSize:size];
        [imageCaches setObject:imageCache forKey:(NSString *)[image objectForKey:@"id"]];
    }
    return imageCaches;
}

-(NIAUCache *)buildFeaturedImageCache {
    __weak NIAUArticle *weakSelf = self;
    NIAUCache *cache = [[NIAUCache alloc] init];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"memory" withReadBlock:^id(id options, id state) {
        return state[@"featuredImage"];
    } andWriteBlock:^(id object, id options, id state) {
        state[@"featuredImage"] = object;
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"disk" withReadBlock:^id(id options, id state) {
        NSData *imageData = [NSData dataWithContentsOfURL:[weakSelf featuredImageCacheURL]];
        return [UIImage imageWithData:imageData];
    } andWriteBlock:^(id object, id options, id state) {
        // Using original file type instead of PNG to save memory.
//        [UIImagePNGRepresentation(object) writeToURL:[weakSelf featuredImageCacheURL] atomically:YES];
        if ([[[[weakSelf featuredImageCacheURL] lastPathComponent] pathExtension] isEqualToString:@"jpg"]) {
            [UIImageJPEGRepresentation(object,0.9) writeToURL:[weakSelf featuredImageCacheURL] atomically:YES];
        } else {
            [UIImagePNGRepresentation(object) writeToURL:[weakSelf featuredImageCacheURL] atomically:YES];
        }
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"net" withReadBlock:^id(id options, id state) {
        NSData *imageData = [NSData dataWithContentsOfCookielessURL:[weakSelf featuredImageURL]];
        return [UIImage imageWithData:imageData];
    } andWriteBlock:^(id object, id options, id state) {
        // noop
    }]];
    return cache;
}

-(NSURL *)imageURLForId:(NSString *)imageId
{
    // Loop through images to get image with imageId, then get its url.
    __block NSString *url;
    [[self images] enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL *stop) {
        if ([[[object objectForKey:@"id"] stringValue] isEqualToString:imageId]) {
            url = [[object objectForKey:@"data"] objectForKey:@"url"];
        }
    }];
    if ((url != (id)[NSNull null]) && url) {
        return [NSURL URLWithString:url relativeToURL:[NSURL URLWithString:SITE_URL]];
    } else {
        //        return [[NSBundle mainBundle] URLForResource:@"default_article_image_table_view" withExtension:@"png"];
        return nil;
    }
}

-(NSURL *)imageCacheURLForId:(NSString *)imageId {
    // Check to see if imageId and imageURL are around.
    NSURL *imageURL = [self imageURLForId:imageId];
    if (imageId && imageURL) {
        NSString *imageFileName = [imageURL lastPathComponent];
        return [NSURL URLWithString:imageFileName relativeToURL:[self cacheURL]];
    } else {
        return nil;
    }
}

-(NSURL *)imageCacheURLForId:(NSString *)imageId andSize:(CGSize)size {
    // Check to see if imageId and imageURL are around.
    NSURL *imageURL = [self imageURLForId:imageId];
    if (imageId && imageURL) {
        NSString *imageName = [imageURL lastPathComponent];
        NSString *imageFileName = [imageName stringByAppendingString:[NSString stringWithFormat:@"_%f.%@", size.width, [imageName pathExtension]]];
        return [NSURL URLWithString:imageFileName relativeToURL:[self cacheURL]];
    } else {
        return nil;
    }
}

-(NSDictionary *)firstImage
{
    // Select the image by first position
    if ([self.images count] > 0) {
        NSArray *sortedImagesByPosition;
        sortedImagesByPosition = [self.images sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
            NSString *first = [(NSDictionary *)a objectForKey:@"position"];
            NSString *second = [(NSDictionary *)b objectForKey:@"position"];
            if (first != (id)[NSNull null] && second != (id)[NSNull null]) {
                // Try sorting by position
                return [first compare:second];
            } else {
                // If position is NULL, sort by id
                first = [(NSDictionary *)a objectForKey:@"id"];
                second = [(NSDictionary *)b objectForKey:@"id"];
                return [first compare:second];
            }
        }];
        return [sortedImagesByPosition objectAtIndex:0];
    } else {
        return nil;
    }
}

-(NIAUCache *)buildImageCacheFromDictionary:(NSDictionary *)imageDictionary forSize:(CGSize)size {
    __weak NIAUArticle *weakSelf = self;
    NIAUCache *cache = [[NIAUCache alloc] init];
    NSString *imageId = [[imageDictionary objectForKey:@"id"] stringValue];
    NSURL *imageCacheURL = [weakSelf imageCacheURLForId:imageId andSize:size];
    NSString *imageStateName = [NSString stringWithFormat:@"%@",imageId];
    NSString *imageStateNameSize = [NSString stringWithFormat:@"%@_size",imageStateName];
    
    // Build big images if requested
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"bigImages"]) {
        imageCacheURL = [weakSelf imageCacheURLForId:imageId];
    }
    
    NSURL *zipImageCacheURL = [[imageCacheURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:[[[imageDictionary objectForKey:@"data"] objectForKey:@"url"] lastPathComponent]];
    
    // search our dictionary for the image data
    NSURL *imageNetURL;
    
    // If the image has been saved to our filesystem via a zip download from the net, change the imageNetURL to local.
    // TODO: Probably should write another cache method ZIP? What do you think Pix?
    if ([[NSFileManager defaultManager] fileExistsAtPath:[zipImageCacheURL path]]) {
        // Image needs to be made into a PNG and stored to disk cache so send local URL
        imageNetURL = zipImageCacheURL;
    } else {
        // Normal NetURL
        imageNetURL = [NSURL URLWithString:[[imageDictionary objectForKey:@"data"] objectForKey:@"url"]];
    }
    
    __block NSURL *_imageCacheURL = imageCacheURL;
    
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"memory" withReadBlock:^id(id options, id state) {
        id entry = state[imageStateNameSize];
        if(!entry) return nil;
        CGSize cachedSize = [(NSValue *)[entry objectForKey:@"size"] CGSizeValue];
        CGSize optionsSize = [(NSValue *)options[@"size"] CGSizeValue];
        CGSize requestedSize = CGSizeMake(0, 0);
        if (optionsSize.width > 0) {
            if (optionsSize.width > size.width) {
                requestedSize = size;
            } else {
                requestedSize = optionsSize;
            }
        } else {
            requestedSize = size;
        }
        
        if(CGSizeEqualToSize(cachedSize,requestedSize)) {
            return state[imageStateName];
        } else {
            return nil;
        }
    } andWriteBlock:^(id object, id options, id state) {
        CGSize optionsSize = [(NSValue *)options[@"size"] CGSizeValue];
        CGSize sizeToWrite;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"bigImages"]) {
            if (optionsSize.width > 0) {
                sizeToWrite = optionsSize;
            } else {
                sizeToWrite = [object size];
            }
        } else {
            if (optionsSize.width > 0) {
                sizeToWrite = optionsSize;
            } else {
                sizeToWrite = size;
            }
        }
        state[imageStateNameSize]=@{@"size":[NSValue valueWithCGSize:sizeToWrite]};
        state[imageStateName]=object;
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"disk" withReadBlock:^id(id options, id state) {
        
        CGSize optionsSize = [(NSValue *)options[@"size"] CGSizeValue];
        if (optionsSize.width > 0) {
            
            if (optionsSize.width > size.width) {
                // Use size calculated above
            } else {
                // Use size from options
                // Use the size in options.
                _imageCacheURL = [weakSelf imageCacheURLForId:imageId andSize:optionsSize];
            }

        } else {
            // No options size, so use current imageCacheURL
        }
        NSData *data = [NSData dataWithContentsOfURL:_imageCacheURL];
        UIImage *image = [UIImage imageWithData:data scale:[[UIScreen mainScreen] scale]];
        
        if(image) {
            return image;
        } else {
            return nil;
        }
        
    } andWriteBlock:^(id object, id options, id state) {
        // Using original file type instead of PNG to save memory.
//        [UIImagePNGRepresentation(object) writeToURL:imageCacheURL atomically:YES];
        
        CGSize optionsSize = [(NSValue *)options[@"size"] CGSizeValue];
        if (optionsSize.width > 0) {
            
            if (optionsSize.width > size.width) {
                // Use size calculated above
            } else {
                // Use size from options
                // Use the size in options.
                _imageCacheURL = [weakSelf imageCacheURLForId:imageId andSize:optionsSize];
            }
            
        } else {
            // No options size, so use current imageCacheURL
        }
        
        if ([[[_imageCacheURL lastPathComponent] pathExtension] isEqualToString:@"jpg"]) {
            [UIImageJPEGRepresentation(object,0.9) writeToURL:_imageCacheURL atomically:YES];
        } else {
            [UIImagePNGRepresentation(object) writeToURL:_imageCacheURL atomically:YES];
        }
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"generate" withReadBlock:^id(id options, id state) {
        // Get full sized image from disk
        NSData *data = [NSData dataWithContentsOfURL:[weakSelf imageCacheURLForId:imageId]];
        UIImage *image = [UIImage imageWithData:data scale:[[UIScreen mainScreen] scale]];
        // return screen size images
        CGSize optionsSize = [(NSValue *)options[@"size"] CGSizeValue];
        CGSize sizeToFit;
        if (optionsSize.width > 0) {
            
            if (optionsSize.width > size.width) {
                // Use size calculated above
                sizeToFit = size;
            } else {
                // Use size from options
                // Use the size in options.
                sizeToFit = optionsSize;
            }
            
        } else {
            // No options size, so use current imageCacheURL
            sizeToFit = size;
        }
        // User defaults for big images or not. (helps speed up response on older iPhones)
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"bigImages"]) {
            if (optionsSize.width > 0) {
                return [weakSelf scaleImage:image toSize:sizeToFit];
            } else {
                return image;
            }
        } else {
            if (optionsSize.width > 0) {
                return [weakSelf scaleImage:image toSize:sizeToFit];
            } else {
                return [weakSelf scaleImage:image toFitWidth:sizeToFit];
            }
        }
    } andWriteBlock:^(id object, id options, id state) {
        // noop
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"net" withReadBlock:^id(id options, id state) {
        NSData *imageData = [NSData dataWithContentsOfCookielessURL:imageNetURL];
        // return screen size images
        CGSize optionsSize = [(NSValue *)options[@"size"] CGSizeValue];
        CGSize sizeToFit;
        if (optionsSize.width > 0) {
            
            if (optionsSize.width > size.width) {
                // Use size calculated above
                sizeToFit = size;
            } else {
                // Use size from options
                // Use the size in options.
                sizeToFit = optionsSize;
            }
            
        } else {
            // No options size, so use current imageCacheURL
            sizeToFit = size;
        }
        // User defaults for big images or not. (helps speed up response on older iPhones)
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"bigImages"]) {
            if (optionsSize.width > 0) {
                return [weakSelf scaleImage:[UIImage imageWithData:imageData] toSize:sizeToFit];
            } else {
                return [UIImage imageWithData:imageData];
            }
        } else {
            if (optionsSize.width > 0) {
                return [weakSelf scaleImage:[UIImage imageWithData:imageData] toSize:sizeToFit];
            } else {
                return [weakSelf scaleImage:[UIImage imageWithData:imageData] toFitWidth:sizeToFit];
            }
        }
    } andWriteBlock:^(id object, id options, id state) {
        // noop
    }]];
    return cache;
}

-(NIAUCache *)buildFeaturedImageThumbCache {
    __weak NIAUArticle *weakSelf = self;
    NIAUCache *cache = [[NIAUCache alloc] init];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"memory" withReadBlock:^id(id options, id state) {
        id entry = state[@"size"];
        if(!entry) return nil;
        CGSize cachedSize = [(NSValue *)entry CGSizeValue];
        CGSize size = [(NSValue *)options[@"size"] CGSizeValue];
        if(CGSizeEqualToSize(cachedSize,size)) {
            return state[@"thumb"];
        } else {
            return nil;
        }
    } andWriteBlock:^(id object, id options, id state) {
        state[@"size"]=options[@"size"];
        state[@"thumb"]=object;
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"disk" withReadBlock:^id(id options, id state) {
        CGSize size = [(NSValue *)options[@"size"] CGSizeValue];
        UIImage *image = [weakSelf getFeaturedImageThumbFromDisk];
        if(image && CGSizeEqualToSize([image size], size)) {
            return image;
        } else {
            return nil;
        }
    } andWriteBlock:^(id object, id options, id state) {
        // writeFeaturedImageThumbToDisk
//        [UIImagePNGRepresentation(object) writeToURL:[weakSelf featuredImageThumbCacheURL] atomically:YES];
        if ([[[[weakSelf featuredImageThumbCacheURL] lastPathComponent] pathExtension] isEqualToString:@"jpg"]) {
            [UIImageJPEGRepresentation(object,0.9) writeToURL:[weakSelf featuredImageThumbCacheURL] atomically:YES];
        } else {
            [UIImagePNGRepresentation(object) writeToURL:[weakSelf featuredImageThumbCacheURL] atomically:YES];
        }
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"generate" withReadBlock:^id(id options, id state) {
        CGSize size = [(NSValue *)options[@"size"] CGSizeValue];
        return [weakSelf scaleImage:[self getFeaturedImage] toSize:size];
    } andWriteBlock:^(id object, id options, id state) {
        // no op
    }]];
    return cache;
}

-(NIAUCache *)buildBodyCache {
    __weak NIAUArticle *weakSelf = self;
    NIAUCache *cache = [[NIAUCache alloc] init];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"memory" withReadBlock:^id(id options, id state) {
        return state[@"body"];
    } andWriteBlock:^(id object, id options, id state) {
        state[@"body"] = object;
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"disk" withReadBlock:^id(id options, id state) {
        return [NSString stringWithContentsOfURL:[weakSelf bodyCacheURL] encoding:NSUTF8StringEncoding error:nil];
    } andWriteBlock:^(id object, id options, id state) {
        if (object) {
            [(NSString*)object writeToURL:[self bodyCacheURL] atomically:FALSE encoding:NSUTF8StringEncoding error:nil];
        } else {
            [[NSFileManager defaultManager] removeItemAtURL:[self bodyCacheURL] error:nil];
        }
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"net" withReadBlock:^id(id options, id state) {
        NSData *data = [self downloadArticleBodyWithIssueRailsID: [[weakSelf issue] railsID] andArticleRailsID: [weakSelf railsID]];
        if(data)
            return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//            return [self expandImageReferencesInString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
        else return nil;
    } andWriteBlock:^(id object, id options, id state) {
        // no op
    }]];
    return cache;
}

- (NSData *)downloadArticleBodyWithIssueRailsID: (NSNumber *)issueIndex andArticleRailsID: (NSNumber *)articleIndex
{
    // POSTs the receipt to Rails, and then onto iTunes to check for a valid purchase
    // If there's a valid purchase, it returns the article body
    
    NSURL *articleURL = [NSURL URLWithString:[NSString stringWithFormat:@"issues/%@/articles/%@/body", issueIndex, articleIndex] relativeToURL:[NSURL URLWithString:SITE_URL]];

    NSData *receiptData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    
    NSString *base64receipt = [receiptData base64EncodedStringWithOptions:0];
    NSData *postData = [base64receipt dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%d", (int)[postData length]];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:articleURL];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];

    NSError *error;
    NSHTTPURLResponse *response;
    
//    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:SITE_URL]];
    
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    int statusCode = (int)[response statusCode];
    NSString *data = [[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding];
    if (!error && statusCode >= 200 && statusCode < 300) {
//        DebugLog(@"Response from Rails: %@", data);
    } else {
        NSLog(@"Rails returned statusCode: %d\n an error: %@\nAnd data: %@", statusCode, error, data);
        responseData = nil;
        
        // If status == 403, user doesn't have an account, else probably a server error.
        if (statusCode == 403) {
            self.isRailsServerReachable = TRUE;
        } else {
            self.isRailsServerReachable = FALSE;
        }
    }
    
    return responseData;
}

-(NIAUArticle *)initWithIssue:(NIAUIssue *)_issue andDictionary:(NSDictionary *)_dictionary {
    self = [super init];
    if(self) {
        issue = _issue;
        dictionary = _dictionary;
        
        featuredImageCache = [self buildFeaturedImageCache];
        featuredImageThumbCache = [self buildFeaturedImageThumbCache];
        NSDictionary *firstImageDictionary = self.firstImage;
        if ([firstImageDictionary count] > 0) {
            firstImageCache = [self buildImageCacheFromDictionary:firstImageDictionary forSize:[NIAUHelper screenSize]];
        }
        // Note: Use this call if we want to pre-build image caches for articles.
        // Not in a thread yet though I don't think... (or is it)
        // Might get called for each article at table of contents stage though..
//        imageCaches = [self buildImageCachesDictionary];
        bodyCache = [self buildBodyCache];
    }
    
    return self;
}

+(NIAUArticle *)articleWithIssue:(NIAUIssue *)_issue andDictionary:(NSDictionary *)_dictionary {
    
    NIAUArticle *article = [[NIAUArticle alloc] initWithIssue:_issue andDictionary: _dictionary];

    //Q: shouldn't this be in initWithIssue?
    [article writeToCache];

    return article;
}


// Q: is providing all of these class methods evil?
// alternate solution could be to create a skeleton issue then call -bodyURL
+(NSURL *) cacheURLWithIssue:(NIAUIssue *)issue andId:(NSNumber *)index {
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/", index] relativeToURL:issue.contentURL];
}

-(NSURL *) cacheURL {
    return [NIAUArticle cacheURLWithIssue:[self issue] andId:[self railsID]];
}

+(NSURL *) metadataURLWithIssue:(NIAUIssue *)issue andId:(NSNumber *)index {
    return [NSURL URLWithString:@"article.json" relativeToURL:[NIAUArticle cacheURLWithIssue:issue andId:index]];
}

-(NSURL *) metadataURL {
    return [NIAUArticle metadataURLWithIssue:[self issue] andId:[self railsID]];
}

-(NSURL *) bodyCacheURL {
    return [NSURL URLWithString:@"body.html" relativeToURL:[self cacheURL]];
}

//TODO: call this once for each article in the issue metadata
+(NIAUArticle *)articleFromCacheWithIssue:(NIAUIssue *)_issue andId:(NSNumber *)_id {
   
    NSData *data = [NSData dataWithContentsOfURL:[self metadataURLWithIssue:_issue andId:_id]];
    NSError *error;
    if (data) {
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        
        // call the init directly to avoid saving back to cache
        return [[NIAUArticle alloc] initWithIssue:_issue andDictionary: dictionary];
    } else {
        // No metadata for article
        NSLog(@"ERROR: No metadata for article id: %d",[_id intValue]);
        return nil;
    }
}

+(NSArray *)articlesFromIssue:(NIAUIssue *)_issue {
    NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
    NSMutableArray *articles = [NSMutableArray array];
    NSArray *keys = @[NSURLIsDirectoryKey,NSURLNameKey];
    NSError *error;
    for (NSURL *url in [[NSFileManager defaultManager] contentsOfDirectoryAtURL:_issue.contentURL includingPropertiesForKeys:keys options:0 error:&error]) {
        NSDictionary *properties = [url resourceValuesForKeys:keys error:&error];
        if ([[properties objectForKey:NSURLIsDirectoryKey] boolValue]==YES) {
            NIAUArticle *articleToAdd = [self articleFromCacheWithIssue:_issue andId:[nf numberFromString:[properties objectForKey:NSURLNameKey]]];
            if (articleToAdd) {
                [articles addObject:articleToAdd];
            }
        }
    }
    return articles;
}

-(NSArray *)images
{
    return [dictionary objectForKey:@"images"];
}

-(void)writeToCache {
//    NSLog(@"TODO: %s", __PRETTY_FUNCTION__);
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtURL:[self cacheURL] withIntermediateDirectories:TRUE attributes:nil error:&error]) {
        
//        NSLog(@"writing article to cache: %@",[[self metadataURL] absoluteString]);
        
        NSOutputStream *os = [NSOutputStream outputStreamWithURL:[self metadataURL] append:FALSE];
        
        [os open];
        NSError *error;
        if ([NSJSONSerialization writeJSONObject:dictionary toStream:os options:0 error:&error]<=0) {
            NSLog(@"Error writing JSON file");
        }
        [os close];
        
    } else {
        NSLog(@"error creating cache dir: %@",error);
    }
}

-(NSURL *)featuredImageThumbCacheURL {
    NSString *featuredImageBaseName = [[[self featuredImageURL] lastPathComponent] stringByDeletingPathExtension];
    return [NSURL URLWithString:[featuredImageBaseName stringByAppendingPathExtension:[NSString stringWithFormat:@"_thumb.%@", [[[self featuredImageURL] lastPathComponent] pathExtension]]] relativeToURL:[self cacheURL]];
}

-(UIImage *)getFeaturedImageThumbFromDisk {
    NSData *thumbData = [NSData dataWithContentsOfURL:[self featuredImageThumbCacheURL]];
    return [UIImage imageWithData:thumbData scale:[[UIScreen mainScreen] scale]];
}

-(UIImage *)scaleImage:(UIImage *)image toSize:(CGSize)thumbSize {
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

-(UIImage *)scaleImage:(UIImage *)image toFitWidth:(CGSize)thumbSize {
    // don't make blank thumbnails ;)
    if(!image) return nil;
    
    float imageAspect = [image size].width/[image size].height;
    CGSize scaledSize = CGSizeMake(thumbSize.width, thumbSize.width/imageAspect);
    
    UIGraphicsBeginImageContextWithOptions(scaledSize, NO, 0.0);
    CGRect drawRect = CGRectMake(0, 0, scaledSize.width, scaledSize.height);
    [image drawInRect:drawRect];
    UIImage *thumb = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return thumb;
}

-(void)getFeaturedImageThumbWithSize:(CGSize)size andCompletionBlock:(void (^)(UIImage *))block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                   ^{
                       UIImage *thumb = [self getFeaturedImageThumbWithSize:size];
                       // run the block on the main queue so it can do ui stuff
                       dispatch_async(dispatch_get_main_queue(), ^{
                           block(thumb);
                       });
                   });
}

-(UIImage *)getFeaturedImageThumbWithSize:(CGSize)size {
    return [featuredImageThumbCache readWithOptions:@{@"size":[NSValue valueWithCGSize:size]}];
}

-(UIImage *)attemptToGetFeaturedImageThumbFromDiskWithSize:(CGSize)size {
    return [featuredImageThumbCache readWithOptions:@{@"size":[NSValue valueWithCGSize:size]} stoppingAt:@"generate"];
}


-(void)getFeaturedImageWithCompletionBlock:(void(^)(UIImage *img)) block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                   ^{
                       UIImage *image = [self getFeaturedImage];
                       // run the block on the main queue so it can 	do ui stuff
                       dispatch_async(dispatch_get_main_queue(), ^{
                           block(image);
                       });

                   });
}

-(NSURL *) featuredImageURL {
    NSString *url = [[dictionary objectForKey:@"featured_image"] objectForKey:@"url"];
    if ((url != (id)[NSNull null]) && url) {
        return [NSURL URLWithString:url relativeToURL:[NSURL URLWithString:SITE_URL]];
    } else {
//        return [[NSBundle mainBundle] URLForResource:@"default_article_image_table_view" withExtension:@"png"];
        return nil;
    }
}

-(NSURL *) featuredImageCacheURL {
    NSString *featuredImageFileName = [[self featuredImageURL]lastPathComponent];
    return [NSURL URLWithString:featuredImageFileName relativeToURL:[self cacheURL]];
}

-(UIImage *)getFeaturedImage {
    return [featuredImageCache readWithOptions:nil];
}

-(UIImage *)getImageWithID:(NSString *)imageID {
    return [[imageCaches objectForKey:imageID] readWithOptions:nil];
}

-(UIImage *)getImageWithID:(NSString *)imageID andSize:(CGSize)size {
    return [[imageCaches objectForKey:imageID] readWithOptions:@{@"size":[NSValue valueWithCGSize:size]}];
}

-(UIImage *)getFirstImageWithID:(NSString *)imageID andSize:(CGSize)size {
    return [firstImageCache readWithOptions:@{@"size":[NSValue valueWithCGSize:size]} stoppingAt:@"net"];
}

-(void)getFirstImageWithID:(NSString *)imageID andSize:(CGSize)size withCompletionBlock:(void(^)(UIImage *img)) block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                   ^{
                       UIImage *image = [self getFirstImageWithID:imageID andSize:size];
                       // run the block on the main queue so it can do ui stuff
                       dispatch_async(dispatch_get_main_queue(), ^{
                           block(image);
                       });
                       
                   });
}

-(NSString *)attemptToGetBodyFromDisk {
    NSString *body = [bodyCache readWithOptions:nil stoppingAt:@"net"];
    return body;
}

-(void)requestBody {
    if(!self.requestingBody) {
        self.requestingBody = TRUE;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            
            id body = [self->bodyCache readWithOptions:nil];
//            NSLog(@"requestBody. body==%@",body);

            if(body) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:ArticleDidUpdateNotification object:self];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:ArticleFailedUpdateNotification object:self];
                });
            }
            self.requestingBody = FALSE;
        });
    }
}

- (NSURL *)getWebURL
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"issues/%@/articles/%@",self.issue.railsID, self.railsID] relativeToURL:[NSURL URLWithString:SITE_URL]];
}

- (NSURL *)getGuestPassURL
{
    // If the user has a rails account or has purchased this issue, they can create a guest pass and share it.
    
    // Check/create a guest pass
    
    NSURL *articleURL = [NSURL URLWithString:[NSString stringWithFormat:@"issues/%@/articles/%@/ios_share.json",self.issue.railsID, self.railsID] relativeToURL:[NSURL URLWithString:SITE_URL]];
    
    NSData *receiptData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    
    NSString *base64receipt = [receiptData base64EncodedStringWithOptions:0];
    NSData *postData = [base64receipt dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%d", (int)[postData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:articleURL];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    
    NSError *error;
    NSHTTPURLResponse *response;
    NSMutableDictionary *tmpGuestPassJsonData = [[NSMutableDictionary alloc] init];
    
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    int statusCode = (int)[response statusCode];
    NSString *data = [[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding];
    
    if (!error && statusCode >= 200 && statusCode < 300) {
        // If there aren't any errors, they have a subscription or have purchased this issue, so return the guest pass url.
        DebugLog(@"Guest Pass: %@", data);
        tmpGuestPassJsonData = [NSJSONSerialization JSONObjectWithData:responseData options:kNilOptions error:&error];
        
        return [NSURL URLWithString:[NSString stringWithFormat:@"issues/%@/articles/%@?utm_source=%@",self.issue.railsID, self.railsID, [tmpGuestPassJsonData objectForKey:@"key"]] relativeToURL:[NSURL URLWithString:SITE_URL]];
    } else {
        // Else, they don't have permission to create a guest pass. Just return the article url.
        NSLog(@"Rails returned statusCode: %d\n an error: %@\nAnd data: %@", statusCode, error, data);
        responseData = nil;
        
        return [NSURL URLWithString:[NSString stringWithFormat:@"issues/%@/articles/%@",self.issue.railsID, self.railsID] relativeToURL:[NSURL URLWithString:SITE_URL]];
    }
}

- (BOOL)containsCategoryWithSubstring:(NSString *)substring
{
    return (NSNotFound != [self.categories indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        NSUInteger returnThing = [[obj objectForKey:@"name"] rangeOfString:substring].location;
        if (NSNotFound != returnThing) {
            *stop = YES;
            return returnThing;
        } else {
            return NO;
        }
    }]);
}

@end
