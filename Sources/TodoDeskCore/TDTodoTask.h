#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TDTaskBucket) {
    TDTaskBucketToday = 0,
    TDTaskBucketCustom = 1
};

typedef NS_ENUM(NSInteger, TDTaskTab) {
    TDTaskTabPastCompleted = 0,
    TDTaskTabPastIncomplete = 1,
    TDTaskTabToday = 2,
    TDTaskTabTomorrow = 3,
    TDTaskTabCustom = 4
};

@interface TDTodoTask : NSObject <NSCopying>

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *taskDescription;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *dueDate;
@property (nonatomic, strong, nullable) NSDate *completedAt;
@property (nonatomic) TDTaskBucket bucket;
@property (nonatomic, copy, nullable) NSString *listID;
@property (nonatomic, copy, nullable) NSString *parentTaskID;
@property (nonatomic) NSInteger estimatedMinutes;
@property (nonatomic) NSInteger sortOrder;

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
                         createdAt:(NSDate *)createdAt
                           dueDate:(nullable NSDate *)dueDate
                       completedAt:(nullable NSDate *)completedAt
                            bucket:(TDTaskBucket)bucket
                            listID:(nullable NSString *)listID
                  estimatedMinutes:(NSInteger)estimatedMinutes
                         sortOrder:(NSInteger)sortOrder;

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
                         createdAt:(NSDate *)createdAt
                           dueDate:(nullable NSDate *)dueDate
                       completedAt:(nullable NSDate *)completedAt
                            bucket:(TDTaskBucket)bucket
                            listID:(nullable NSString *)listID
                      parentTaskID:(nullable NSString *)parentTaskID
                  estimatedMinutes:(NSInteger)estimatedMinutes
                         sortOrder:(NSInteger)sortOrder NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
                         createdAt:(NSDate *)createdAt
                           dueDate:(nullable NSDate *)dueDate
                       completedAt:(nullable NSDate *)completedAt
                            bucket:(TDTaskBucket)bucket
                            listID:(nullable NSString *)listID
                         sortOrder:(NSInteger)sortOrder;

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
                         createdAt:(NSDate *)createdAt
                           dueDate:(nullable NSDate *)dueDate
                       completedAt:(nullable NSDate *)completedAt
                            bucket:(TDTaskBucket)bucket
                         sortOrder:(NSInteger)sortOrder;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (nullable TDTodoTask *)taskWithDictionaryRepresentation:(NSDictionary<NSString *, id> *)dictionary;
- (NSDictionary<NSString *, id> *)dictionaryRepresentation;

+ (NSString *)stringForBucket:(TDTaskBucket)bucket;
+ (TDTaskBucket)bucketForString:(NSString *)string;

@end

NS_ASSUME_NONNULL_END
