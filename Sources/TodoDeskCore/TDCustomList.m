#import "TDCustomList.h"

NSISO8601DateFormatter *TDSharedISODateFormatter(void);

@implementation TDCustomList

- (instancetype)initWithIdentifier:(NSString *)identifier
                              name:(NSString *)name
                         createdAt:(NSDate *)createdAt
                         sortOrder:(NSInteger)sortOrder {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _name = [name copy];
        _createdAt = createdAt;
        _sortOrder = sortOrder;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return [[TDCustomList allocWithZone:zone] initWithIdentifier:self.identifier
                                                            name:self.name
                                                       createdAt:self.createdAt
                                                       sortOrder:self.sortOrder];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:TDCustomList.class]) {
        return NO;
    }
    TDCustomList *other = object;
    return [self.identifier isEqualToString:other.identifier]
        && [self.name isEqualToString:other.name]
        && [self.createdAt isEqualToDate:other.createdAt]
        && self.sortOrder == other.sortOrder;
}

- (NSUInteger)hash {
    return self.identifier.hash;
}

+ (TDCustomList *)listWithDictionaryRepresentation:(NSDictionary<NSString *, id> *)dictionary {
    NSString *identifier = [dictionary[@"id"] isKindOfClass:NSString.class] ? dictionary[@"id"] : nil;
    NSString *name = [dictionary[@"name"] isKindOfClass:NSString.class] ? dictionary[@"name"] : nil;
    NSString *createdAtString = [dictionary[@"createdAt"] isKindOfClass:NSString.class] ? dictionary[@"createdAt"] : nil;
    NSNumber *sortOrder = [dictionary[@"sortOrder"] isKindOfClass:NSNumber.class] ? dictionary[@"sortOrder"] : @0;
    NSDate *createdAt = createdAtString == nil ? nil : [TDSharedISODateFormatter() dateFromString:createdAtString];

    if (identifier.length == 0 || name.length == 0 || createdAt == nil) {
        return nil;
    }

    return [[TDCustomList alloc] initWithIdentifier:identifier
                                               name:name
                                          createdAt:createdAt
                                          sortOrder:sortOrder.integerValue];
}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    return @{
        @"id": self.identifier,
        @"name": self.name,
        @"createdAt": [TDSharedISODateFormatter() stringFromDate:self.createdAt],
        @"sortOrder": @(self.sortOrder)
    };
}

@end
