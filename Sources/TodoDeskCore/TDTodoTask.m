#import "TDTodoTask.h"

NSISO8601DateFormatter *TDSharedISODateFormatter(void) {
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    });
    return formatter;
}

static id TDNullableDateString(NSDate *date) {
    return date == nil ? [NSNull null] : [TDSharedISODateFormatter() stringFromDate:date];
}

static NSDate *TDDateFromJSONValue(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return nil;
    }
    return [TDSharedISODateFormatter() dateFromString:value];
}

static BOOL TDTaskValuesEqual(id left, id right) {
    if (left == nil || right == nil) {
        return left == right;
    }
    return [left isEqual:right];
}

@implementation TDTodoTask

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
                         createdAt:(NSDate *)createdAt
                           dueDate:(NSDate *)dueDate
                       completedAt:(NSDate *)completedAt
                            bucket:(TDTaskBucket)bucket
                            listID:(NSString *)listID
                  estimatedMinutes:(NSInteger)estimatedMinutes
                         sortOrder:(NSInteger)sortOrder {
    return [self initWithIdentifier:identifier
                              title:title
                          createdAt:createdAt
                            dueDate:dueDate
                        completedAt:completedAt
                             bucket:bucket
                             listID:listID
                       parentTaskID:nil
                   estimatedMinutes:estimatedMinutes
                          sortOrder:sortOrder];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
                         createdAt:(NSDate *)createdAt
                           dueDate:(NSDate *)dueDate
                       completedAt:(NSDate *)completedAt
                            bucket:(TDTaskBucket)bucket
                            listID:(NSString *)listID
                      parentTaskID:(NSString *)parentTaskID
                  estimatedMinutes:(NSInteger)estimatedMinutes
                         sortOrder:(NSInteger)sortOrder {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _title = [title copy];
        _taskDescription = nil;
        _createdAt = createdAt;
        _dueDate = dueDate;
        _completedAt = completedAt;
        _bucket = bucket;
        _listID = [listID copy];
        _parentTaskID = [parentTaskID copy];
        _estimatedMinutes = MAX(0, estimatedMinutes);
        _sortOrder = sortOrder;
    }
    return self;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
                         createdAt:(NSDate *)createdAt
                           dueDate:(NSDate *)dueDate
                       completedAt:(NSDate *)completedAt
                            bucket:(TDTaskBucket)bucket
                            listID:(NSString *)listID
                         sortOrder:(NSInteger)sortOrder {
    return [self initWithIdentifier:identifier
                              title:title
                          createdAt:createdAt
                            dueDate:dueDate
                        completedAt:completedAt
                             bucket:bucket
                             listID:listID
                  estimatedMinutes:0
                          sortOrder:sortOrder];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
                         createdAt:(NSDate *)createdAt
                           dueDate:(NSDate *)dueDate
                       completedAt:(NSDate *)completedAt
                            bucket:(TDTaskBucket)bucket
                         sortOrder:(NSInteger)sortOrder {
    return [self initWithIdentifier:identifier
                              title:title
                          createdAt:createdAt
                            dueDate:dueDate
                        completedAt:completedAt
                             bucket:bucket
                             listID:nil
                  estimatedMinutes:0
                          sortOrder:sortOrder];
}

- (id)copyWithZone:(NSZone *)zone {
    TDTodoTask *copy = [[TDTodoTask allocWithZone:zone] initWithIdentifier:self.identifier
                                                                     title:self.title
                                                                 createdAt:self.createdAt
                                                                   dueDate:self.dueDate
                                                               completedAt:self.completedAt
                                                                    bucket:self.bucket
                                                                    listID:self.listID
                                                              parentTaskID:self.parentTaskID
                                                         estimatedMinutes:self.estimatedMinutes
                                                                 sortOrder:self.sortOrder];
    copy.taskDescription = self.taskDescription;
    return copy;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:TDTodoTask.class]) {
        return NO;
    }
    TDTodoTask *other = object;
    return [self.identifier isEqualToString:other.identifier]
        && [self.title isEqualToString:other.title]
        && TDTaskValuesEqual(self.taskDescription, other.taskDescription)
        && [self.createdAt isEqualToDate:other.createdAt]
        && TDTaskValuesEqual(self.dueDate, other.dueDate)
        && TDTaskValuesEqual(self.completedAt, other.completedAt)
        && self.bucket == other.bucket
        && TDTaskValuesEqual(self.listID, other.listID)
        && TDTaskValuesEqual(self.parentTaskID, other.parentTaskID)
        && self.estimatedMinutes == other.estimatedMinutes
        && self.sortOrder == other.sortOrder;
}

- (NSUInteger)hash {
    return self.identifier.hash;
}

+ (TDTodoTask *)taskWithDictionaryRepresentation:(NSDictionary<NSString *, id> *)dictionary {
    NSString *identifier = [dictionary[@"id"] isKindOfClass:NSString.class] ? dictionary[@"id"] : nil;
    NSString *title = [dictionary[@"title"] isKindOfClass:NSString.class] ? dictionary[@"title"] : nil;
    NSString *taskDescription = [dictionary[@"description"] isKindOfClass:NSString.class] ? dictionary[@"description"] : nil;
    NSDate *createdAt = TDDateFromJSONValue(dictionary[@"createdAt"]);
    NSString *bucketString = [dictionary[@"bucket"] isKindOfClass:NSString.class] ? dictionary[@"bucket"] : @"today";
    NSString *listID = [dictionary[@"listID"] isKindOfClass:NSString.class] ? dictionary[@"listID"] : nil;
    NSString *parentTaskID = [dictionary[@"parentTaskID"] isKindOfClass:NSString.class] ? dictionary[@"parentTaskID"] : nil;
    NSNumber *estimatedMinutes = [dictionary[@"estimatedMinutes"] isKindOfClass:NSNumber.class] ? dictionary[@"estimatedMinutes"] : @0;
    NSNumber *sortOrder = [dictionary[@"sortOrder"] isKindOfClass:NSNumber.class] ? dictionary[@"sortOrder"] : @0;

    if (identifier.length == 0 || title == nil || createdAt == nil) {
        return nil;
    }

    TDTodoTask *task = [[TDTodoTask alloc] initWithIdentifier:identifier
                                                        title:title
                                                    createdAt:createdAt
                                                      dueDate:TDDateFromJSONValue(dictionary[@"dueDate"])
                                                  completedAt:TDDateFromJSONValue(dictionary[@"completedAt"])
                                                       bucket:[self bucketForString:bucketString]
                                                       listID:listID
                                                 parentTaskID:parentTaskID
                                             estimatedMinutes:estimatedMinutes.integerValue
                                                    sortOrder:sortOrder.integerValue];
    task.taskDescription = taskDescription.length > 0 ? taskDescription : nil;
    return task;
}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    return @{
        @"id": self.identifier,
        @"title": self.title,
        @"description": self.taskDescription ?: [NSNull null],
        @"createdAt": [TDSharedISODateFormatter() stringFromDate:self.createdAt],
        @"dueDate": TDNullableDateString(self.dueDate),
        @"completedAt": TDNullableDateString(self.completedAt),
        @"bucket": [TDTodoTask stringForBucket:self.bucket],
        @"listID": self.listID ?: [NSNull null],
        @"parentTaskID": self.parentTaskID ?: [NSNull null],
        @"estimatedMinutes": @(self.estimatedMinutes),
        @"sortOrder": @(self.sortOrder)
    };
}

+ (NSString *)stringForBucket:(TDTaskBucket)bucket {
    switch (bucket) {
        case TDTaskBucketCustom:
            return @"custom";
        case TDTaskBucketToday:
        default:
            return @"today";
    }
}

+ (TDTaskBucket)bucketForString:(NSString *)string {
    if ([string isEqualToString:@"custom"]) {
        return TDTaskBucketCustom;
    }
    return TDTaskBucketToday;
}

@end
