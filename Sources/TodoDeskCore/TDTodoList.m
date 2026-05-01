#import "TDTodoList.h"

static BOOL TDValuesEqual(id left, id right) {
    if (left == nil || right == nil) {
        return left == right;
    }
    return [left isEqual:right];
}

@implementation TDTodoList

+ (NSDate *)activeDayStartForDate:(NSDate *)date
                          calendar:(NSCalendar *)calendar
                todayCutoffMinutes:(NSInteger)todayCutoffMinutes {
    NSInteger clampedCutoff = MAX(0, MIN(todayCutoffMinutes, 23 * 60 + 59));
    NSDate *cutoffShiftedDate = [date dateByAddingTimeInterval:-(NSTimeInterval)(clampedCutoff * 60)];
    return [calendar startOfDayForDate:cutoffShiftedDate];
}

+ (NSDate *)dayStartForDate:(NSDate *)date
                     offset:(NSInteger)dayOffset
                   calendar:(NSCalendar *)calendar
         todayCutoffMinutes:(NSInteger)todayCutoffMinutes {
    NSDate *activeDayStart = [self activeDayStartForDate:date calendar:calendar todayCutoffMinutes:todayCutoffMinutes];
    return [calendar dateByAddingUnit:NSCalendarUnitDay value:dayOffset toDate:activeDayStart options:0];
}

- (instancetype)initWithTasks:(NSArray<TDTodoTask *> *)tasks {
    return [self initWithTasks:tasks customLists:@[]];
}

- (instancetype)initWithTasks:(NSArray<TDTodoTask *> *)tasks
                  customLists:(NSArray<TDCustomList *> *)customLists {
    self = [super init];
    if (self) {
        _tasks = [tasks mutableCopy];
        _customLists = [[customLists sortedArrayUsingComparator:^NSComparisonResult(TDCustomList *left, TDCustomList *right) {
            if (left.sortOrder < right.sortOrder) {
                return NSOrderedAscending;
            }
            if (left.sortOrder > right.sortOrder) {
                return NSOrderedDescending;
            }
            return [left.createdAt compare:right.createdAt];
        }] mutableCopy];
    }
    return self;
}

- (TDTodoTask *)addTaskWithTitle:(NSString *)title
                          bucket:(TDTaskBucket)bucket
                             now:(NSDate *)now
                        calendar:(NSCalendar *)calendar {
    return [self addTaskWithTitle:title bucket:bucket estimatedMinutes:0 now:now calendar:calendar];
}

- (TDTodoTask *)addTaskWithTitle:(NSString *)title
                          bucket:(TDTaskBucket)bucket
                estimatedMinutes:(NSInteger)estimatedMinutes
                             now:(NSDate *)now
                        calendar:(NSCalendar *)calendar {
    return [self addTaskWithTitle:title
                           bucket:bucket
                 estimatedMinutes:estimatedMinutes
                         dayOffset:0
                              now:now
                         calendar:calendar
               todayCutoffMinutes:0];
}

- (TDTodoTask *)addTaskWithTitle:(NSString *)title
                          bucket:(TDTaskBucket)bucket
                estimatedMinutes:(NSInteger)estimatedMinutes
                        dayOffset:(NSInteger)dayOffset
                             now:(NSDate *)now
                        calendar:(NSCalendar *)calendar
              todayCutoffMinutes:(NSInteger)todayCutoffMinutes {
    NSString *trimmedTitle = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSDate *dueDate = bucket == TDTaskBucketToday
        ? [TDTodoList dayStartForDate:now offset:dayOffset calendar:calendar todayCutoffMinutes:todayCutoffMinutes]
        : nil;
    TDTodoTask *task = [[TDTodoTask alloc] initWithIdentifier:[NSUUID UUID].UUIDString
                                                        title:trimmedTitle
                                                    createdAt:now
                                                      dueDate:dueDate
                                                  completedAt:nil
                                                       bucket:bucket
                                                       listID:nil
                                            estimatedMinutes:estimatedMinutes
                                                    sortOrder:[self nextSortOrderForBucket:bucket dueDate:dueDate listID:nil]];
    [self.tasks addObject:task];
    return task;
}

- (TDTodoTask *)addTaskWithTitle:(NSString *)title
                     customListID:(NSString *)customListID
                              now:(NSDate *)now {
    return [self addTaskWithTitle:title customListID:customListID estimatedMinutes:0 now:now];
}

- (TDTodoTask *)addTaskWithTitle:(NSString *)title
                     customListID:(NSString *)customListID
                 estimatedMinutes:(NSInteger)estimatedMinutes
                              now:(NSDate *)now {
    NSString *trimmedTitle = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    TDTodoTask *task = [[TDTodoTask alloc] initWithIdentifier:[NSUUID UUID].UUIDString
                                                        title:trimmedTitle
                                                    createdAt:now
                                                      dueDate:nil
                                                  completedAt:nil
                                                       bucket:TDTaskBucketCustom
                                                       listID:customListID
                                            estimatedMinutes:estimatedMinutes
                                                    sortOrder:[self nextSortOrderForBucket:TDTaskBucketCustom dueDate:nil listID:customListID]];
    [self.tasks addObject:task];
    return task;
}

- (TDCustomList *)addCustomListNamed:(NSString *)name now:(NSDate *)now {
    NSString *trimmedName = [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    TDCustomList *list = [[TDCustomList alloc] initWithIdentifier:[NSUUID UUID].UUIDString
                                                             name:trimmedName.length == 0 ? @"未命名" : trimmedName
                                                        createdAt:now
                                                        sortOrder:[self nextCustomListSortOrder]];
    [self.customLists addObject:list];
    return list;
}

- (TDTodoTask *)addSubtaskWithTitle:(NSString *)title
                        parentTaskID:(NSString *)parentTaskID
                                 now:(NSDate *)now {
    return [self addSubtaskWithTitle:title parentTaskID:parentTaskID estimatedMinutes:0 now:now];
}

- (TDTodoTask *)addSubtaskWithTitle:(NSString *)title
                        parentTaskID:(NSString *)parentTaskID
                    estimatedMinutes:(NSInteger)estimatedMinutes
                                 now:(NSDate *)now {
    TDTodoTask *parent = [self rootParentTaskForTask:[self taskWithID:parentTaskID]];
    if (parent == nil) {
        return nil;
    }

    NSString *trimmedTitle = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    TDTodoTask *task = [[TDTodoTask alloc] initWithIdentifier:[NSUUID UUID].UUIDString
                                                        title:trimmedTitle.length == 0 ? @"未命名子任務" : trimmedTitle
                                                    createdAt:now
                                                      dueDate:parent.dueDate
                                                  completedAt:nil
                                                       bucket:parent.bucket
                                                       listID:parent.listID
                                                 parentTaskID:parent.identifier
                                             estimatedMinutes:estimatedMinutes
                                                    sortOrder:[self nextSortOrderForParentTaskID:parent.identifier]];
    [self.tasks addObject:task];
    return task;
}

- (NSArray<TDTodoTask *> *)tasksForTab:(TDTaskTab)tab
                                   now:(NSDate *)now
                              calendar:(NSCalendar *)calendar {
    return [self tasksForTab:tab now:now calendar:calendar todayCutoffMinutes:0];
}

- (NSArray<TDTodoTask *> *)tasksForTab:(TDTaskTab)tab
                                   now:(NSDate *)now
                              calendar:(NSCalendar *)calendar
                    todayCutoffMinutes:(NSInteger)todayCutoffMinutes {
    NSDate *todayStart = [TDTodoList dayStartForDate:now offset:0 calendar:calendar todayCutoffMinutes:todayCutoffMinutes];
    NSDate *tomorrowStart = [TDTodoList dayStartForDate:now offset:1 calendar:calendar todayCutoffMinutes:todayCutoffMinutes];
    NSPredicate *predicate;
    NSComparator comparator;

    switch (tab) {
        case TDTaskTabPastCompleted: {
            predicate = [NSPredicate predicateWithBlock:^BOOL(TDTodoTask *task, NSDictionary *bindings) {
                (void)bindings;
                return task.bucket == TDTaskBucketToday && task.completedAt != nil && [self dueDate:task.dueDate isBefore:todayStart];
            }];
            comparator = ^NSComparisonResult(TDTodoTask *left, TDTodoTask *right) {
                NSComparisonResult result = [right.completedAt compare:left.completedAt];
                if (result != NSOrderedSame) {
                    return result;
                }
                return [right.createdAt compare:left.createdAt];
            };
            break;
        }

        case TDTaskTabPastIncomplete: {
            predicate = [NSPredicate predicateWithBlock:^BOOL(TDTodoTask *task, NSDictionary *bindings) {
                (void)bindings;
                return task.bucket == TDTaskBucketToday && task.completedAt == nil && [self dueDate:task.dueDate isBefore:todayStart];
            }];
            comparator = ^NSComparisonResult(TDTodoTask *left, TDTodoTask *right) {
                NSComparisonResult result = [left.dueDate compare:right.dueDate];
                if (result != NSOrderedSame) {
                    return result;
                }
                return [self compareTaskOrder:left other:right];
            };
            break;
        }

        case TDTaskTabToday: {
            predicate = [NSPredicate predicateWithBlock:^BOOL(TDTodoTask *task, NSDictionary *bindings) {
                (void)bindings;
                return task.bucket == TDTaskBucketToday && task.dueDate != nil && [calendar isDate:task.dueDate inSameDayAsDate:todayStart];
            }];
            comparator = ^NSComparisonResult(TDTodoTask *left, TDTodoTask *right) {
                return [self compareTaskOrder:left other:right];
            };
            break;
        }

        case TDTaskTabTomorrow: {
            predicate = [NSPredicate predicateWithBlock:^BOOL(TDTodoTask *task, NSDictionary *bindings) {
                (void)bindings;
                return task.bucket == TDTaskBucketToday && task.dueDate != nil && [calendar isDate:task.dueDate inSameDayAsDate:tomorrowStart];
            }];
            comparator = ^NSComparisonResult(TDTodoTask *left, TDTodoTask *right) {
                return [self compareTaskOrder:left other:right];
            };
            break;
        }

        case TDTaskTabCustom:
        default: {
            predicate = [NSPredicate predicateWithBlock:^BOOL(TDTodoTask *task, NSDictionary *bindings) {
                (void)bindings;
                return task.bucket == TDTaskBucketCustom && task.listID != nil;
            }];
            comparator = ^NSComparisonResult(TDTodoTask *left, TDTodoTask *right) {
                return [self compareTaskOrder:left other:right];
            };
            break;
        }
    }

    return [self hierarchicalTasksFromFilteredTasks:[self.tasks filteredArrayUsingPredicate:predicate] comparator:comparator];
}

- (NSArray<TDTodoTask *> *)tasksForCustomListID:(NSString *)customListID {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(TDTodoTask *task, NSDictionary *bindings) {
        (void)bindings;
        return task.bucket == TDTaskBucketCustom && [task.listID isEqualToString:customListID];
    }];
    NSArray<TDTodoTask *> *tasks = [self.tasks filteredArrayUsingPredicate:predicate];
    NSComparator comparator = ^NSComparisonResult(TDTodoTask *left, TDTodoTask *right) {
        return [self compareTaskOrder:left other:right];
    };
    return [self hierarchicalTasksFromFilteredTasks:tasks comparator:comparator];
}

- (void)toggleCompletionForTaskID:(NSString *)taskID atDate:(NSDate *)date {
    TDTodoTask *task = [self taskWithID:taskID];
    if (task == nil) {
        return;
    }
    task.completedAt = task.completedAt == nil ? date : nil;
}

- (BOOL)renameTaskWithID:(NSString *)taskID title:(NSString *)title {
    TDTodoTask *task = [self taskWithID:taskID];
    if (task == nil) {
        return NO;
    }

    NSString *trimmedTitle = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedTitle.length == 0) {
        return NO;
    }

    task.title = trimmedTitle;
    return YES;
}

- (BOOL)updateDescriptionForTaskID:(NSString *)taskID description:(NSString *)description {
    TDTodoTask *task = [self taskWithID:taskID];
    if (task == nil) {
        return NO;
    }

    NSString *trimmedDescription = [description stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    task.taskDescription = trimmedDescription.length > 0 ? trimmedDescription : nil;
    return YES;
}

- (BOOL)updateDetailsForTaskID:(NSString *)taskID description:(NSString *)description estimatedMinutes:(NSInteger)estimatedMinutes {
    TDTodoTask *task = [self taskWithID:taskID];
    if (task == nil) {
        return NO;
    }

    NSString *trimmedDescription = [description stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    task.taskDescription = trimmedDescription.length > 0 ? trimmedDescription : nil;
    task.estimatedMinutes = MAX(0, estimatedMinutes);
    return YES;
}

- (void)deleteTaskWithID:(NSString *)taskID {
    NSMutableSet<NSString *> *idsToDelete = [NSMutableSet setWithObject:taskID];
    BOOL addedChild = YES;
    while (addedChild) {
        addedChild = NO;
        for (TDTodoTask *task in self.tasks) {
            if (task.parentTaskID.length == 0 || ![idsToDelete containsObject:task.parentTaskID] || [idsToDelete containsObject:task.identifier]) {
                continue;
            }
            [idsToDelete addObject:task.identifier];
            addedChild = YES;
        }
    }

    NSIndexSet *indexes = [self.tasks indexesOfObjectsPassingTest:^BOOL(TDTodoTask *task, NSUInteger idx, BOOL *stop) {
        (void)idx;
        (void)stop;
        return [idsToDelete containsObject:task.identifier];
    }];
    if (indexes.count > 0) {
        [self.tasks removeObjectsAtIndexes:indexes];
    }
}

- (BOOL)renameCustomListWithID:(NSString *)listID name:(NSString *)name {
    TDCustomList *list = [self customListWithID:listID];
    if (list == nil) {
        return NO;
    }

    NSString *trimmedName = [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedName.length == 0) {
        return NO;
    }

    list.name = trimmedName;
    return YES;
}

- (BOOL)deleteCustomListWithID:(NSString *)listID {
    TDCustomList *list = [self customListWithID:listID];
    if (list == nil) {
        return NO;
    }

    NSIndexSet *listIndexes = [self.customLists indexesOfObjectsPassingTest:^BOOL(TDCustomList *candidate, NSUInteger idx, BOOL *stop) {
        (void)idx;
        (void)stop;
        return [candidate.identifier isEqualToString:listID];
    }];
    [self.customLists removeObjectsAtIndexes:listIndexes];

    NSIndexSet *taskIndexes = [self.tasks indexesOfObjectsPassingTest:^BOOL(TDTodoTask *task, NSUInteger idx, BOOL *stop) {
        (void)idx;
        (void)stop;
        return [task.listID isEqualToString:listID];
    }];
    if (taskIndexes.count > 0) {
        [self.tasks removeObjectsAtIndexes:taskIndexes];
    }
    return YES;
}

- (NSArray<TDTodoTask *> *)childrenForTaskID:(NSString *)taskID {
    NSMutableArray<TDTodoTask *> *children = [NSMutableArray array];
    for (TDTodoTask *task in self.tasks) {
        if ([task.parentTaskID isEqualToString:taskID]) {
            [children addObject:task];
        }
    }
    [children sortUsingComparator:^NSComparisonResult(TDTodoTask *left, TDTodoTask *right) {
        return [self compareTaskOrder:left other:right];
    }];
    return children;
}

- (NSArray<TDTodoTask *> *)descendantsForTaskID:(NSString *)taskID {
    NSMutableArray<TDTodoTask *> *descendants = [NSMutableArray array];
    NSMutableArray<NSString *> *pendingParentIDs = [NSMutableArray arrayWithObject:taskID];
    while (pendingParentIDs.count > 0) {
        NSString *parentID = pendingParentIDs.firstObject;
        [pendingParentIDs removeObjectAtIndex:0];
        NSArray<TDTodoTask *> *children = [self childrenForTaskID:parentID];
        for (TDTodoTask *child in children) {
            [descendants addObject:child];
            [pendingParentIDs addObject:child.identifier];
        }
    }
    return descendants;
}

- (NSArray<TDTodoTask *> *)moveTasksBackToToday:(NSArray<TDTodoTask *> *)tasks
                                            now:(NSDate *)now
                                       calendar:(NSCalendar *)calendar {
    return [self moveTasksBackToToday:tasks now:now calendar:calendar todayCutoffMinutes:0];
}

- (NSArray<TDTodoTask *> *)moveTasksBackToToday:(NSArray<TDTodoTask *> *)tasks
                                            now:(NSDate *)now
                                       calendar:(NSCalendar *)calendar
                             todayCutoffMinutes:(NSInteger)todayCutoffMinutes {
    NSDate *todayStart = [TDTodoList dayStartForDate:now offset:0 calendar:calendar todayCutoffMinutes:todayCutoffMinutes];
    NSMutableArray<TDTodoTask *> *movedTasks = [NSMutableArray array];
    for (TDTodoTask *task in tasks) {
        if (task.bucket != TDTaskBucketToday || task.completedAt != nil || ![self dueDate:task.dueDate isBefore:todayStart]) {
            continue;
        }
        task.dueDate = todayStart;
        [movedTasks addObject:task];
    }
    return movedTasks;
}

- (void)retargetTasksWithIDs:(NSArray<NSString *> *)taskIDs
                 toDayOffset:(NSInteger)dayOffset
                         now:(NSDate *)now
                    calendar:(NSCalendar *)calendar
          todayCutoffMinutes:(NSInteger)todayCutoffMinutes {
    if (taskIDs.count == 0) {
        return;
    }

    NSSet<NSString *> *taskIDSet = [NSSet setWithArray:taskIDs];
    NSDate *dueDate = [TDTodoList dayStartForDate:now offset:dayOffset calendar:calendar todayCutoffMinutes:todayCutoffMinutes];
    for (TDTodoTask *task in self.tasks) {
        if (![taskIDSet containsObject:task.identifier] || task.bucket != TDTaskBucketToday) {
            continue;
        }
        task.dueDate = dueDate;
    }
}

- (void)moveVisibleTaskFromIndex:(NSUInteger)sourceIndex
                         toIndex:(NSUInteger)destinationIndex
                             tab:(TDTaskTab)tab
                             now:(NSDate *)now
                        calendar:(NSCalendar *)calendar {
    [self moveVisibleTaskFromIndex:sourceIndex
                           toIndex:destinationIndex
                               tab:tab
                               now:now
                          calendar:calendar
                todayCutoffMinutes:0];
}

- (void)moveVisibleTaskFromIndex:(NSUInteger)sourceIndex
                         toIndex:(NSUInteger)destinationIndex
                             tab:(TDTaskTab)tab
                             now:(NSDate *)now
                        calendar:(NSCalendar *)calendar
              todayCutoffMinutes:(NSInteger)todayCutoffMinutes {
    NSMutableArray<TDTodoTask *> *visible = [[self tasksForTab:tab now:now calendar:calendar todayCutoffMinutes:todayCutoffMinutes] mutableCopy];
    if (sourceIndex >= visible.count) {
        return;
    }

    TDTodoTask *movingTask = visible[sourceIndex];
    [visible removeObjectAtIndex:sourceIndex];
    NSUInteger insertionIndex = MIN(destinationIndex, visible.count);
    [visible insertObject:movingTask atIndex:insertionIndex];

    [visible enumerateObjectsUsingBlock:^(TDTodoTask *task, NSUInteger index, BOOL *stop) {
        (void)stop;
        task.sortOrder = (NSInteger)index;
    }];
}

- (void)moveVisibleTaskFromIndex:(NSUInteger)sourceIndex
                         toIndex:(NSUInteger)destinationIndex
                    customListID:(NSString *)customListID {
    NSMutableArray<TDTodoTask *> *visible = [[self tasksForCustomListID:customListID] mutableCopy];
    if (sourceIndex >= visible.count) {
        return;
    }

    TDTodoTask *movingTask = visible[sourceIndex];
    [visible removeObjectAtIndex:sourceIndex];
    NSUInteger insertionIndex = MIN(destinationIndex, visible.count);
    [visible insertObject:movingTask atIndex:insertionIndex];

    [visible enumerateObjectsUsingBlock:^(TDTodoTask *task, NSUInteger index, BOOL *stop) {
        (void)stop;
        task.sortOrder = (NSInteger)index;
    }];
}

- (NSInteger)nextSortOrderForBucket:(TDTaskBucket)bucket dueDate:(NSDate *)dueDate listID:(NSString *)listID {
    NSInteger maximumOrder = -1;
    for (TDTodoTask *task in self.tasks) {
        BOOL sameDueDate = TDValuesEqual(task.dueDate, dueDate);
        BOOL sameList = TDValuesEqual(task.listID, listID);
        if (task.parentTaskID.length == 0 && task.bucket == bucket && sameDueDate && sameList && task.sortOrder > maximumOrder) {
            maximumOrder = task.sortOrder;
        }
    }
    return maximumOrder + 1;
}

- (NSInteger)nextSortOrderForParentTaskID:(NSString *)parentTaskID {
    NSInteger maximumOrder = -1;
    for (TDTodoTask *task in self.tasks) {
        if ([task.parentTaskID isEqualToString:parentTaskID] && task.sortOrder > maximumOrder) {
            maximumOrder = task.sortOrder;
        }
    }
    return maximumOrder + 1;
}

- (NSInteger)nextCustomListSortOrder {
    NSInteger maximumOrder = -1;
    for (TDCustomList *list in self.customLists) {
        if (list.sortOrder > maximumOrder) {
            maximumOrder = list.sortOrder;
        }
    }
    return maximumOrder + 1;
}

- (TDTodoTask *)taskWithID:(NSString *)taskID {
    for (TDTodoTask *task in self.tasks) {
        if ([task.identifier isEqualToString:taskID]) {
            return task;
        }
    }
    return nil;
}

- (TDCustomList *)customListWithID:(NSString *)listID {
    for (TDCustomList *list in self.customLists) {
        if ([list.identifier isEqualToString:listID]) {
            return list;
        }
    }
    return nil;
}

- (TDTodoTask *)rootParentTaskForTask:(TDTodoTask *)task {
    if (task == nil) {
        return nil;
    }
    if (task.parentTaskID.length == 0) {
        return task;
    }
    TDTodoTask *parent = [self taskWithID:task.parentTaskID];
    return parent ?: task;
}

- (NSArray<TDTodoTask *> *)hierarchicalTasksFromFilteredTasks:(NSArray<TDTodoTask *> *)filteredTasks comparator:(NSComparator)comparator {
    NSMutableDictionary<NSString *, NSMutableArray<TDTodoTask *> *> *childrenByParentID = [NSMutableDictionary dictionary];
    NSMutableArray<TDTodoTask *> *rootTasks = [NSMutableArray array];
    NSMutableSet<NSString *> *filteredIDs = [NSMutableSet set];
    for (TDTodoTask *task in filteredTasks) {
        [filteredIDs addObject:task.identifier];
    }

    for (TDTodoTask *task in filteredTasks) {
        if (task.parentTaskID.length > 0 && [filteredIDs containsObject:task.parentTaskID]) {
            NSMutableArray<TDTodoTask *> *children = childrenByParentID[task.parentTaskID];
            if (children == nil) {
                children = [NSMutableArray array];
                childrenByParentID[task.parentTaskID] = children;
            }
            [children addObject:task];
        } else {
            [rootTasks addObject:task];
        }
    }

    [rootTasks sortUsingComparator:comparator];
    NSMutableArray<TDTodoTask *> *result = [NSMutableArray array];
    for (TDTodoTask *root in rootTasks) {
        [result addObject:root];
        NSArray<TDTodoTask *> *rootChildren = childrenByParentID[root.identifier] ?: @[];
        NSArray<TDTodoTask *> *children = [rootChildren sortedArrayUsingComparator:^NSComparisonResult(TDTodoTask *left, TDTodoTask *right) {
            return [self compareTaskOrder:left other:right];
        }];
        [result addObjectsFromArray:children];
    }
    return result;
}

- (BOOL)dueDate:(NSDate *)dueDate isBefore:(NSDate *)todayStart {
    return dueDate != nil && [dueDate compare:todayStart] == NSOrderedAscending;
}

- (NSComparisonResult)compareTaskOrder:(TDTodoTask *)left other:(TDTodoTask *)right {
    if (left.sortOrder < right.sortOrder) {
        return NSOrderedAscending;
    }
    if (left.sortOrder > right.sortOrder) {
        return NSOrderedDescending;
    }
    return [left.createdAt compare:right.createdAt];
}

@end
