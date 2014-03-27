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
//#import "UIImage+Resize.h"


NSString *ArticleDidUpdateNotification = @"ArticleDidUpdate";
NSString *ArticleFailedUpdateNotification = @"ArticleFailedUpdate";
NSString *ImageDidSaveToCacheNotification = @"ImageDidSaveToCache";


@implementation NIAUArticle

// AHA: this makes getters/setters for these readonly properties without exposing them publically
@synthesize issue;

-(void)deleteArticleFromCache
{
    [[NSFileManager defaultManager] removeItemAtURL:[self bodyCacheURL] error:nil];
}

-(void)clearCache {
    [bodyCache readWithOptions:nil startingAt:@"net" stoppingAt:nil];
    [featuredImageCache readWithOptions:nil startingAt:@"net" stoppingAt:nil];
    // would need to do a read for every set options we have received since starting.
    // a good argument for an explicit clear block
    //[featuredImageThumbCache clear];
    NSLog(@"Article cache cleared for #%@",self.railsID);
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

-(NSString *)attemptToGetExpandedBodyFromDisk {
    NSString *body = [self attemptToGetBodyFromDisk];
    if(!body) {
        return nil;
    }
    
    // Expand the [File:xxx|option] tags
    NSString *newBody = [self expandImageTagsInBody:body];
    
    if ([body isEqualToString:newBody] && [[dictionary objectForKey:@"images"] count] > 0) {
        // No images were found, but there are some attached to this article
        // So adding [File:xxx|full] for now and re-running generateNewBodyFromBody:
        
        NSString *modifiedBody = body;
        NSMutableArray *imagesToAdd = [dictionary objectForKey:@"images"];
        
        // Sort the images by their position
        NSSortDescriptor *lowestPositionToHighest = [NSSortDescriptor sortDescriptorWithKey:@"position" ascending:NO];
        imagesToAdd = [NSMutableArray arrayWithArray:[imagesToAdd sortedArrayUsingDescriptors:[NSArray arrayWithObject:lowestPositionToHighest]]];
        
        for (int i = 0; i < [imagesToAdd count]; i++) {
            NSError *error = nil;
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<div class=\"article-body\">" options:NSRegularExpressionCaseInsensitive error:&error];
            modifiedBody = [regex stringByReplacingMatchesInString:modifiedBody options:0 range:NSMakeRange(0, [body length]) withTemplate:[NSString stringWithFormat:@"<div class=\"article-body\">[File:%@|full|ns]", [imagesToAdd[i] objectForKey:@"id"]]];
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
        } else if([options containsObject:@"small"]) {
            cssClass = @"article-image article-image-small";
            imageWidth = @"150";
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
        
        if ([imageId length]>0) {
            // TODO: keep track of article images here
            
            NSArray *images = [dictionary objectForKey:@"images"];
            // catch missing!
            
            NSUInteger imageIndex = [images indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                return [[obj objectForKey:@"id"] isEqualToNumber:[NSNumber numberWithInteger:[imageId integerValue]]];
            }];
            
            NSDictionary *imageDictionary = nil;
            
            if (imageIndex != NSNotFound) {
                imageDictionary = [images objectAtIndex:imageIndex];
                
                // make entry in imageCaches dictionary if necessary
                if (![imageCaches objectForKey:imageId]) {
                    NIAUCache *imageCache = [self buildImageCacheFromDictionary:imageDictionary];
                    [imageCaches setObject:imageCache forKey:imageId];
                    
                    // and fire off a background priority cache read
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                        [imageCache readWithOptions:nil];
                        
                        // Send a notification when the image has been read successfully
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSArray *imageInformation = @[imageId,[[self imageCacheURLForId:imageId] absoluteString]];
                            [[NSNotificationCenter defaultCenter] postNotificationName:ImageDidSaveToCacheNotification object:imageInformation];
                            NSLog(@"Sent Image saved notification for ID:%@",imageId);
                        });
                    });
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
                NSString *imageSource = @"";
                if ([[NSFileManager defaultManager] fileExistsAtPath:[[self imageCacheURLForId:imageId] absoluteString]]) {
                    imageSource = [[self imageCacheURLForId:imageId] absoluteString];
                } else {
                    imageSource = @"loading_image.png";
                }
                
                //TODO: can we dry up the image URL (it's also defined in the buildImageCache method
                replacement = [NSString stringWithFormat:@"<div class='%@'><a href='%@'><img id='image%@' width='%@' src='%@'/></a>%@%@</div>", cssClass, [[self imageCacheURLForId:imageId] absoluteString], imageId, imageWidth, imageSource, caption_div, credit_div];
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
        [UIImagePNGRepresentation(object) writeToURL:[weakSelf featuredImageCacheURL] atomically:YES];
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"net" withReadBlock:^id(id options, id state) {
        NSData *imageData = [NSData dataWithContentsOfCookielessURL:[weakSelf featuredImageURL]];
        return [UIImage imageWithData:imageData];
    } andWriteBlock:^(id object, id options, id state) {
        // noop
    }]];
    return cache;
}

-(NSURL *)imageCacheURLForId:(NSString *)imageId {
    return [NSURL URLWithString:[imageId stringByAppendingPathExtension:@"png"] relativeToURL:[self cacheURL]];
}

-(NSDictionary *)firstImage
{
    // Select the image by first position
    NSArray *sortedImagesByPosition;
    sortedImagesByPosition = [self.images sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *first = [(NSDictionary *)a objectForKey:@"position"];
        NSString *second = [(NSDictionary *)b objectForKey:@"position"];
        return [first compare:second];
    }];
    return [sortedImagesByPosition objectAtIndex:0];
}

-(NIAUCache *)buildImageCacheFromDictionary:(NSDictionary*)imageDictionary {
    NIAUCache *cache = [[NIAUCache alloc] init];
    NSString *imageId = [[imageDictionary objectForKey:@"id"] stringValue];
    NSURL *imageCacheURL = [self imageCacheURLForId:imageId];
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
    
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"memory" withReadBlock:^id(id options, id state) {
        return state[@"image"];
    } andWriteBlock:^(id object, id options, id state) {
        state[@"image"] = object;
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"disk" withReadBlock:^id(id options, id state) {
        NSData *imageData = [NSData dataWithContentsOfURL:imageCacheURL];
        return [UIImage imageWithData:imageData];
    } andWriteBlock:^(id object, id options, id state) {
        [UIImagePNGRepresentation(object) writeToURL:imageCacheURL atomically:YES];
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"net" withReadBlock:^id(id options, id state) {
        NSData *imageData = [NSData dataWithContentsOfCookielessURL:imageNetURL];
        return [UIImage imageWithData:imageData];
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
        [UIImagePNGRepresentation(object) writeToURL:[weakSelf featuredImageThumbCacheURL] atomically:YES];
    }]];
    [cache addMethod:[[NIAUCacheMethod alloc] initMethod:@"generate" withReadBlock:^id(id options, id state) {
        CGSize size = [(NSValue *)options[@"size"] CGSizeValue];
        return [weakSelf generateFeaturedImageThumbWithSize:size];
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
//        NSLog(@"Response from Rails: %@", data);
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
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/", index] relativeToURL:issue.nkIssue.contentURL];
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
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];

    // call the init directly to avoid saving back to cache
    return [[NIAUArticle alloc] initWithIssue:_issue andDictionary: dictionary];

}

+(NSArray *)articlesFromIssue:(NIAUIssue *)_issue {
    NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
    NSMutableArray *articles = [NSMutableArray array];
    NSArray *keys = @[NSURLIsDirectoryKey,NSURLNameKey];
    NSError *error;
    for (NSURL *url in [[NSFileManager defaultManager] contentsOfDirectoryAtURL:_issue.nkIssue.contentURL includingPropertiesForKeys:keys options:0 error:&error]) {
        NSDictionary *properties = [url resourceValuesForKeys:keys error:&error];
        if ([[properties objectForKey:NSURLIsDirectoryKey] boolValue]==YES) {
            [articles addObject:[self articleFromCacheWithIssue:_issue andId:[nf numberFromString:[properties objectForKey:NSURLNameKey]]]];
        }
    }
    return articles;
}

-(NSArray *)images
{
    return [dictionary objectForKey:@"images"];
}

-(void)writeToCache {
    NSLog(@"TODO: %s", __PRETTY_FUNCTION__);
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtURL:[self cacheURL] withIntermediateDirectories:TRUE attributes:nil error:&error]) {
        
        NSLog(@"writing article to cache: %@",[[self metadataURL] absoluteString]);
        
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
    return [NSURL URLWithString:[featuredImageBaseName stringByAppendingPathExtension:@"_thumb.png"] relativeToURL:[self cacheURL]];
}

-(UIImage *)getFeaturedImageThumbFromDisk {
    NSData *thumbData = [NSData dataWithContentsOfURL:[self featuredImageThumbCacheURL]];
    return [UIImage imageWithData:thumbData scale:[[UIScreen mainScreen] scale]];
}

-(UIImage *)generateFeaturedImageThumbWithSize:(CGSize)thumbSize {
    UIImage *image = [self getFeaturedImage];
    
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

-(NSString *)attemptToGetBodyFromDisk {
    NSString *body = [bodyCache readWithOptions:nil stoppingAt:@"net"];
    return body;
}

-(void)requestBody {
    if(!self.requestingBody) {
        self.requestingBody = TRUE;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            
            id body = [bodyCache readWithOptions:nil];
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
        NSLog(@"Guest Pass: %@", data);
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
