#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface TDTaskTableView : NSTableView

@property (nonatomic, weak, nullable) id keyActionTarget;
@property (nonatomic, nullable) SEL deleteAction;
@property (nonatomic, nullable) SEL renameAction;
@property (nonatomic, nullable) SEL timerAction;
@property (nonatomic, nullable) SEL focusAddAction;
@property (nonatomic, nullable) SEL switchTabAction;
@property (nonatomic) NSInteger dropIndicatorRow;
@property (nonatomic) BOOL showsDropIndicator;

@end

NS_ASSUME_NONNULL_END
