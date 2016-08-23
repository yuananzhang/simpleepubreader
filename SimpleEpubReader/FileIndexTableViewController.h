//
//  FileIndexTableViewController.h
//  SimpleEpubReader
//
//  Created by zhang yuanan on 15-3-11.
//  Copyright (c) 2015年 xiaobu network. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FileIndexTableViewController : UITableViewController

@property (copy, nonatomic) NSArray *navArray;

@property (strong, nonatomic) void (^completeCallback)(NSInteger index);

@end
