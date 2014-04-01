#import "JFIConstants.h"
#import "JFIAppDelegate.h"
#import "JFIMessagesViewController.h"
#import "JFIHTTPImageOperation.h"

@interface JFIMessagesViewController ()

@end

@implementation JFIMessagesViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    JFIAppDelegate *delegate = (JFIAppDelegate *) [[UIApplication sharedApplication] delegate];
    
    // xibファイル名を指定しUINibオブジェクトを生成する
    UINib *nib = [UINib nibWithNibName:@"JFIMessageCell" bundle:nil];
    
    // UITableView#registerNib:forCellReuseIdentifierで、使用するセルを登録
    [self.tableView registerNib:nib forCellReuseIdentifier:JFICellID];
    
    // 高さの計算用のセルを登録
    [self.tableView registerNib:nib forCellReuseIdentifier:JFICellForHeightID];
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    // セルの高さ計算用のオブジェクトをあらかじめ生成して変数に保持しておく
    self.cellForHeight = [self.tableView dequeueReusableCellWithIdentifier:JFICellForHeightID];
    
    // pull down to refresh
    self.refreshControl = UIRefreshControl.new;
    [self.refreshControl addTarget:self action:@selector(onRefresh) forControlEvents:UIControlEventValueChanged];
    [self.tableView insertSubview:self.refreshControl atIndex:0];
    
    if ([delegate.accounts count] > 0) {
        [self onRefresh];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.messages count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    JFIMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:JFICellID forIndexPath:indexPath];
    
    if ([self.messages count] == 0) {
        return cell;
    }
    
    NSDictionary *message = [self.messages objectAtIndex:indexPath.row];
    
    NSURL *url = [NSURL URLWithString:[message valueForKeyPath:@"sender.profile_image_url"]];
    
    [cell setLabelTexts:message];
    
    [cell.displayNameLabel sizeToFit];
    
    [JFIHTTPImageOperation loadURL:url
                           handler:^(NSHTTPURLResponse *response, UIImage *image, NSError *error) {
                               JFIMessageCell *cell = (JFIMessageCell *)[tableView cellForRowAtIndexPath:indexPath];
                               cell.iconImageView.image = image;
                           }];
    
    return cell;
}

#pragma mark - UITableViewDataSource

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 59;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.cellForHeight.frame = self.tableView.bounds;
    
    [self.cellForHeight setLabelTexts:[self.messages objectAtIndex:indexPath.row]];
    [self.cellForHeight.contentView setNeedsLayout];
    [self.cellForHeight.contentView layoutIfNeeded];
    
    // 適切なサイズをAuto Layoutによって自動計算する
    CGSize size = [self.cellForHeight.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    
    // 自動計算で得られた高さを返す
    return size.height;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Statusを選択された時の処理
}

#pragma mark - UIRefreshControl

- (void)onRefresh
{
    JFIAppDelegate *delegate = (JFIAppDelegate *) [[UIApplication sharedApplication] delegate];
    
    if ([delegate.accounts count] == 0) {
        [self.refreshControl endRefreshing];
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle:@"disconnect"
                              message:@"「認」ボタンからアカウントを追加して下さい。"
                              delegate:nil
                              cancelButtonTitle:nil
                              otherButtonTitles:@"OK", nil
                              ];
        [alert show];
        return;
    }
    
    [self.refreshControl beginRefreshing];
    
    self.messages = [NSMutableArray array];
    
    STTwitterAPI *twitter = [delegate getTwitter];
    
    void(^errorBlock)(NSError *) =
    ^(NSError *error) {
        NSLog(@"-- error: %@", [error localizedDescription]);
        [self.refreshControl endRefreshing];
    };
    
    void(^sentSuccessBlock)(NSArray *) =
    ^(NSArray *messages) {
        [self.messages addObjectsFromArray:messages];
        NSSortDescriptor *sortDispNo = [[NSSortDescriptor alloc] initWithKey:@"created_at" ascending:NO];
        NSArray *sortDescArray = [NSArray arrayWithObjects:sortDispNo, nil];
        self.messages = [[self.messages sortedArrayUsingDescriptors:sortDescArray] mutableCopy];
        [self.tableView reloadData];
        [self.refreshControl endRefreshing];
    };
    
    void(^receiveSuccessBlock)(NSArray *) =
    ^(NSArray *messages) {
        [self.messages addObjectsFromArray:messages];
        [twitter getDirectMessagesSinceID:nil
                                    maxID:nil
                                    count:nil
                                     page:nil
                          includeEntities:0
                             successBlock:sentSuccessBlock
                               errorBlock:errorBlock];
        
    };
    
    [twitter getDirectMessagesSinceID:nil
                                count:20
                         successBlock:receiveSuccessBlock
                           errorBlock:errorBlock];
}

@end