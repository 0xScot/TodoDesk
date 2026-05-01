#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TDCustomList : NSObject <NSCopying>

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic) NSInteger sortOrder;

- (instancetype)initWithIdentifier:(NSString *)identifier
                              name:(NSString *)name
                         createdAt:(NSDate *)createdAt
                         sortOrder:(NSInteger)sortOrder NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (nullable TDCustomList *)listWithDictionaryRepresentation:(NSDictionary<NSString *, id> *)dictionary;
- (NSDictionary<NSString *, id> *)dictionaryRepresentation;

@end

NS_ASSUME_NONNULL_END
