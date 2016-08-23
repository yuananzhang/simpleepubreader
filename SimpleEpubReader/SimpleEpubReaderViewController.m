//
//  SimpleEpubReaderViewController.m
//  SimpleEpubReader
//
//  Created by zhang yuanan on 15-3-9.
//  Copyright (c) 2015年 xiaobu network. All rights reserved.
//

#import "SimpleEpubReaderViewController.h"
#import "EpubReader.h"
#import "SSZipArchive.h"
#import "FileIndexTableViewController.h"
#import "MBProgressHUD.h"

@interface UIWebView (selectedText)

- (NSString *)selectedText;

@end

@implementation UIWebView (selectedText)

- (NSString *)selectedText {
    return [self stringByEvaluatingJavaScriptFromString: @"window.getSelection().toString()"];
}

@end

@interface SimpleEpubReaderViewController () <UIWebViewDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate, EpubReaderDelegate>
@property (weak, nonatomic) IBOutlet UIWebView *webView;

@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
- (IBAction)listButtonPressed:(id)sender;
- (IBAction)minusButtonPressed:(id)sender;

- (IBAction)addButtonPressed:(id)sender;

@property (strong, nonatomic) EpubReader *epubReader;
@property (copy, nonatomic) NSString *epubFilePath;
@property (copy, nonatomic) NSString *epubOpfPath;

@property (copy, nonatomic) NSArray *navArray;
@property (copy, nonatomic) NSMutableArray *spinePageArray;

@property (nonatomic) BOOL isNavigate;
@property (nonatomic) BOOL spineChanged;
@property (nonatomic) BOOL changedTextSize;

@property (nonatomic) NSInteger currentSpineIndex;
@property (nonatomic) NSInteger currentPage;
@property (nonatomic) CGFloat pageWidth;
@property (nonatomic) NSInteger textFontSize;

@end

@implementation SimpleEpubReaderViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _webView.delegate = self;
    _webView.scrollView.delegate = self;
    _webView.scrollView.bounces = NO;
    _webView.scrollView.pagingEnabled = YES;
    _webView.paginationMode = UIWebPaginationModeLeftToRight;
    
    [self startObservingContentSizeChangesInWebView:_webView];
    
    [self initGesture];
    _textFontSize = 100;
    _pageWidth = CGRectGetWidth(self.view.frame);
    
    _epubReader = [EpubReader new];
    _epubReader.delegate = self;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains
    (NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [paths objectAtIndex:0];
    _epubFilePath = [NSString stringWithFormat:@"%@/book", cacheDirectory];
    [self createEpubFilePath:[[NSBundle mainBundle] pathForResource:@"book" ofType:nil]  path:_epubFilePath];
    
    [self prepare];
}

- (void)createEpubFilePath:(NSString *)fileName path:(NSString *)path{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path]) {
        return;
    }
    [fileManager createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
    [SSZipArchive unzipFileAtPath:fileName toDestination:path];
}

- (void)dealloc {
    [self stopObservingContentSizeChangesInWebView:_webView];
}

- (BOOL)prefersStatusBarHidden {
    return self.navigationController.navigationBar.hidden;
}

- (IBAction)listButtonPressed:(id)sender {
    [self performSegueWithIdentifier:@"list" sender:self];
}

- (IBAction)minusButtonPressed:(id)sender {
    [self addTextFontSize:NO];
}
- (IBAction)addButtonPressed:(id)sender {
    [self addTextFontSize:YES];
}

- (void)addTextFontSize:(BOOL)add
{
    NSLog(@"before:%f", _webView.scrollView.contentSize.width);
    if (add) {
        _textFontSize = (_textFontSize < 160) ? _textFontSize +5 : _textFontSize;
    } else {
        _textFontSize = (_textFontSize > 50) ? _textFontSize -5 : _textFontSize;
    }
    
    [self _adjustWebView:_webView textSize:_textFontSize];
}

- (void)hideBars:(BOOL)barHidden {
    self.navigationController.navigationBar.hidden = barHidden;
    _toolbar.hidden = barHidden;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)prepare {
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [_epubReader loadEpubPath:_epubFilePath frame:self.view.bounds];
}

- (void)loadEpubFinished:(NSString *)opfPath spinePageArray:(NSArray *)spineArray navArray:(NSArray *)navArray {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    _epubOpfPath = opfPath;
    _spinePageArray = [[NSMutableArray alloc] initWithArray:spineArray];
    _navArray = [navArray copy];
    [self _gotoSpine:0 page:0];
}

#pragma mark -- scroll delegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    //NSLog(@"start:%@", NSStringFromCGPoint(_webView.scrollView.contentOffset));
    //NSInteger startPage = lroundf(scrollView.contentOffset.x/_pageWidth);
    //NSAssert(startPage==_currentPage, @"page should match");
    _spineChanged = FALSE;
    if ([scrollView.panGestureRecognizer translationInView:scrollView.superview].x > 0) {
        NSLog(@"goto left");
        if (_currentPage==0 && _currentSpineIndex!=0) {
            //NSDictionary *dict = _spinePageArray[_currentSpineIndex-1];
            _spineChanged = TRUE;
            [self _gotoSpine:(_currentSpineIndex-1) page:-1];
        }
    } else {
        NSLog(@"goto right");
        NSDictionary *dict = _spinePageArray[_currentSpineIndex];
        NSLog(@"%ld", [dict[@"page"] integerValue]);
        if (_currentPage==([dict[@"page"] integerValue]-1) && _currentSpineIndex!=(_spinePageArray.count-1)) {
            _spineChanged = TRUE;
            [self _gotoSpine:(_currentSpineIndex+1) page:0];
        }
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    //NSLog(@"target:%@", NSStringFromCGPoint(*targetContentOffset));
    if (!_spineChanged) {
        _currentPage = lroundf((*targetContentOffset).x/_pageWidth);
        NSLog(@"current page:%ld", (long)_currentPage);
    }
}

#pragma mark -- kvo

static int kObservingContentSizeChangesContext;

- (void)startObservingContentSizeChangesInWebView:(UIWebView *)webView {
    [webView.scrollView addObserver:self forKeyPath:@"contentSize" options:0 context:&kObservingContentSizeChangesContext];
}

- (void)stopObservingContentSizeChangesInWebView:(UIWebView *)webView {
    [webView.scrollView removeObserver:self forKeyPath:@"contentSize" context:&kObservingContentSizeChangesContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &kObservingContentSizeChangesContext) {
        if (_changedTextSize) {
            UIScrollView *scrollView = object;
            NSInteger changedPage = lroundf(scrollView.contentSize.width/_pageWidth);
            if (_currentPage==-1) {
                _currentPage = changedPage-1;
                scrollView.contentOffset = CGPointMake(_currentPage*_pageWidth, 0);
            }
            NSDictionary *dict = _spinePageArray[_currentSpineIndex];
            NSInteger prePage = [dict[@"page"] integerValue];
            NSLog(@"changedPage:%ld, prePage:%ld", (long)changedPage, (long)prePage);
            if (changedPage!=prePage) {
                [_spinePageArray replaceObjectAtIndex:_currentSpineIndex
                                           withObject:@{@"spine":dict[@"spine"],
                                                        @"page":[NSNumber numberWithInteger:changedPage]}];
            }
            _changedTextSize = FALSE;
        } else {
            if (_textFontSize!=100) {
                NSLog(@"change text size:%ld", (long)_textFontSize);
                [self _adjustWebView:_webView textSize:_textFontSize];
                _changedTextSize = YES;
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -- webview

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSLog(@"%@", request.URL.scheme);
    if ([request.URL.scheme isEqualToString:@"callback"]) {
        NSLog(@"set text size callback");
        NSLog(@"after:%f", _webView.scrollView.contentSize.width);
        return NO;
    }
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (_isNavigate) {
        _currentPage = lroundf(webView.scrollView.contentOffset.x/_pageWidth);
    } else {
        if (_currentPage==-1) {
            if (_textFontSize!=100) {
                return;
            }
            NSDictionary *dict = _spinePageArray[_currentSpineIndex];
            _currentPage = [dict[@"page"] integerValue]-1;
        }
        NSLog(@"goto page:%ld", (long)_currentPage);
        webView.scrollView.contentOffset = CGPointMake(_currentPage*webView.bounds.size.width, 0);
    }
}

#pragma mark -- gesture

- (void)initGesture {
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGesture:)];
    longPress.delegate = self;
    [_webView addGestureRecognizer:longPress];
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    singleTap.delegate = self;
    [singleTap setNumberOfTapsRequired:1];
    [singleTap requireGestureRecognizerToFail:longPress];
    [_webView addGestureRecognizer:singleTap];
    
    UISwipeGestureRecognizer *leftSwipeGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGesture:)];
    leftSwipeGesture.direction = UISwipeGestureRecognizerDirectionLeft;
    [_webView addGestureRecognizer:leftSwipeGesture];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)handleTapGesture:(UIGestureRecognizer *)recognizer {
    if (self.navigationController.navigationBar.hidden) {
        [self hideBars:NO];
    } else {
        [self hideBars:YES];
    }
}

- (void)handleLongPressGesture:(UIGestureRecognizer *)recognizer {
    NSString *word = [[_webView selectedText] lowercaseString];
    if (word.length==0) {
        return;
    }
    NSLog(@"selected word %@", word);
}

- (void)handleSwipeGesture:(UISwipeGestureRecognizer *)recognizer {
    NSDictionary *dict = _spinePageArray[_currentSpineIndex];
    if ([dict[@"page"] integerValue]==1) {
        [self _gotoSpine:(_currentSpineIndex+1) page:0];
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    FileIndexTableViewController *vc = segue.destinationViewController;
    vc.navArray = [_navArray copy];
    vc.completeCallback = ^(NSInteger index){
        NSLog(@"index=%ld", (long)index);
        
        [self hideBars:YES];
        
        NSDictionary *fileIndexDict = _navArray[index];
        NSString *currentSpine = fileIndexDict[@"spine"];
        _currentSpineIndex = [self _getSpineIndex:_spinePageArray spine:currentSpine];
        
        NSString *spinePath = [NSString stringWithFormat:@"%@/%@", _epubOpfPath, currentSpine];
        NSURL* url = [NSURL URLWithString:spinePath];
        NSURL *newUrl = [NSURL URLWithString:fileIndexDict[@"ext"] relativeToURL:url];
        _isNavigate = TRUE;
        [_webView loadRequest:[NSURLRequest requestWithURL:newUrl]];
    };
}

#pragma mark --private methods

- (void)_adjustWebView:(UIWebView *)webView textSize:(NSInteger)textSize {
    NSString *jsString = [[NSString alloc] initWithFormat:@"document.getElementsByTagName('body')[0].style.webkitTextSizeAdjust= '%ld%%';window.location='callback://nothing'",
                          (long)textSize];
    [webView stringByEvaluatingJavaScriptFromString:jsString];
}

- (NSDictionary *)_getSpineIndexAndPage:(NSArray *)spinePageArray page:(NSInteger)page {
    NSInteger index = -1;
    NSInteger total = 0;
    for (NSInteger i=0; i<spinePageArray.count; i++) {
        NSDictionary *dict = spinePageArray[i];
        total += [dict[@"page"] integerValue];
        if (page<total) {
            index = i;
            break;
        }
    }
    NSAssert(index>=0, @"page number is too big!");
    NSInteger offset = total-page;
    return @{@"spineIndex":[NSNumber numberWithInteger:index],
             @"page":[NSNumber numberWithInteger:offset]};
    
}

- (NSInteger)_getSpineIndex:(NSArray *)spinePageArray spine:(NSString *)spine {
    for (NSInteger i=0; i<spinePageArray.count; i++) {
        NSDictionary *dict = spinePageArray[i];
        if ([spine isEqualToString:dict[@"spine"]]) {
            return i;
        }
    }
    return -1;
}

- (void)_gotoSpine:(NSInteger)spineIndex page:(NSInteger)page {
    _currentSpineIndex = spineIndex;
    _currentPage = page;
    NSLog(@"curSpine:%ld, curPage:%ld", (long)_currentSpineIndex, (long)_currentPage);
    
    NSDictionary *dict = _spinePageArray[_currentSpineIndex];
    NSString *currentSpine = dict[@"spine"];
    NSString *spinePath = [NSString stringWithFormat:@"%@/%@", _epubOpfPath, currentSpine];
    NSURL* url = [NSURL URLWithString:spinePath];
    _isNavigate = FALSE;
    [_webView loadRequest:[NSURLRequest requestWithURL:url]];
}


@end
