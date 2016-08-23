//
//  EpubReader.h
//  GGEnglish
//
//  Created by zhang yuanan on 15-3-9.
//  Copyright (c) 2015年 xiaobu network. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol EpubReaderDelegate <NSObject>

- (void)loadEpubFinished:(NSString *)opfPath spinePageArray:(NSArray *)spinePageArray navArray:(NSArray *)navArray;

@end

@interface EpubReader : NSObject

@property (weak, nonatomic) id<EpubReaderDelegate> delegate;

- (void)loadEpubPath:(NSString *)epubPath frame:(CGRect)frame;

@end
