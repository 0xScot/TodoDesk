#import <Foundation/Foundation.h>
#import "TDCustomList.h"
#import "TDTodoTask.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDTodoList : NSObject

@property (nonatomic, strong, readonly) NSMutableArray<TDTodoTask *> *tasks;
@property (nonatomic, strong, readonly) NSMutableArray<TDCustomList *> *customLists;

- (instancetype)initWithTasks:(NSArray<TDTodoTask *> *)tasks;
- (instancetype)initWithTasks:(NSArray<TDTodoTask *> *)tasks
                  customLists:(NSArray<TDCustomList *> *)customLists NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSDate *)activeDayStartForDate:(NSDate *)date
                          calendar:(NSCalendar *)calendar
                todayCutoffMinutes:(NSInteger)todayCutoffMinutes;

+ (NSDate *)dayStartForDate:(NSDate *)date
                     offset:(NSInteger)dayOffset
                   calendar:(NSCalendar *)calendar
         todayCutoffMinutes:(NSInteger)todayCutoffMinutes;

- (TDTodoTask *)addTaskWithTitle:(NSString *)title
                          bucket:(TDTaskBucket)bucket
                             now:(NSDate *)now
                        calendar:(NSCalendar *)calendar;

- (TDTodoTask *)addTaskWithTitle:(NSString *)title
                          bucket:(TDTaskBucket)bucket
                estimatedMinutes:(NSInteger)estimatedMinutes
                             now:(NSDate *)now
                        calendar:(NSCalendar *)calendar;

- (TDTodoTask *)addTaskWithTitle:(NSString *)title
                          bucket:(TDTaskBucket)bucket
                estimatedMinutes:(NSInteger)estimatedMinutes
                        dayOffset:(NSInteger)dayOffset
                             now:(NSDate *)now
                        calendar:(NSCalendar *)calendar
              todayCutoffMinutes:(NSInteger)todayCutoffMinutes;

- (TDTodoTask *)addTaskWithTitle:(NSString *)title
                     customListID:(NSString *)customListID
                              now:(NSDate *)now;

- (TDTodoTask *)addTaskWithTitle:(NSString *)title
                     customListID:(NSString *)customListID
                 estimatedMinutes:(NSInteger)estimatedMinutes
                              now:(NSDate *)now;

- (TDCustomList *)addCustomListNamed:(NSString *)name now:(NSDate *)now;

- (nullable TDTodoTask *)addSubtaskWithTitle:(NSString *)title
                                parentTaskID:(NSString *)parentTaskID
                                         now:(NSDate *)now;

- (nullable TDTodoTask *)addSubtaskWithTitle:(NSString *)title
                                parentTaskID:(NSString *)parentTaskID
                            estimatedMinutes:(NSInteger)estimatedMinutes
                                         now:(NSDate *)now;

- (NSArray<TDTodoTask *> *)tasksForTab:(TDTaskTab)tab
                                   now:(NSDate *)now
                              calendar:(NSCalendar *)calendar;

- (NSArray<TDTodoTask *> *)tasksForTab:(TDTaskTab)tab
                                   now:(NSDate *)now
                              calendar:(NSCalendar *)calendar
                    todayCutoffMinutes:(NSInteger)todayCutoffMinutes;

- (NSArray<TDTodoTask *> *)tasksForCustomListID:(NSString *)customListID;

- (void)toggleCompletionForTaskID:(NSString *)taskID atDate:(NSDate *)date;
- (BOOL)renameTaskWithID:(NSString *)taskID title:(NSString *)title;
- (BOOL)updateDescriptionForTaskID:(NSString *)taskID description:(nullable NSString *)description;
- (BOOL)updateDetailsForTaskID:(NSString *)taskID
                    description:(nullable NSString *)description
               estimatedMinutes:(NSInteger)estimatedMinutes;
- (void)deleteTaskWithID:(NSString *)taskID;
- (BOOL)renameCustomListWithID:(NSString *)listID name:(NSString *)name;
- (BOOL)deleteCustomListWithID:(NSString *)listID;
- (NSArray<TDTodoTask *> *)childrenForTaskID:(NSString *)taskID;
- (NSArray<TDTodoTask *> *)descendantsForTaskID:(NSString *)taskID;
- (NSArray<TDTodoTask *> *)moveTasksBackToToday:(NSArray<TDTodoTask *> *)tasks
                                            now:(NSDate *)now
                                       calendar:(NSCalendar *)calendar;

- (NSArray<TDTodoTask *> *)moveTasksBackToToday:(NSArray<TDTodoTask *> *)tasks
                                            now:(NSDate *)now
                                       calendar:(NSCalendar *)calendar
                             todayCutoffMinutes:(NSInteger)todayCutoffMinutes;

- (void)retargetTasksWithIDs:(NSArray<NSString *> *)taskIDs
                 toDayOffset:(NSInteger)dayOffset
                         now:(NSDate *)now
                    calendar:(NSCalendar *)calendar
          todayCutoffMinutes:(NSInteger)todayCutoffMinutes;

- (void)moveVisibleTaskFromIndex:(NSUInteger)sourceIndex
                         toIndex:(NSUInteger)destinationIndex
                             tab:(TDTaskTab)tab
                             now:(NSDate *)now
                        calendar:(NSCalendar *)calendar;

- (void)moveVisibleTaskFromIndex:(NSUInteger)sourceIndex
                         toIndex:(NSUInteger)destinationIndex
                             tab:(TDTaskTab)tab
                             now:(NSDate *)now
                        calendar:(NSCalendar *)calendar
              todayCutoffMinutes:(NSInteger)todayCutoffMinutes;

- (void)moveVisibleTaskFromIndex:(NSUInteger)sourceIndex
                         toIndex:(NSUInteger)destinationIndex
                    customListID:(NSString *)customListID;

@end

NS_ASSUME_NONNULL_END
