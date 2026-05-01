#import <Foundation/Foundation.h>
#import "TDCustomList.h"
#import "TDTodoList.h"
#import "TDTaskFileStore.h"
#import "TDTimeFormatting.h"

static NSUInteger failures = 0;

#define TDAssert(condition, message) \
    do { \
        if (!(condition)) { \
            failures += 1; \
            fprintf(stderr, "FAIL: %s:%d %s\n", __FILE__, __LINE__, message); \
        } \
    } while (0)

#define TDAssertEqualObjects(actual, expected, message) \
    TDAssert([(actual) isEqual:(expected)], message)

static NSCalendar *HongKongCalendar(void) {
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    calendar.timeZone = [NSTimeZone timeZoneWithName:@"Asia/Hong_Kong"];
    return calendar;
}

static NSDate *DateAtMinute(NSUInteger year, NSUInteger month, NSUInteger day, NSUInteger hour, NSUInteger minute);

static NSDate *DateAt(NSUInteger year, NSUInteger month, NSUInteger day, NSUInteger hour) {
    return DateAtMinute(year, month, day, hour, 0);
}

static NSDate *DateAtMinute(NSUInteger year, NSUInteger month, NSUInteger day, NSUInteger hour, NSUInteger minute) {
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.calendar = HongKongCalendar();
    components.timeZone = HongKongCalendar().timeZone;
    components.year = (NSInteger)year;
    components.month = (NSInteger)month;
    components.day = (NSInteger)day;
    components.hour = (NSInteger)hour;
    components.minute = (NSInteger)minute;
    return [components date];
}

static TDTodoTask *Task(NSString *title, NSDate *dueDate, NSDate *completedAt, TDTaskBucket bucket, NSInteger sortOrder) {
    return [[TDTodoTask alloc] initWithIdentifier:[NSUUID UUID].UUIDString
                                           title:title
                                       createdAt:DateAt(2026, 4, 29, 8)
                                         dueDate:dueDate
                                     completedAt:completedAt
                                          bucket:bucket
                                       sortOrder:sortOrder];
}

static NSArray<NSString *> *TaskIDs(NSArray<TDTodoTask *> *tasks) {
    NSMutableArray<NSString *> *ids = [NSMutableArray arrayWithCapacity:tasks.count];
    for (TDTodoTask *task in tasks) {
        [ids addObject:task.identifier];
    }
    return ids;
}

static void TestTodayTabIncludesOnlyTodayBucketTasksDueTodayAndSortsByOrder(void) {
    NSDate *now = DateAt(2026, 4, 29, 9);
    NSDate *todayDue = [HongKongCalendar() startOfDayForDate:now];
    NSDate *yesterdayDue = DateAt(2026, 4, 28, 0);
    TDTodoTask *first = Task(@"first", todayDue, nil, TDTaskBucketToday, 1);
    TDTodoTask *second = Task(@"second", todayDue, nil, TDTaskBucketToday, 0);
    TDTodoTask *expired = Task(@"expired", yesterdayDue, nil, TDTaskBucketToday, 2);
    TDTodoTask *custom = Task(@"custom", nil, nil, TDTaskBucketCustom, 3);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[first, second, expired, custom]];

    NSArray *result = TaskIDs([list tasksForTab:TDTaskTabToday now:now calendar:HongKongCalendar()]);

    TDAssertEqualObjects(result, (@[second.identifier, first.identifier]), "today tab should include only due-today tasks sorted by order");
}

static void TestTomorrowTabIncludesNextActiveDayTasks(void) {
    NSCalendar *calendar = HongKongCalendar();
    NSDate *now = DateAt(2026, 4, 29, 9);
    NSDate *todayDue = [calendar startOfDayForDate:now];
    NSDate *tomorrowDue = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:todayDue options:0];
    TDTodoTask *today = Task(@"today", todayDue, nil, TDTaskBucketToday, 0);
    TDTodoTask *tomorrowFirst = Task(@"tomorrow first", tomorrowDue, nil, TDTaskBucketToday, 1);
    TDTodoTask *tomorrowSecond = Task(@"tomorrow second", tomorrowDue, nil, TDTaskBucketToday, 0);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[tomorrowFirst, today, tomorrowSecond]];

    NSArray *result = TaskIDs([list tasksForTab:TDTaskTabTomorrow now:now calendar:calendar todayCutoffMinutes:0]);

    TDAssertEqualObjects(result, (@[tomorrowSecond.identifier, tomorrowFirst.identifier]), "tomorrow tab should include next active day tasks sorted by order");
}

static void TestCutoffKeepsEarlyMorningInPreviousActiveDay(void) {
    NSCalendar *calendar = HongKongCalendar();
    NSDate *now = DateAt(2026, 4, 30, 1);
    NSDate *activeToday = DateAt(2026, 4, 29, 0);
    NSDate *activeTomorrow = DateAt(2026, 4, 30, 0);
    TDTodoTask *today = Task(@"late work", activeToday, nil, TDTaskBucketToday, 0);
    TDTodoTask *tomorrow = Task(@"morning work", activeTomorrow, nil, TDTaskBucketToday, 0);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[tomorrow, today]];

    NSArray *todayResult = TaskIDs([list tasksForTab:TDTaskTabToday now:now calendar:calendar todayCutoffMinutes:360]);
    NSArray *tomorrowResult = TaskIDs([list tasksForTab:TDTaskTabTomorrow now:now calendar:calendar todayCutoffMinutes:360]);

    TDAssertEqualObjects(todayResult, (@[today.identifier]), "0600 cutoff should keep 1am tasks in the previous active day");
    TDAssertEqualObjects(tomorrowResult, (@[tomorrow.identifier]), "0600 cutoff should make tomorrow start at the coming 6am boundary");
}

static void TestTomorrowTasksRollIntoTodayAfterCutoff(void) {
    NSCalendar *calendar = HongKongCalendar();
    NSDate *beforeCutoff = DateAt(2026, 4, 30, 1);
    NSDate *afterCutoff = DateAt(2026, 4, 30, 6);
    NSDate *tomorrowDue = DateAt(2026, 4, 30, 0);
    TDTodoTask *task = Task(@"planned tomorrow", tomorrowDue, nil, TDTaskBucketToday, 0);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[task]];

    NSArray *beforeResult = TaskIDs([list tasksForTab:TDTaskTabTomorrow now:beforeCutoff calendar:calendar todayCutoffMinutes:360]);
    NSArray *afterResult = TaskIDs([list tasksForTab:TDTaskTabToday now:afterCutoff calendar:calendar todayCutoffMinutes:360]);

    TDAssertEqualObjects(beforeResult, (@[task.identifier]), "task due next active day should show in tomorrow before cutoff");
    TDAssertEqualObjects(afterResult, (@[task.identifier]), "tomorrow task should roll into today at cutoff");
}

static void TestAddTomorrowTaskUsesNextActiveDayDueDate(void) {
    NSCalendar *calendar = HongKongCalendar();
    NSDate *now = DateAt(2026, 4, 30, 1);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[]];

    TDTodoTask *task = [list addTaskWithTitle:@"prep" bucket:TDTaskBucketToday estimatedMinutes:0 dayOffset:1 now:now calendar:calendar todayCutoffMinutes:360];

    TDAssertEqualObjects(task.dueDate, DateAt(2026, 4, 30, 0), "tomorrow task should store the next active day anchor");
}

static void TestRetargetTasksKeepsTodayAndTomorrowAfterCutoffChange(void) {
    NSCalendar *calendar = HongKongCalendar();
    NSDate *now = DateAt(2026, 4, 30, 1);
    TDTodoTask *today = Task(@"old today", DateAt(2026, 4, 30, 0), nil, TDTaskBucketToday, 0);
    TDTodoTask *tomorrow = Task(@"old tomorrow", DateAt(2026, 5, 1, 0), nil, TDTaskBucketToday, 0);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[today, tomorrow]];
    NSArray *todayIDs = TaskIDs([list tasksForTab:TDTaskTabToday now:now calendar:calendar todayCutoffMinutes:0]);
    NSArray *tomorrowIDs = TaskIDs([list tasksForTab:TDTaskTabTomorrow now:now calendar:calendar todayCutoffMinutes:0]);

    [list retargetTasksWithIDs:todayIDs toDayOffset:0 now:now calendar:calendar todayCutoffMinutes:360];
    [list retargetTasksWithIDs:tomorrowIDs toDayOffset:1 now:now calendar:calendar todayCutoffMinutes:360];

    TDAssertEqualObjects(TaskIDs([list tasksForTab:TDTaskTabToday now:now calendar:calendar todayCutoffMinutes:360]), (@[today.identifier]), "current today tasks should stay in today after changing cutoff");
    TDAssertEqualObjects(TaskIDs([list tasksForTab:TDTaskTabTomorrow now:now calendar:calendar todayCutoffMinutes:360]), (@[tomorrow.identifier]), "current tomorrow tasks should stay in tomorrow after changing cutoff");
    TDAssertEqualObjects(today.dueDate, DateAt(2026, 4, 29, 0), "today task should retarget to new active day anchor");
    TDAssertEqualObjects(tomorrow.dueDate, DateAt(2026, 4, 30, 0), "tomorrow task should retarget to new next active day anchor");
}

static void TestCustomTasksIgnoreTodayCutoff(void) {
    NSCalendar *calendar = HongKongCalendar();
    NSDate *now = DateAt(2026, 4, 30, 1);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    TDCustomList *customList = [list addCustomListNamed:@"ideas" now:now];
    TDTodoTask *custom = [list addTaskWithTitle:@"someday" customListID:customList.identifier now:now];

    NSArray *todayResult = TaskIDs([list tasksForTab:TDTaskTabToday now:now calendar:calendar todayCutoffMinutes:360]);
    NSArray *tomorrowResult = TaskIDs([list tasksForTab:TDTaskTabTomorrow now:now calendar:calendar todayCutoffMinutes:360]);
    NSArray *customResult = TaskIDs([list tasksForCustomListID:customList.identifier]);

    TDAssert(custom.dueDate == nil, "custom task should not receive a due date under cutoff rules");
    TDAssertEqualObjects(todayResult, (@[]), "custom task should not appear in today under cutoff rules");
    TDAssertEqualObjects(tomorrowResult, (@[]), "custom task should not appear in tomorrow under cutoff rules");
    TDAssertEqualObjects(customResult, (@[custom.identifier]), "custom task should remain in its custom list");
}

static void TestMoveBackToTodayUsesCutoffActiveDay(void) {
    NSCalendar *calendar = HongKongCalendar();
    NSDate *now = DateAt(2026, 4, 30, 1);
    TDTodoTask *overdue = Task(@"overdue", DateAt(2026, 4, 28, 0), nil, TDTaskBucketToday, 0);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[overdue]];

    NSArray<TDTodoTask *> *moved = [list moveTasksBackToToday:@[overdue] now:now calendar:calendar todayCutoffMinutes:360];

    TDAssertEqualObjects(TaskIDs(moved), (@[overdue.identifier]), "move back should move overdue items with custom cutoff");
    TDAssertEqualObjects(overdue.dueDate, DateAt(2026, 4, 29, 0), "move back should retarget to the active day anchor before cutoff");
}

static void TestPastIncompleteIncludesExpiredUnfinishedTodayTasksOnly(void) {
    NSDate *now = DateAt(2026, 4, 29, 10);
    NSDate *yesterday = DateAt(2026, 4, 28, 0);
    TDTodoTask *unfinished = Task(@"unfinished", yesterday, nil, TDTaskBucketToday, 0);
    TDTodoTask *completed = Task(@"completed", yesterday, now, TDTaskBucketToday, 0);
    TDTodoTask *custom = Task(@"custom", nil, nil, TDTaskBucketCustom, 0);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[completed, custom, unfinished]];

    NSArray *result = TaskIDs([list tasksForTab:TDTaskTabPastIncomplete now:now calendar:HongKongCalendar()]);

    TDAssertEqualObjects(result, (@[unfinished.identifier]), "past incomplete should include expired unfinished today tasks only");
}

static void TestPastCompletedOrdersByCompletedAtDescending(void) {
    NSDate *now = DateAt(2026, 4, 29, 10);
    NSDate *yesterday = DateAt(2026, 4, 28, 0);
    TDTodoTask *older = Task(@"older", yesterday, DateAt(2026, 4, 28, 18), TDTaskBucketToday, 0);
    TDTodoTask *newer = Task(@"newer", yesterday, DateAt(2026, 4, 29, 8), TDTaskBucketToday, 0);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[older, newer]];

    NSArray *result = TaskIDs([list tasksForTab:TDTaskTabPastCompleted now:now calendar:HongKongCalendar()]);

    TDAssertEqualObjects(result, (@[newer.identifier, older.identifier]), "past completed should sort newest completion first");
}

static void TestCustomIncludesCustomTasksRegardlessOfCompletion(void) {
    NSDate *now = DateAt(2026, 4, 29, 10);
    NSString *listID = @"default-custom";
    TDTodoTask *customDone = Task(@"done", nil, now, TDTaskBucketCustom, 1);
    customDone.listID = listID;
    TDTodoTask *customOpen = Task(@"open", nil, nil, TDTaskBucketCustom, 0);
    customOpen.listID = listID;
    TDTodoTask *today = Task(@"today", [HongKongCalendar() startOfDayForDate:now], nil, TDTaskBucketToday, 2);
    TDCustomList *customList = [[TDCustomList alloc] initWithIdentifier:listID name:@"自定義" createdAt:now sortOrder:0];
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[customDone, today, customOpen] customLists:@[customList]];

    NSArray *result = TaskIDs([list tasksForCustomListID:listID]);

    TDAssertEqualObjects(result, (@[customOpen.identifier, customDone.identifier]), "custom tab should include custom tasks sorted by order");
}

static void TestMultipleCustomListsKeepTasksSeparate(void) {
    NSDate *now = DateAt(2026, 4, 29, 11);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    TDCustomList *work = [list addCustomListNamed:@"工作" now:now];
    TDCustomList *shopping = [list addCustomListNamed:@"購物" now:now];

    TDTodoTask *workTask = [list addTaskWithTitle:@"send deck" customListID:work.identifier now:now];
    TDTodoTask *shoppingTask = [list addTaskWithTitle:@"buy tea" customListID:shopping.identifier now:now];

    TDAssert(workTask.bucket == TDTaskBucketCustom && workTask.dueDate == nil, "custom list task should never expire");
    TDAssertEqualObjects(TaskIDs([list tasksForCustomListID:work.identifier]), (@[workTask.identifier]), "work list should only include work tasks");
    TDAssertEqualObjects(TaskIDs([list tasksForCustomListID:shopping.identifier]), (@[shoppingTask.identifier]), "shopping list should only include shopping tasks");
}

static void TestAddingCustomTaskAfterTodayTaskKeepsNilDatesSafe(void) {
    NSDate *now = DateAt(2026, 4, 29, 11);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    TDCustomList *customList = [list addCustomListNamed:@"工作" now:now];
    TDTodoTask *todayTask = [list addTaskWithTitle:@"today" bucket:TDTaskBucketToday now:now calendar:HongKongCalendar()];

    TDTodoTask *firstCustomTask = [list addTaskWithTitle:@"first custom" customListID:customList.identifier now:now];
    TDTodoTask *secondCustomTask = [list addTaskWithTitle:@"second custom" customListID:customList.identifier now:now];

    TDAssert(todayTask.dueDate != nil, "today task should keep a due date");
    TDAssert(firstCustomTask.dueDate == nil && secondCustomTask.dueDate == nil, "custom list tasks should keep nil due dates");
    TDAssert(firstCustomTask.sortOrder == 0 && secondCustomTask.sortOrder == 1, "custom list tasks should sort independently from dated today tasks");
}

static void TestAddSetsTodayDueDateButLeavesCustomWithoutDueDate(void) {
    NSDate *now = DateAt(2026, 4, 29, 22);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[]];

    TDTodoTask *today = [list addTaskWithTitle:@"finish draft" bucket:TDTaskBucketToday now:now calendar:HongKongCalendar()];
    TDTodoTask *custom = [list addTaskWithTitle:@"someday" bucket:TDTaskBucketCustom now:now calendar:HongKongCalendar()];

    TDAssertEqualObjects(today.dueDate, [HongKongCalendar() startOfDayForDate:now], "today task should get today's due date");
    TDAssert(custom.dueDate == nil, "custom task should not get due date");
    TDAssert(today.sortOrder == 0 && custom.sortOrder == 0, "first task in each bucket should start at sort order zero");
}

static void TestTaskEqualityHandlesOneSidedOptionalValues(void) {
    NSDate *now = DateAt(2026, 4, 29, 8);
    TDTodoTask *withoutOptionals = [[TDTodoTask alloc] initWithIdentifier:@"same"
                                                                    title:@"task"
                                                                createdAt:now
                                                                  dueDate:nil
                                                              completedAt:nil
                                                                   bucket:TDTaskBucketToday
                                                                   listID:nil
                                                            parentTaskID:nil
                                                        estimatedMinutes:0
                                                               sortOrder:0];
    TDTodoTask *withOptionals = [[TDTodoTask alloc] initWithIdentifier:@"same"
                                                                 title:@"task"
                                                             createdAt:now
                                                               dueDate:now
                                                           completedAt:nil
                                                                bucket:TDTaskBucketToday
                                                                listID:@"list"
                                                         parentTaskID:nil
                                                     estimatedMinutes:0
                                                            sortOrder:0];

    TDAssert(![withoutOptionals isEqual:withOptionals], "task equality should safely compare one-sided optional fields");
    TDAssert(![withOptionals isEqual:withoutOptionals], "task equality should stay symmetric for one-sided optional fields");
}

static void TestEstimatedDurationDefaultsAndPersists(void) {
    NSDate *now = DateAt(2026, 4, 29, 22);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    TDCustomList *customList = [list addCustomListNamed:@"工作" now:now];

    TDTodoTask *defaultTask = [list addTaskWithTitle:@"no estimate" bucket:TDTaskBucketToday now:now calendar:HongKongCalendar()];
    TDTodoTask *estimatedTask = [list addTaskWithTitle:@"timed" customListID:customList.identifier estimatedMinutes:95 now:now];
    NSDictionary *dictionary = [estimatedTask dictionaryRepresentation];
    TDTodoTask *loaded = [TDTodoTask taskWithDictionaryRepresentation:dictionary];

    TDAssert(defaultTask.estimatedMinutes == 0, "estimated duration should default to zero");
    TDAssert(estimatedTask.estimatedMinutes == 95, "custom task should store estimated minutes");
    TDAssert(loaded.estimatedMinutes == 95, "estimated minutes should round trip through JSON");
}

static void TestSubtasksPersistAndRenderAfterParent(void) {
    NSDate *now = DateAt(2026, 4, 29, 22);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    TDTodoTask *first = [list addTaskWithTitle:@"first" bucket:TDTaskBucketToday now:now calendar:HongKongCalendar()];
    TDTodoTask *second = [list addTaskWithTitle:@"second" bucket:TDTaskBucketToday now:now calendar:HongKongCalendar()];
    TDTodoTask *subtask = [list addSubtaskWithTitle:@"child" parentTaskID:first.identifier estimatedMinutes:15 now:now];
    TDTodoTask *loaded = [TDTodoTask taskWithDictionaryRepresentation:[subtask dictionaryRepresentation]];

    NSArray *result = TaskIDs([list tasksForTab:TDTaskTabToday now:now calendar:HongKongCalendar()]);

    TDAssertEqualObjects(result, (@[first.identifier, subtask.identifier, second.identifier]), "subtask should render directly under parent");
    TDAssertEqualObjects(subtask.parentTaskID, first.identifier, "subtask should store parent task id");
    TDAssertEqualObjects(loaded.parentTaskID, first.identifier, "parent task id should round trip through JSON");
    TDAssert(subtask.estimatedMinutes == 15, "subtask estimated minutes should be stored");
}

static void TestRenameTaskTrimsTitleAndIgnoresBlankNames(void) {
    NSDate *now = DateAt(2026, 4, 29, 22);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    TDTodoTask *task = [list addTaskWithTitle:@"old" bucket:TDTaskBucketToday now:now calendar:HongKongCalendar()];

    BOOL renamed = [list renameTaskWithID:task.identifier title:@"  new name  "];
    BOOL blankRenamed = [list renameTaskWithID:task.identifier title:@"   "];

    TDAssert(renamed, "rename should return YES for nonblank titles");
    TDAssert(!blankRenamed, "rename should return NO for blank titles");
    TDAssertEqualObjects(task.title, @"new name", "rename should trim and store task title");
}

static void TestTaskDescriptionUpdatesAndRoundTripsJSON(void) {
    NSDate *now = DateAt(2026, 4, 29, 22);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    TDTodoTask *task = [list addTaskWithTitle:@"task" bucket:TDTaskBucketToday now:now calendar:HongKongCalendar()];

    BOOL updated = [list updateDescriptionForTaskID:task.identifier description:@"  context note  "];
    TDTodoTask *loaded = [TDTodoTask taskWithDictionaryRepresentation:[task dictionaryRepresentation]];
    BOOL cleared = [list updateDescriptionForTaskID:task.identifier description:@"   "];

    TDAssert(updated, "description update should return YES for existing task");
    TDAssertEqualObjects(loaded.taskDescription, @"context note", "task description should trim and round trip through JSON");
    TDAssert(cleared, "blank description should still update existing task");
    TDAssert(task.taskDescription == nil, "blank description should clear existing description");
}

static void TestTaskDetailsUpdateDescriptionAndEstimate(void) {
    NSDate *now = DateAt(2026, 4, 29, 22);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    TDTodoTask *task = [list addTaskWithTitle:@"task" bucket:TDTaskBucketToday estimatedMinutes:10 now:now calendar:HongKongCalendar()];

    BOOL updated = [list updateDetailsForTaskID:task.identifier description:@"  context note  " estimatedMinutes:75];
    BOOL missingUpdated = [list updateDetailsForTaskID:@"missing" description:@"ignored" estimatedMinutes:20];

    TDAssert(updated, "details update should return YES for existing task");
    TDAssert(!missingUpdated, "details update should return NO for missing task");
    TDAssertEqualObjects(task.taskDescription, @"context note", "details update should trim and store description");
    TDAssert(task.estimatedMinutes == 75, "details update should store estimated minutes");
}

static void TestSubtaskDetailsUpdateDescriptionAndEstimate(void) {
    NSDate *now = DateAt(2026, 4, 29, 22);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    TDTodoTask *parent = [list addTaskWithTitle:@"parent" bucket:TDTaskBucketToday now:now calendar:HongKongCalendar()];
    TDTodoTask *subtask = [list addSubtaskWithTitle:@"child" parentTaskID:parent.identifier estimatedMinutes:15 now:now];

    BOOL updated = [list updateDetailsForTaskID:subtask.identifier description:@"   " estimatedMinutes:-30];

    TDAssert(updated, "subtask details update should return YES for existing subtask");
    TDAssert(subtask.taskDescription == nil, "blank details description should clear subtask description");
    TDAssert(subtask.estimatedMinutes == 0, "negative estimated minutes should clamp to zero for subtasks");
}

static void TestSubtaskFromSubtaskCreatesSiblingUnderRootParent(void) {
    NSDate *now = DateAt(2026, 4, 29, 22);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    TDTodoTask *parent = [list addTaskWithTitle:@"parent" bucket:TDTaskBucketToday now:now calendar:HongKongCalendar()];
    TDTodoTask *firstChild = [list addSubtaskWithTitle:@"child one" parentTaskID:parent.identifier now:now];

    TDTodoTask *secondChild = [list addSubtaskWithTitle:@"child two" parentTaskID:firstChild.identifier now:now];
    NSArray<TDTodoTask *> *children = [list childrenForTaskID:parent.identifier];

    TDAssertEqualObjects(secondChild.parentTaskID, parent.identifier, "subtask created from subtask should become a sibling under root parent");
    TDAssertEqualObjects(TaskIDs(children), (@[firstChild.identifier, secondChild.identifier]), "children lookup should return siblings in sort order");
}

static void TestRenameAndDeleteCustomList(void) {
    NSDate *now = DateAt(2026, 4, 29, 22);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    TDCustomList *customList = [list addCustomListNamed:@"工作" now:now];
    TDTodoTask *parent = [list addTaskWithTitle:@"parent" customListID:customList.identifier now:now];
    [list addSubtaskWithTitle:@"child" parentTaskID:parent.identifier now:now];

    BOOL renamed = [list renameCustomListWithID:customList.identifier name:@"  學習  "];
    BOOL blankRenamed = [list renameCustomListWithID:customList.identifier name:@"   "];
    BOOL deleted = [list deleteCustomListWithID:customList.identifier];

    TDAssert(renamed, "custom list rename should return YES for nonblank names");
    TDAssert(!blankRenamed, "custom list rename should reject blank names");
    TDAssertEqualObjects(customList.name, @"學習", "custom list rename should trim and store name");
    TDAssert(deleted, "custom list delete should return YES for an existing list");
    TDAssert(list.customLists.count == 0, "custom list delete should remove the list");
    TDAssert(list.tasks.count == 0, "custom list delete should remove tasks and subtasks in the list");
}

static void TestDeletingParentDeletesSubtasks(void) {
    NSDate *now = DateAt(2026, 4, 29, 22);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    TDTodoTask *parent = [list addTaskWithTitle:@"parent" bucket:TDTaskBucketToday now:now calendar:HongKongCalendar()];
    [list addSubtaskWithTitle:@"child" parentTaskID:parent.identifier now:now];

    [list deleteTaskWithID:parent.identifier];

    TDAssert(list.tasks.count == 0, "deleting a parent should delete its subtasks");
}

static void TestMoveVisiblePastIncompleteTasksBackToToday(void) {
    NSDate *now = DateAt(2026, 4, 29, 22);
    NSDate *yesterday = DateAt(2026, 4, 28, 0);
    NSCalendar *calendar = HongKongCalendar();
    TDTodoTask *overdue = Task(@"overdue", yesterday, nil, TDTaskBucketToday, 0);
    TDTodoTask *completed = Task(@"completed", yesterday, now, TDTaskBucketToday, 1);
    TDTodoTask *custom = Task(@"custom", nil, nil, TDTaskBucketCustom, 2);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[overdue, completed, custom]];

    NSArray<TDTodoTask *> *moved = [list moveTasksBackToToday:@[overdue, completed, custom] now:now calendar:calendar];

    TDAssertEqualObjects(TaskIDs(moved), (@[overdue.identifier]), "daily review should only move overdue incomplete today tasks");
    TDAssertEqualObjects(overdue.dueDate, [calendar startOfDayForDate:now], "moved task should receive today's due date");
    TDAssertEqualObjects(completed.dueDate, yesterday, "completed overdue task should stay in history");
    TDAssert(custom.dueDate == nil, "custom tasks should never receive a due date");
}

static void TestRemainingTimeTextFormatsCountdownSeconds(void) {
    TDAssertEqualObjects(TDRemainingTimeTextForSeconds(90), @"剩餘 1:30", "remaining time should format minutes and seconds");
    TDAssertEqualObjects(TDRemainingTimeTextForSeconds(3661), @"剩餘 1:01:01", "remaining time should include hours when needed");
    TDAssertEqualObjects(TDRemainingTimeTextForSeconds(-2), @"剩餘 0:00", "remaining time should clamp negative seconds to zero");
}

static void TestToggleCompletionSetsAndClearsCompletedAt(void) {
    TDTodoTask *task = Task(@"toggle", nil, nil, TDTaskBucketToday, 0);
    NSDate *completedAt = DateAt(2026, 4, 29, 20);
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[task]];

    [list toggleCompletionForTaskID:task.identifier atDate:completedAt];
    TDAssertEqualObjects(task.completedAt, completedAt, "toggle should set completedAt");

    [list toggleCompletionForTaskID:task.identifier atDate:[completedAt dateByAddingTimeInterval:60]];
    TDAssert(task.completedAt == nil, "second toggle should clear completedAt");
}

static void TestMoveVisibleTasksUpdatesOnlyVisibleSortOrders(void) {
    TDTodoTask *hidden = Task(@"hidden", nil, nil, TDTaskBucketToday, 99);
    TDTodoTask *first = Task(@"first", nil, nil, TDTaskBucketCustom, 0);
    first.listID = @"default-custom";
    TDTodoTask *second = Task(@"second", nil, nil, TDTaskBucketCustom, 1);
    second.listID = @"default-custom";
    TDTodoTask *third = Task(@"third", nil, nil, TDTaskBucketCustom, 2);
    third.listID = @"default-custom";
    TDCustomList *customList = [[TDCustomList alloc] initWithIdentifier:@"default-custom" name:@"自定義" createdAt:DateAt(2026, 4, 29, 8) sortOrder:0];
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[hidden, first, second, third] customLists:@[customList]];

    [list moveVisibleTaskFromIndex:0 toIndex:3 customListID:@"default-custom"];
    NSArray *visible = [list tasksForCustomListID:@"default-custom"];

    TDAssertEqualObjects(TaskIDs(visible), (@[second.identifier, third.identifier, first.identifier]), "moving first custom item to bottom should reorder visible tasks");
    TDAssert(hidden.sortOrder == 99, "hidden task sort order should not change");
}

static void TestFileStoreRoundTripsTasksAsJSONAndCreatesParentDirectory(void) {
    NSString *temporaryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    NSURL *fileURL = [NSURL fileURLWithPath:[temporaryPath stringByAppendingPathComponent:@"nested/tasks.json"]];
    TDTaskFileStore *store = [[TDTaskFileStore alloc] initWithFileURL:fileURL];
    NSArray<TDTodoTask *> *tasks = @[Task(@"persist", DateAt(2026, 4, 29, 0), nil, TDTaskBucketToday, 0)];
    NSError *error = nil;

    TDAssert([store saveTasks:tasks error:&error], "save should succeed");
    NSArray<TDTodoTask *> *loaded = [store loadTasksWithError:&error];

    TDAssert(error == nil, "load should not error");
    TDAssertEqualObjects([loaded.firstObject dictionaryRepresentation], [tasks.firstObject dictionaryRepresentation], "file store should round trip task JSON");
}

static void TestFileStoreRoundTripsFullTodoListDatabaseData(void) {
    NSDate *now = DateAt(2026, 4, 29, 9);
    TDTaskFileStore *store = [[TDTaskFileStore alloc] initWithFileURL:[NSURL fileURLWithPath:@"/tmp/tododesk-export-test.json"]];
    TDTodoList *list = [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    TDCustomList *customList = [list addCustomListNamed:@"工作" now:now];
    [list addTaskWithTitle:@"today" bucket:TDTaskBucketToday estimatedMinutes:30 now:now calendar:HongKongCalendar()];
    [list addTaskWithTitle:@"custom" customListID:customList.identifier estimatedMinutes:45 now:now];
    NSError *error = nil;

    NSData *data = [store dataForTodoList:list error:&error];
    TDTodoList *loaded = [store todoListFromData:data error:&error];

    TDAssert(error == nil, "database data round trip should not report an error");
    TDAssert(data.length > 0, "database data should be generated");
    TDAssert(loaded.tasks.count == 2, "database data should round trip all tasks");
    TDAssert(loaded.customLists.count == 1, "database data should round trip custom lists");
    TDAssertEqualObjects([loaded.tasks.firstObject dictionaryRepresentation], [list.tasks.firstObject dictionaryRepresentation], "first task should survive database data round trip");
    TDAssertEqualObjects([loaded.customLists.firstObject dictionaryRepresentation], [customList dictionaryRepresentation], "custom list should survive database data round trip");
}

static void TestDefaultStoreURLCanBeOverriddenByEnvironment(void) {
    NSString *temporaryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    setenv("TODODESK_STORE_PATH", temporaryPath.UTF8String, 1);

    NSURL *storeURL = [TDTaskFileStore defaultStoreURL];

    unsetenv("TODODESK_STORE_PATH");
    TDAssertEqualObjects(storeURL.path, temporaryPath, "default store URL should honor TODODESK_STORE_PATH for portable testing and custom installs");
}

static void TestFileStoreMigratesLegacyCustomTasksIntoDefaultCustomList(void) {
    NSString *temporaryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    NSURL *fileURL = [NSURL fileURLWithPath:[temporaryPath stringByAppendingPathComponent:@"legacy/tasks.json"]];
    NSArray *legacyTasks = @[
        @{
            @"id": @"legacy-custom",
            @"title": @"old custom task",
            @"createdAt": @"2026-04-29T08:00:00.000Z",
            @"dueDate": [NSNull null],
            @"completedAt": [NSNull null],
            @"bucket": @"custom",
            @"sortOrder": @0
        }
    ];
    [NSFileManager.defaultManager createDirectoryAtURL:[fileURL URLByDeletingLastPathComponent]
                           withIntermediateDirectories:YES
                                            attributes:nil
                                                 error:nil];
    NSData *data = [NSJSONSerialization dataWithJSONObject:legacyTasks options:0 error:nil];
    [data writeToURL:fileURL atomically:YES];

    TDTaskFileStore *store = [[TDTaskFileStore alloc] initWithFileURL:fileURL];
    NSError *error = nil;
    TDTodoList *list = [store loadTodoListWithError:&error];

    TDAssert(error == nil, "legacy load should not error");
    TDAssertEqualObjects(list.customLists.firstObject.name, @"自定義", "legacy custom tasks should create default custom list");
    TDAssertEqualObjects(list.tasks.firstObject.listID, list.customLists.firstObject.identifier, "legacy custom task should receive default list id");
}

int main(void) {
    @autoreleasepool {
        TestTodayTabIncludesOnlyTodayBucketTasksDueTodayAndSortsByOrder();
        TestTomorrowTabIncludesNextActiveDayTasks();
        TestCutoffKeepsEarlyMorningInPreviousActiveDay();
        TestTomorrowTasksRollIntoTodayAfterCutoff();
        TestAddTomorrowTaskUsesNextActiveDayDueDate();
        TestRetargetTasksKeepsTodayAndTomorrowAfterCutoffChange();
        TestCustomTasksIgnoreTodayCutoff();
        TestMoveBackToTodayUsesCutoffActiveDay();
        TestPastIncompleteIncludesExpiredUnfinishedTodayTasksOnly();
        TestPastCompletedOrdersByCompletedAtDescending();
        TestCustomIncludesCustomTasksRegardlessOfCompletion();
        TestMultipleCustomListsKeepTasksSeparate();
        TestAddingCustomTaskAfterTodayTaskKeepsNilDatesSafe();
        TestAddSetsTodayDueDateButLeavesCustomWithoutDueDate();
        TestTaskEqualityHandlesOneSidedOptionalValues();
        TestEstimatedDurationDefaultsAndPersists();
        TestSubtasksPersistAndRenderAfterParent();
        TestRenameTaskTrimsTitleAndIgnoresBlankNames();
        TestTaskDescriptionUpdatesAndRoundTripsJSON();
        TestTaskDetailsUpdateDescriptionAndEstimate();
        TestSubtaskDetailsUpdateDescriptionAndEstimate();
        TestSubtaskFromSubtaskCreatesSiblingUnderRootParent();
        TestRenameAndDeleteCustomList();
        TestDeletingParentDeletesSubtasks();
        TestMoveVisiblePastIncompleteTasksBackToToday();
        TestRemainingTimeTextFormatsCountdownSeconds();
        TestToggleCompletionSetsAndClearsCompletedAt();
        TestMoveVisibleTasksUpdatesOnlyVisibleSortOrders();
        TestFileStoreRoundTripsTasksAsJSONAndCreatesParentDirectory();
        TestFileStoreRoundTripsFullTodoListDatabaseData();
        TestDefaultStoreURLCanBeOverriddenByEnvironment();
        TestFileStoreMigratesLegacyCustomTasksIntoDefaultCustomList();

        if (failures > 0) {
            fprintf(stderr, "%lu test(s) failed\n", (unsigned long)failures);
            return 1;
        }

        printf("TodoDeskCoreTests passed\n");
        return 0;
    }
}
