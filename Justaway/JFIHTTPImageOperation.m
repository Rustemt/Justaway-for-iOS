#import "JFIHTTPImageOperation.h"
#import "UIImage+Processing.h"
#import <ISMemoryCache/ISMemoryCache.h>
#import <ISDiskCache/ISDiskCache.h>

@interface JFIHTTPImageOperation ()

@property (nonatomic) NSData *data;
@property (nonatomic) NSHTTPURLResponse *response;
@property (nonatomic) ImageProcessType processType;

@end

@implementation JFIHTTPImageOperation

+ (void)loadURL:(NSURL *)URL processType:(ImageProcessType)processType handler:(void (^)(NSHTTPURLResponse *, UIImage *, NSError *))handler
{
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    JFIHTTPImageOperation *operation = [[JFIHTTPImageOperation alloc] initWithRequest:request
                                                                              handler:handler];
    operation.processType = processType;
    operation.queuePriority = 0;
    [[ISHTTPOperationQueue defaultQueue] addOperation:operation];
}

- (NSURL *)cacheKey
{
    NSString *string;
    switch (self.processType) {
        case ImageProcessTypeIcon:
            string = @"icon";
            break;
            
        case ImageProcessTypeThumbnail:
            string = @"thumbnail";
            break;
            
        default:
            string = @"";
            break;
    }
    if (self.request.URL.query) {
        return [NSURL URLWithString:[NSString stringWithFormat:@"%@&%@", [self.request.URL absoluteString], string]];
    } else {
        return [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", [self.request.URL absoluteString], string]];
    }
}

- (void)main
{
    @autoreleasepool {
        ISMemoryCache *memoryCache = [ISMemoryCache sharedCache];
        UIImage *cachedImage = [memoryCache objectForKey:self.cacheKey];
        
        if (cachedImage) {
            [memoryCache setObject:cachedImage forKey:self.cacheKey];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.handler) {
                    self.handler(nil, cachedImage, nil);
                }
            });
            [self completeOperation];
            
            return;
        }
    }
    [super main];
}

- (id)processData:(NSData *)data
{
    UIImage *image = [UIImage imageWithData:data];
    
    ISMemoryCache *memoryCache = [ISMemoryCache sharedCache];
    ISDiskCache *diskCache = [ISDiskCache sharedCache];
    
    UIImage *processedImage;
    switch (self.processType) {
        case ImageProcessTypeIcon:
            processedImage = [image resizedImageForSize:CGSizeMake(42.f, 42.f) cornerRadius:5.f];
            break;
            
        case ImageProcessTypeThumbnail:
            processedImage = [image resizedImageForSize:CGSizeMake(75.f, 75.f)];
            break;
            
        default:
            break;
    }
    
    if (processedImage) {
        [memoryCache setObject:processedImage forKey:self.cacheKey];
        [diskCache setObject:processedImage forKey:self.cacheKey];
    }
    
    return processedImage;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    id object = [self processData:self.data];
    if (object && self.handler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.handler(self.response, object, nil);
        });
    }
    
    [self completeOperation];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self completeOperation];
}

@end
