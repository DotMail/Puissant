//
//  PSTCommitFoldersOperation.h
//  DotMail
//
//  Created by Robert Widmann on 10/14/12.
//  Copyright (c) 2012 CodaFi Inc. All rights reserved.
//

#import "PSTStorageOperation.h"

/**
 * A concrete subclass of PSTStorageOperation that adds and indexes an array of folders to the 
 * message database.
 * Note: All properties are required except where noted.
 */

@interface PSTCommitFoldersOperation : PSTStorageOperation

- (void)start:(void(^)(void))callback;

/**
 * An array of folder paths to commit to the database.
 */
@property (nonatomic, strong) NSArray *folderPaths;

@end

