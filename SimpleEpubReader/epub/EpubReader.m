//
//  EpubReader.m
//  GGEnglish
//
//  Created by zhang yuanan on 15-3-9.
//  Copyright (c) 2015年 xiaobu network. All rights reserved.
//

#import "EpubReader.h"
#import "TouchXML.h"

@interface EpubReader () <UIWebViewDelegate>

@property (copy, nonatomic) NSString *opfPath;
@property (strong, nonatomic) NSMutableArray *spineArray;
@property (strong, nonatomic) NSMutableArray *pageArray;
@property (strong, nonatomic) NSMutableArray *spinePageArray;
//{'spine':, 'ext:', 'title':}
@property (strong, nonatomic) NSMutableArray *navArray;

@property (strong, nonatomic) UIWebView *webView;
@property (nonatomic) NSInteger curParseIndex;

@end

@implementation EpubReader

- (void)loadEpubPath:(NSString *)epubPath frame:(CGRect)frame {
    NSString *manifestFilename = [NSString stringWithFormat:@"%@/META-INF/container.xml", epubPath];
    NSString *opfFilename = [self _getOpfFilename:manifestFilename];
    if (opfFilename) {
        NSString *totalPath = [NSString stringWithFormat:@"%@/%@", epubPath, opfFilename];
        NSInteger lastSlash = [totalPath rangeOfString:@"/" options:NSBackwardsSearch].location;
        _opfPath = [totalPath substringToIndex:lastSlash];
        [self _parseOPF:totalPath];
        [self _calcSpinePage:frame];
    }
}

- (NSString *)_getOpfFilename:(NSString *)manifestPath {
    NSError *error = nil;
    CXMLDocument *document = [[CXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:manifestPath] encoding:NSUTF8StringEncoding options:0 error:&error];
    if (error) {
        NSLog(@"%@", error);
        return nil;
    }
    CXMLNode *node = [document nodeForXPath:@"//@full-path[1]" error:&error];
    if (error) {
        NSLog(@"%@", error);
        return nil;
    }
    return [node stringValue];
}

- (void)_parseOPF:(NSString*)opfPath {
    CXMLDocument* opfFile = [[CXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:opfPath] options:0 error:nil];
    NSArray* itemArray = [opfFile nodesForXPath:@"//opf:item" namespaceMappings:[NSDictionary dictionaryWithObject:@"http://www.idpf.org/2007/opf" forKey:@"opf"] error:nil];

    NSMutableDictionary* itemDict = [NSMutableDictionary new];
    for (CXMLElement* element in itemArray) {
        [itemDict setValue:[[element attributeForName:@"href"] stringValue] forKey:[[element attributeForName:@"id"] stringValue]];
    }

    NSArray* itemRefArray = [opfFile nodesForXPath:@"//opf:itemref" namespaceMappings:[NSDictionary dictionaryWithObject:@"http://www.idpf.org/2007/opf" forKey:@"opf"] error:nil];
    
    _spineArray = [NSMutableArray new];
    for (CXMLElement* element in itemRefArray) {
        [_spineArray addObject:[itemDict valueForKey:[[element attributeForName:@"idref"] stringValue]]];
    }
    
    NSAssert(itemDict[@"ncx"], @"ncx should exist");
    NSString *ncxPath = [NSString stringWithFormat:@"%@/%@", _opfPath, itemDict[@"ncx"]];
    [self _parseNcx:ncxPath];
}

- (void)_parseNcx:(NSString *)ncxPath {
    CXMLDocument* ncxToc = [[CXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:ncxPath] options:0 error:nil];
    
    NSArray *textArray = [ncxToc nodesForXPath:@"//ncx:navLabel/ncx:text" namespaceMappings:[NSDictionary dictionaryWithObject:@"http://www.daisy.org/z3986/2005/ncx/" forKey:@"ncx"] error:nil];
    NSArray *contentArray = [ncxToc nodesForXPath:@"//ncx:content" namespaceMappings:[NSDictionary dictionaryWithObject:@"http://www.daisy.org/z3986/2005/ncx/" forKey:@"ncx"] error:nil];
    NSAssert(textArray.count==contentArray.count, @"text and content array should match");
    _navArray = [NSMutableArray new];
    for (NSInteger i=0; i<textArray.count; i++) {
        CXMLElement *textElement = textArray[i];
        CXMLElement *contentElement = contentArray[i];
        NSString *ref = [[contentElement attributeForName:@"src"] stringValue];
        NSInteger idPos = [ref rangeOfString:@"#" options:NSBackwardsSearch].location;
        NSString *spine = [ref substringToIndex:idPos];
        NSString *ext = [ref substringFromIndex:idPos];
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:@{@"spine":spine,
                                       @"ext":ext,
                                       @"title":[textElement stringValue]}];
        [_navArray addObject:dict];
    }
}

- (void)_calcSpinePage:(CGRect)frame {
    _webView = [[UIWebView alloc] initWithFrame:frame];
    _webView.delegate = self;
    _webView.paginationMode = UIWebPaginationModeLeftToRight;
    _curParseIndex = 0;
    _pageArray = [NSMutableArray new];
    [self _parseSpinePage];
}

- (void)_parseSpinePage {
    NSString *spinePath = [NSString stringWithFormat:@"%@/%@", _opfPath, _spineArray[_curParseIndex]];
    NSURL* url = [NSURL URLWithString:spinePath];
    [_webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [_pageArray addObject:[NSNumber numberWithInteger:webView.pageCount]];
    _curParseIndex++;
    //NSLog(@"parse index: %d", _curParseIndex);
    if (_curParseIndex==_spineArray.count) {
        _spinePageArray = [NSMutableArray new];
        for (NSInteger i=0; i<_spineArray.count; i++) {
            NSInteger page = [_pageArray[i] integerValue];
            [_spinePageArray addObject:@{@"spine":_spineArray[i],
                               @"page":[NSNumber numberWithInteger:page]}];
        }
        
        [_delegate loadEpubFinished:_opfPath spinePageArray:_spinePageArray navArray:_navArray];
    } else {
        [self _parseSpinePage];
    }
}


@end
