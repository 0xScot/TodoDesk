#import <Cocoa/Cocoa.h>
#import "TDTodoTask.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDTaskCellView : NSTableCellView

@property (nonatomic, strong, readonly) NSButton *timerButton;
@property (nonatomic, strong, readonly) NSButton *disclosureButton;
@property (nonatomic, strong, readonly) NSButton *descriptionButton;

- (void)configureWithTask:(TDTodoTask *)task;
- (void)configureWithTask:(TDTodoTask *)task
         remainingSeconds:(NSTimeInterval)remainingSeconds
               timerState:(nullable NSString *)timerState
              hasChildren:(BOOL)hasChildren
                collapsed:(BOOL)collapsed;

@end

NS_ASSUME_NONNULL_END
