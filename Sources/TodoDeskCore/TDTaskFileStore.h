#import <Foundation/Foundation.h>
#import "TDTodoList.h"
#import "TDTodoTask.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDTaskFileStore : NSObject

@property (nonatomic, strong, readonly) NSURL *fileURL;

- (instancetype)initWithFileURL:(NSURL *)fileURL NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSURL *)defaultStoreURL;
- (TDTodoList *)loadTodoListWithError:(NSError **)error;
- (NSArray<TDTodoTask *> *)loadTasksWithError:(NSError **)error;
- (BOOL)saveTodoList:(TDTodoList *)todoList error:(NSError **)error;
- (BOOL)saveTasks:(NSArray<TDTodoTask *> *)tasks error:(NSError **)error;
- (nullable NSData *)dataForTodoList:(TDTodoList *)todoList error:(NSError **)error;
- (TDTodoList *)todoListFromData:(NSData *)data error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
