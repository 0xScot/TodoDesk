#import "TDTaskFileStore.h"

@implementation TDTaskFileStore

- (instancetype)initWithFileURL:(NSURL *)fileURL {
    self = [super init];
    if (self) {
        _fileURL = fileURL;
    }
    return self;
}

+ (NSURL *)defaultStoreURL {
    NSString *customStorePath = [NSProcessInfo.processInfo.environment[@"TODODESK_STORE_PATH"] stringByExpandingTildeInPath];
    if (customStorePath.length > 0) {
        return [NSURL fileURLWithPath:customStorePath];
    }

    NSURL *applicationSupportURL = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                                                        inDomains:NSUserDomainMask].firstObject;
    if (applicationSupportURL == nil) {
        applicationSupportURL = [NSURL fileURLWithPath:NSHomeDirectory()];
    }
    return [[applicationSupportURL URLByAppendingPathComponent:@"TodoDesk" isDirectory:YES] URLByAppendingPathComponent:@"tasks.json"];
}

- (NSArray<TDTodoTask *> *)loadTasksWithError:(NSError **)error {
    return [self loadTodoListWithError:error].tasks;
}

- (TDTodoList *)loadTodoListWithError:(NSError **)error {
    if (![NSFileManager.defaultManager fileExistsAtPath:self.fileURL.path]) {
        return [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    }

    NSData *data = [NSData dataWithContentsOfURL:self.fileURL options:0 error:error];
    if (data == nil) {
        return [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    }

    return [self todoListFromData:data error:error];
}

- (TDTodoList *)todoListFromData:(NSData *)data error:(NSError **)error {
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if ([json isKindOfClass:NSArray.class]) {
        return [self todoListByMigratingLegacyTaskArray:json];
    }

    if (![json isKindOfClass:NSDictionary.class]) {
        return [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    }

    NSArray *taskJSON = [json[@"tasks"] isKindOfClass:NSArray.class] ? json[@"tasks"] : @[];
    NSArray *listJSON = [json[@"lists"] isKindOfClass:NSArray.class] ? json[@"lists"] : @[];
    NSMutableArray<TDCustomList *> *customLists = [NSMutableArray array];
    for (id item in listJSON) {
        if (![item isKindOfClass:NSDictionary.class]) {
            continue;
        }
        TDCustomList *list = [TDCustomList listWithDictionaryRepresentation:item];
        if (list != nil) {
            [customLists addObject:list];
        }
    }

    NSMutableArray<TDTodoTask *> *tasks = [NSMutableArray array];
    for (id item in taskJSON) {
        if (![item isKindOfClass:NSDictionary.class]) {
            continue;
        }
        TDTodoTask *task = [TDTodoTask taskWithDictionaryRepresentation:item];
        if (task != nil) {
            [tasks addObject:task];
        }
    }

    return [self todoListByEnsuringCustomTasksHaveListsWithTasks:tasks customLists:customLists];
}

- (BOOL)saveTasks:(NSArray<TDTodoTask *> *)tasks error:(NSError **)error {
    TDTodoList *todoList = [[TDTodoList alloc] initWithTasks:tasks customLists:@[]];
    return [self saveTodoList:todoList error:error];
}

- (BOOL)saveTodoList:(TDTodoList *)todoList error:(NSError **)error {
    NSURL *directoryURL = [self.fileURL URLByDeletingLastPathComponent];
    if (![NSFileManager.defaultManager createDirectoryAtURL:directoryURL
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                     error:error]) {
        return NO;
    }

    NSData *data = [self dataForTodoList:todoList error:error];
    if (data == nil) {
        return NO;
    }

    return [data writeToURL:self.fileURL options:NSDataWritingAtomic error:error];
}

- (NSData *)dataForTodoList:(TDTodoList *)todoList error:(NSError **)error {
    NSMutableArray<NSDictionary<NSString *, id> *> *jsonTasks = [NSMutableArray arrayWithCapacity:todoList.tasks.count];
    for (TDTodoTask *task in todoList.tasks) {
        [jsonTasks addObject:[task dictionaryRepresentation]];
    }

    NSMutableArray<NSDictionary<NSString *, id> *> *jsonLists = [NSMutableArray arrayWithCapacity:todoList.customLists.count];
    for (TDCustomList *list in todoList.customLists) {
        [jsonLists addObject:[list dictionaryRepresentation]];
    }

    NSDictionary *database = @{
        @"version": @2,
        @"lists": jsonLists,
        @"tasks": jsonTasks
    };

    return [NSJSONSerialization dataWithJSONObject:database
                                          options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                            error:error];
}

- (TDTodoList *)todoListByMigratingLegacyTaskArray:(NSArray *)legacyTaskArray {
    NSMutableArray<TDTodoTask *> *tasks = [NSMutableArray array];
    for (id item in legacyTaskArray) {
        if (![item isKindOfClass:NSDictionary.class]) {
            continue;
        }
        TDTodoTask *task = [TDTodoTask taskWithDictionaryRepresentation:item];
        if (task != nil) {
            [tasks addObject:task];
        }
    }
    return [self todoListByEnsuringCustomTasksHaveListsWithTasks:tasks customLists:[NSMutableArray array]];
}

- (TDTodoList *)todoListByEnsuringCustomTasksHaveListsWithTasks:(NSMutableArray<TDTodoTask *> *)tasks
                                                    customLists:(NSMutableArray<TDCustomList *> *)customLists {
    NSMutableSet<NSString *> *knownListIDs = [NSMutableSet set];
    for (TDCustomList *list in customLists) {
        [knownListIDs addObject:list.identifier];
    }

    TDCustomList *defaultList = nil;
    for (TDTodoTask *task in tasks) {
        if (task.bucket != TDTaskBucketCustom) {
            continue;
        }
        if (task.listID.length > 0 && [knownListIDs containsObject:task.listID]) {
            continue;
        }
        if (defaultList == nil) {
            defaultList = [[TDCustomList alloc] initWithIdentifier:[NSUUID UUID].UUIDString
                                                              name:@"自定義"
                                                         createdAt:task.createdAt ?: [NSDate date]
                                                         sortOrder:customLists.count];
            [customLists addObject:defaultList];
            [knownListIDs addObject:defaultList.identifier];
        }
        task.listID = defaultList.identifier;
    }

    return [[TDTodoList alloc] initWithTasks:tasks customLists:customLists];
}

@end
