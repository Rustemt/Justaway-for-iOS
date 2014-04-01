#import "JFIStatusCell.h"
#import "NSDate+Justaway.h"

@implementation JFIStatusCell

// ステータス（ツイートメッセージ）のスタイル
// 一時的にここで定義しているが後で移動する
+ (NSDictionary *)statusAttribute
{
    return @{ NSForegroundColorAttributeName : [UIColor darkGrayColor],
              NSFontAttributeName : [UIFont systemFontOfSize:12] };
}

// 自動生成されたやつ
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

// 自動生成されたやつ
- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

// セルにステータスを反映する奴
- (void)setLabelTexts:(NSDictionary *)status
{
    // 表示名
    self.displayNameLabel.text = [status valueForKeyPath:@"user.name"];
    
    // screen_name
    self.screenNameLabel.text = [@"@" stringByAppendingString:[status valueForKeyPath:@"user.screen_name"]];
    
    // ツイート
    self.statusLabel.attributedText = [[NSAttributedString alloc] initWithString:[status valueForKey:@"text"]
                                                                      attributes:JFIStatusCell.statusAttribute];
    
    // via名
    self.sourceLabel.text = [self getClientNameFromSource:[status valueForKey:@"source"]];
    
    // 投稿日時
    NSDate *createdAt = [NSDate dateWithTwitterDate:[status valueForKey:@"created_at"]];
    self.createdAtRelativeLabel.text = [createdAt relativeDescription];
    self.createdAtLabel.text = [createdAt absoluteDescription];
    
    // RT数
    if (![[[status valueForKey:@"retweet_count"] stringValue] isEqual:@"0"]) {
        self.retweetCountLabel.text = [[status valueForKey:@"retweet_count"] stringValue];
    } else {
        self.retweetCountLabel.text = @"";
    }
    
    // ふぁぼ数
    if (![[[status valueForKey:@"favorite_count"] stringValue] isEqual:@"0"]) {
        self.favoriteCountLabel.text = [[status valueForKey:@"favorite_count"] stringValue];
    } else {
        self.favoriteCountLabel.text = @"";
    }
    
    self.status = status;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    UIFont *font = [UIFont fontWithName:@"fontello" size:15];
    [self.replyButton.titleLabel setFont:font];
    [self.retweetButton.titleLabel setFont:font];
    [self.favoriteButton.titleLabel setFont:font];
    
    CGSize statusSize = [self.statusLabel.attributedText boundingRectWithSize:CGSizeMake(self.statusLabel.frame.size.width, MAXFLOAT)
                                                                      options:NSStringDrawingUsesLineFragmentOrigin
                                                                      context:nil].size;
    
    self.statusLabel.frame = CGRectMake(self.statusLabel.frame.origin.x,
                                        self.statusLabel.frame.origin.y,
                                        self.statusLabel.frame.size.width,
                                        statusSize.height);
}

- (void)setIndexPath:(NSIndexPath *)indexPath
{
    
}

- (NSString *)getClientNameFromSource:(NSString *)source
{
    NSError *error = nil;
    NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"rel=\"nofollow\">(.+)</a>" options:0 error:&error];
    if (error != nil) {
        NSLog(@"%@", error);
    } else {
        NSTextCheckingResult *match = [regexp firstMatchInString:source options:0 range:NSMakeRange(0, source.length)];
        if (match.numberOfRanges > 0) {
            return [source substringWithRange:[match rangeAtIndex:1]];
        }
    }
    return source;
}

- (IBAction)replyAction:(id)sender
{
    NSLog(@"reply status:%@", self.status);
}

- (IBAction)retweetAction:(id)sender
{
    NSLog(@"retweet status:%@", self.status);
}

- (IBAction)favoriteAction:(id)sender
{
    NSLog(@"favorite status:%@", self.status);
}

@end
