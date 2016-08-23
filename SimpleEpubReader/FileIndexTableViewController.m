//
//  FileIndexTableViewController.m
//  SimpleEpubReader
//
//  Created by zhang yuanan on 15-3-11.
//  Copyright (c) 2015年 xiaobu network. All rights reserved.
//

#import "FileIndexTableViewController.h"

@interface FileIndexTableViewController ()

@end

@implementation FileIndexTableViewController

static NSString * const TableCellIdentifier = @"cell";

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:TableCellIdentifier];
    [self setNeedsStatusBarAppearanceUpdate];
}


- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _navArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:TableCellIdentifier forIndexPath:indexPath];
    
    NSDictionary *dict = _navArray[indexPath.row];
    cell.textLabel.font = [UIFont italicSystemFontOfSize:13.0];
    cell.textLabel.text = dict[@"title"];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    _completeCallback(indexPath.row);
    _completeCallback = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
