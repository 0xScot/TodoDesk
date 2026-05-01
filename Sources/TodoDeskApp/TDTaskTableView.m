#import "TDTaskTableView.h"

static NSColor *TDMinimalTableColor(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha) {
    return [NSColor colorWithCalibratedRed:red / 255.0 green:green / 255.0 blue:blue / 255.0 alpha:alpha];
}

@implementation TDTaskTableView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _dropIndicatorRow = -1;
        _showsDropIndicator = NO;
    }
    return self;
}

- (void)setDropIndicatorRow:(NSInteger)dropIndicatorRow {
    if (_dropIndicatorRow == dropIndicatorRow) {
        return;
    }
    _dropIndicatorRow = dropIndicatorRow;
    self.needsDisplay = YES;
}

- (void)setShowsDropIndicator:(BOOL)showsDropIndicator {
    if (_showsDropIndicator == showsDropIndicator) {
        return;
    }
    _showsDropIndicator = showsDropIndicator;
    self.needsDisplay = YES;
}

- (void)keyDown:(NSEvent *)event {
    BOOL commandDown = (event.modifierFlags & NSEventModifierFlagCommand) == NSEventModifierFlagCommand;
    NSString *characters = event.charactersIgnoringModifiers.lowercaseString ?: @"";
    if (commandDown && [characters isEqualToString:@"n"]) {
        if ([self performKeyAction:self.focusAddAction object:self]) {
            return;
        }
    }
    if (commandDown && characters.length == 1) {
        unichar character = [characters characterAtIndex:0];
        if (character >= '1' && character <= '9') {
            if ([self performKeyAction:self.switchTabAction object:@(character - '1')]) {
                return;
            }
        }
    }

    if ((event.keyCode == 51 || event.keyCode == 117)
        && [self performKeyAction:self.deleteAction object:self]) {
        return;
    }
    if ((event.keyCode == 36 || event.keyCode == 76)
        && [self performKeyAction:self.renameAction object:self]) {
        return;
    }
    if (event.keyCode == 49 && [self performKeyAction:self.timerAction object:self]) {
        return;
    }

    [super keyDown:event];
}

- (BOOL)performKeyAction:(SEL)action object:(id)object {
    if (self.keyActionTarget == nil || action == NULL || ![self.keyActionTarget respondsToSelector:action]) {
        return NO;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.keyActionTarget performSelector:action withObject:object];
#pragma clang diagnostic pop
    return YES;
}

- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    NSInteger row = [self rowAtPoint:point];
    if (row >= 0) {
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row] byExtendingSelection:NO];
    }
    return [super menuForEvent:event];
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
    (void)sender;
    self.showsDropIndicator = NO;
    self.dropIndicatorRow = -1;
    [super draggingExited:sender];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    if (!self.showsDropIndicator || self.dropIndicatorRow < 0) {
        return;
    }

    CGFloat y = 10;
    if (self.numberOfRows > 0) {
        if (self.dropIndicatorRow >= self.numberOfRows) {
            y = NSMaxY([self rectOfRow:self.numberOfRows - 1]) + 1;
        } else {
            y = NSMinY([self rectOfRow:self.dropIndicatorRow]) - 1;
        }
    }

    CGFloat inset = 28;
    NSRect lineRect = NSMakeRect(inset, y - 2, MAX(0, NSWidth(self.bounds) - inset * 2), 4);
    if (!NSIntersectsRect(NSInsetRect(lineRect, -4, -8), dirtyRect)) {
        return;
    }

    [TDMinimalTableColor(18, 18, 18, 0.92) setFill];
    NSBezierPath *line = [NSBezierPath bezierPathWithRoundedRect:lineRect xRadius:2 yRadius:2];
    [line fill];

    NSRect handleRect = NSMakeRect(inset - 7, y - 5, 10, 10);
    NSBezierPath *handle = [NSBezierPath bezierPathWithOvalInRect:handleRect];
    [handle fill];
}

@end
