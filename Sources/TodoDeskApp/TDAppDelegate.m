#import "TDAppDelegate.h"
#import "TDTaskCellView.h"
#import "TDTaskTableView.h"
#import "TDTodoList.h"
#import "TDTaskFileStore.h"
#import <QuartzCore/QuartzCore.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <UserNotifications/UserNotifications.h>

static NSPasteboardType const TDTaskDragType = @"io.github.0xscot.tododesk.task-row";
static NSString * const TDTabOrderDefaultsKey = @"TodoDeskTabOrder";
static NSString * const TDCollapsedTaskIDsDefaultsKey = @"TodoDeskCollapsedTaskIDs";
static NSString * const TDTodayCutoffMinutesDefaultsKey = @"TodoDeskTodayCutoffMinutes";
static NSString * const TDTabPastCompletedID = @"fixed:pastCompleted";
static NSString * const TDTabPastIncompleteID = @"fixed:pastIncomplete";
static NSString * const TDTabTodayID = @"fixed:today";
static NSString * const TDTabTomorrowID = @"fixed:tomorrow";
static NSString * const TDTabCustomPrefix = @"custom:";

static NSColor *TDMinimalColor(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha) {
    return [NSColor colorWithCalibratedRed:red / 255.0 green:green / 255.0 blue:blue / 255.0 alpha:alpha];
}

@interface TDTabButton : NSButton
@end

@implementation TDTabButton

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    (void)event;
    return YES;
}

@end

@interface TDAppDelegate () <UNUserNotificationCenterDelegate>

@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) NSView *tabBarView;
@property (nonatomic, strong) NSStackView *tabStackView;
@property (nonatomic, strong) NSMutableArray<NSButton *> *tabButtons;
@property (nonatomic, strong) NSMutableArray<NSString *> *tabOrder;
@property (nonatomic, strong) NSView *tabDropIndicator;
@property (nonatomic, strong) TDTaskTableView *tableView;
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSTextField *inputField;
@property (nonatomic, strong) NSTextField *hoursField;
@property (nonatomic, strong) NSTextField *hoursLabel;
@property (nonatomic, strong) NSTextField *minutesField;
@property (nonatomic, strong) NSTextField *minutesLabel;
@property (nonatomic, strong) NSButton *addButton;
@property (nonatomic, strong) NSButton *reviewButton;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) TDTodoList *todoList;
@property (nonatomic, strong) TDTaskFileStore *fileStore;
@property (nonatomic, strong) NSArray<TDTodoTask *> *visibleTasks;
@property (nonatomic, strong) NSCalendar *calendar;
@property (nonatomic, strong) NSTimer *clockTimer;
@property (nonatomic, strong) NSTimer *countdownTimer;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *runningTimerDeadlines;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *pausedTimerRemainingSeconds;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *timerNotificationIDs;
@property (nonatomic, strong) NSMutableSet<NSString *> *collapsedTaskIDs;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, strong) NSIndexSet *draggedRows;
@property (nonatomic, weak) NSButton *draggedTabButton;
@property (nonatomic, copy) NSString *draggedTaskID;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *preDragTaskSortOrders;
@property (nonatomic, strong) NSArray<NSString *> *preDragTabOrder;
@property (nonatomic) NSInteger selectedTabIndex;
@property (nonatomic) NSInteger previousSelectedTabIndex;
@property (nonatomic) NSInteger draggedTabIndex;
@property (nonatomic) NSInteger pendingTabDropIndex;
@property (nonatomic) NSInteger liveDraggedRowIndex;
@property (nonatomic) NSInteger todayCutoffMinutes;
@property (nonatomic) BOOL blockDragAccepted;
@property (nonatomic) BOOL tabOrderChangedDuringDrag;

@end

@implementation TDAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    self.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    self.calendar.timeZone = NSTimeZone.localTimeZone;
    self.fileStore = [[TDTaskFileStore alloc] initWithFileURL:TDTaskFileStore.defaultStoreURL];
    self.todayCutoffMinutes = [self savedTodayCutoffMinutes];

    NSError *error = nil;
    self.todoList = [self.fileStore loadTodoListWithError:&error];
    if (self.todoList == nil) {
        self.todoList = [[TDTodoList alloc] initWithTasks:@[] customLists:@[]];
    }
    self.selectedTabIndex = 2;
    self.previousSelectedTabIndex = 2;
    self.draggedTabIndex = -1;
    self.pendingTabDropIndex = -1;
    self.liveDraggedRowIndex = -1;
    self.runningTimerDeadlines = [NSMutableDictionary dictionary];
    self.pausedTimerRemainingSeconds = [NSMutableDictionary dictionary];
    self.timerNotificationIDs = [NSMutableDictionary dictionary];
    NSArray *savedCollapsedTaskIDs = [NSUserDefaults.standardUserDefaults arrayForKey:TDCollapsedTaskIDsDefaultsKey] ?: @[];
    self.collapsedTaskIDs = [NSMutableSet setWithArray:savedCollapsedTaskIDs];
    self.searchQuery = @"";
    [self configureNotifications];
    [self configureMainMenu];

    [self buildWindow];
    [self reloadVisibleTasks];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];

    self.clockTimer = [NSTimer scheduledTimerWithTimeInterval:60
                                                       target:self
                                                     selector:@selector(refreshForClock:)
                                                     userInfo:nil
                                                      repeats:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}

- (void)configureMainMenu {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"Main Menu"];

    NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"TodoDesk" action:nil keyEquivalent:@""];
    [mainMenu addItem:appMenuItem];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"TodoDesk"];
    NSMenuItem *cutoffItem = [[NSMenuItem alloc] initWithTitle:@"今日到期時間..." action:@selector(promptForTodayCutoffTime:) keyEquivalent:@""];
    cutoffItem.target = self;
    [appMenu addItem:cutoffItem];
    [appMenu addItem:NSMenuItem.separatorItem];
    NSString *quitTitle = @"結束 TodoDesk";
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:quitTitle action:@selector(terminate:) keyEquivalent:@"q"];
    [appMenu addItem:quitItem];
    appMenuItem.submenu = appMenu;

    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] initWithTitle:@"檔案" action:nil keyEquivalent:@""];
    [mainMenu addItem:fileMenuItem];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"檔案"];
    NSMenuItem *newTaskItem = [[NSMenuItem alloc] initWithTitle:@"新增事項" action:@selector(focusAddTaskField:) keyEquivalent:@"n"];
    newTaskItem.target = self;
    [fileMenu addItem:newTaskItem];
    [fileMenu addItem:NSMenuItem.separatorItem];
    NSMenuItem *importItem = [[NSMenuItem alloc] initWithTitle:@"匯入 JSON..." action:@selector(importTodoData:) keyEquivalent:@"i"];
    importItem.target = self;
    [fileMenu addItem:importItem];
    NSMenuItem *exportItem = [[NSMenuItem alloc] initWithTitle:@"匯出 JSON..." action:@selector(exportTodoData:) keyEquivalent:@"e"];
    exportItem.target = self;
    [fileMenu addItem:exportItem];
    [fileMenu addItem:NSMenuItem.separatorItem];
    NSMenuItem *openDataFolderItem = [[NSMenuItem alloc] initWithTitle:@"打開資料夾" action:@selector(openDataFolder:) keyEquivalent:@""];
    openDataFolderItem.target = self;
    [fileMenu addItem:openDataFolderItem];
    fileMenuItem.submenu = fileMenu;

    NSApp.mainMenu = mainMenu;
}

- (void)buildWindow {
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 560, 660)
                                              styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"TodoDesk";
    self.window.minSize = NSMakeSize(460, 520);
    [self.window center];

    NSView *contentView = self.window.contentView;
    contentView.wantsLayer = YES;
    contentView.layer.backgroundColor = TDMinimalColor(238, 237, 233, 1).CGColor;

    self.tabBarView = [[NSView alloc] init];
    self.tabBarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabBarView.wantsLayer = YES;
    self.tabBarView.layer.backgroundColor = TDMinimalColor(238, 237, 233, 1).CGColor;
    [contentView addSubview:self.tabBarView];

    self.tabStackView = [[NSStackView alloc] init];
    self.tabStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabStackView.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.tabStackView.alignment = NSLayoutAttributeBottom;
    self.tabStackView.distribution = NSStackViewDistributionFill;
    self.tabStackView.spacing = 8;
    [self.tabBarView addSubview:self.tabStackView];

    self.tabDropIndicator = [[NSView alloc] initWithFrame:NSZeroRect];
    self.tabDropIndicator.wantsLayer = YES;
    self.tabDropIndicator.layer.backgroundColor = TDMinimalColor(18, 18, 18, 1).CGColor;
    self.tabDropIndicator.layer.cornerRadius = 1.5;
    self.tabDropIndicator.hidden = YES;
    [self.tabBarView addSubview:self.tabDropIndicator];

    self.tabButtons = [NSMutableArray array];
    [self configureTabsPreservingSelection:NO];

    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.hasVerticalScroller = YES;
    scrollView.drawsBackground = NO;
    [contentView addSubview:scrollView];

    self.tableView = [[TDTaskTableView alloc] init];
    self.tableView.headerView = nil;
    self.tableView.backgroundColor = NSColor.clearColor;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = 82;
    self.tableView.intercellSpacing = NSMakeSize(0, 2);
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
    self.tableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    self.tableView.doubleAction = @selector(toggleSelectedTask:);
    self.tableView.target = self;
    self.tableView.keyActionTarget = self;
    self.tableView.deleteAction = @selector(deleteSelectedTask:);
    self.tableView.renameAction = @selector(renameSelectedTask:);
    self.tableView.timerAction = @selector(toggleTimerForSelectedTask:);
    self.tableView.focusAddAction = @selector(focusAddTaskField:);
    self.tableView.switchTabAction = @selector(switchTabFromShortcut:);
    [self.tableView registerForDraggedTypes:@[TDTaskDragType]];
    [self.tableView setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];

    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"task"];
    column.resizingMask = NSTableColumnAutoresizingMask;
    [self.tableView addTableColumn:column];
    scrollView.documentView = self.tableView;

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Task"];
    [menu addItemWithTitle:@"重新命名" action:@selector(renameSelectedTask:) keyEquivalent:@""].target = self;
    [menu addItemWithTitle:@"開始/暫停/繼續計時" action:@selector(toggleTimerForSelectedTask:) keyEquivalent:@""].target = self;
    [menu addItemWithTitle:@"取消計時" action:@selector(cancelTimerForSelectedTask:) keyEquivalent:@""].target = self;
    [menu addItem:NSMenuItem.separatorItem];
    [menu addItemWithTitle:@"刪除" action:@selector(deleteSelectedTask:) keyEquivalent:@""].target = self;
    self.tableView.menu = menu;

    NSView *bottomBar = [[NSView alloc] init];
    bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    bottomBar.wantsLayer = YES;
    bottomBar.layer.backgroundColor = TDMinimalColor(238, 237, 233, 1).CGColor;
    [contentView addSubview:bottomBar];

    self.searchField = [[NSSearchField alloc] init];
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchField.placeholderString = @"搜尋";
    self.searchField.target = self;
    self.searchField.action = @selector(searchChanged:);
    self.searchField.sendsSearchStringImmediately = YES;
    self.searchField.focusRingType = NSFocusRingTypeNone;
    [bottomBar addSubview:self.searchField];

    self.inputField = [[NSTextField alloc] init];
    self.inputField.translatesAutoresizingMaskIntoConstraints = NO;
    self.inputField.placeholderString = @"加入今日事項";
    self.inputField.backgroundColor = TDMinimalColor(250, 249, 246, 1);
    self.inputField.textColor = TDMinimalColor(18, 18, 18, 1);
    self.inputField.focusRingType = NSFocusRingTypeNone;
    self.inputField.target = self;
    self.inputField.action = @selector(addTask:);
    [bottomBar addSubview:self.inputField];

    self.hoursField = [self durationFieldWithPlaceholder:@"0"];
    [bottomBar addSubview:self.hoursField];

    self.hoursLabel = [NSTextField labelWithString:@"hr"];
    self.hoursLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.hoursLabel.textColor = TDMinimalColor(112, 112, 108, 1);
    self.hoursLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    [bottomBar addSubview:self.hoursLabel];

    self.minutesField = [self durationFieldWithPlaceholder:@"0"];
    [bottomBar addSubview:self.minutesField];

    self.minutesLabel = [NSTextField labelWithString:@"min"];
    self.minutesLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.minutesLabel.textColor = TDMinimalColor(112, 112, 108, 1);
    self.minutesLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    [bottomBar addSubview:self.minutesLabel];

    self.addButton = [NSButton buttonWithTitle:@"新增" target:self action:@selector(addTask:)];
    self.addButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.addButton.bezelStyle = NSBezelStyleRounded;
    self.addButton.contentTintColor = TDMinimalColor(18, 18, 18, 1);
    self.addButton.refusesFirstResponder = NO;
    [bottomBar addSubview:self.addButton];

    self.reviewButton = [NSButton buttonWithTitle:@"搬返今日" target:self action:@selector(moveVisiblePastIncompleteBackToToday:)];
    self.reviewButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.reviewButton.bezelStyle = NSBezelStyleRounded;
    self.reviewButton.contentTintColor = TDMinimalColor(18, 18, 18, 1);
    [bottomBar addSubview:self.reviewButton];

    self.statusLabel = [NSTextField labelWithString:@""];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.textColor = TDMinimalColor(112, 112, 108, 1);
    self.statusLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    [bottomBar addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.tabBarView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        [self.tabBarView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
        [self.tabBarView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:12],
        [self.tabBarView.heightAnchor constraintEqualToConstant:34],

        [self.tabStackView.leadingAnchor constraintEqualToAnchor:self.tabBarView.leadingAnchor],
        [self.tabStackView.trailingAnchor constraintEqualToAnchor:self.tabBarView.trailingAnchor],
        [self.tabStackView.topAnchor constraintEqualToAnchor:self.tabBarView.topAnchor],
        [self.tabStackView.bottomAnchor constraintEqualToAnchor:self.tabBarView.bottomAnchor],

        [scrollView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:self.tabBarView.bottomAnchor constant:4],
        [scrollView.bottomAnchor constraintEqualToAnchor:bottomBar.topAnchor],

        [bottomBar.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [bottomBar.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [bottomBar.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
        [bottomBar.heightAnchor constraintEqualToConstant:92],

        [self.searchField.leadingAnchor constraintEqualToAnchor:bottomBar.leadingAnchor constant:16],
        [self.searchField.trailingAnchor constraintEqualToAnchor:bottomBar.trailingAnchor constant:-16],
        [self.searchField.topAnchor constraintEqualToAnchor:bottomBar.topAnchor constant:8],
        [self.searchField.heightAnchor constraintEqualToConstant:26],

        [self.inputField.leadingAnchor constraintEqualToAnchor:bottomBar.leadingAnchor constant:16],
        [self.inputField.centerYAnchor constraintEqualToAnchor:bottomBar.bottomAnchor constant:-28],
        [self.inputField.trailingAnchor constraintEqualToAnchor:self.hoursField.leadingAnchor constant:-10],
        [self.inputField.heightAnchor constraintEqualToConstant:28],

        [self.hoursField.centerYAnchor constraintEqualToAnchor:self.inputField.centerYAnchor],
        [self.hoursField.widthAnchor constraintEqualToConstant:42],
        [self.hoursField.heightAnchor constraintEqualToConstant:28],

        [self.hoursLabel.leadingAnchor constraintEqualToAnchor:self.hoursField.trailingAnchor constant:4],
        [self.hoursLabel.centerYAnchor constraintEqualToAnchor:self.inputField.centerYAnchor],

        [self.minutesField.leadingAnchor constraintEqualToAnchor:self.hoursLabel.trailingAnchor constant:8],
        [self.minutesField.centerYAnchor constraintEqualToAnchor:self.inputField.centerYAnchor],
        [self.minutesField.widthAnchor constraintEqualToConstant:42],
        [self.minutesField.heightAnchor constraintEqualToConstant:28],

        [self.minutesLabel.leadingAnchor constraintEqualToAnchor:self.minutesField.trailingAnchor constant:4],
        [self.minutesLabel.centerYAnchor constraintEqualToAnchor:self.inputField.centerYAnchor],

        [self.addButton.leadingAnchor constraintEqualToAnchor:self.minutesLabel.trailingAnchor constant:10],
        [self.addButton.trailingAnchor constraintEqualToAnchor:bottomBar.trailingAnchor constant:-16],
        [self.addButton.centerYAnchor constraintEqualToAnchor:self.inputField.centerYAnchor],
        [self.addButton.widthAnchor constraintEqualToConstant:72],

        [self.reviewButton.trailingAnchor constraintEqualToAnchor:bottomBar.trailingAnchor constant:-16],
        [self.reviewButton.centerYAnchor constraintEqualToAnchor:self.inputField.centerYAnchor],
        [self.reviewButton.widthAnchor constraintEqualToConstant:92],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:bottomBar.leadingAnchor constant:16],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.inputField.centerYAnchor],
        [self.statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.reviewButton.leadingAnchor constant:-10]
    ]];

    [self configureAddTaskKeyLoop];
}

- (void)configureAddTaskKeyLoop {
    self.inputField.nextKeyView = self.hoursField;
    self.hoursField.nextKeyView = self.minutesField;
    self.minutesField.nextKeyView = self.addButton;
    self.addButton.nextKeyView = self.inputField;
    self.window.initialFirstResponder = self.inputField;
}

- (NSTextField *)durationFieldWithPlaceholder:(NSString *)placeholder {
    NSTextField *field = [[NSTextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.placeholderString = placeholder;
    field.alignment = NSTextAlignmentCenter;
    field.backgroundColor = TDMinimalColor(250, 249, 246, 1);
    field.textColor = TDMinimalColor(18, 18, 18, 1);
    field.focusRingType = NSFocusRingTypeNone;
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.minimum = @0;
    formatter.allowsFloats = NO;
    field.formatter = formatter;
    return field;
}

- (void)tabButtonPressed:(NSButton *)sender {
    NSInteger index = sender.tag;
    if (index == [self addSegmentIndex]) {
        [self promptForNewCustomList];
        return;
    }

    self.selectedTabIndex = index;
    self.previousSelectedTabIndex = index;
    [self refreshTabButtonStyles];
    [self reloadVisibleTasksAnimated:YES];
}

- (void)refreshForClock:(NSTimer *)timer {
    (void)timer;
    [self reloadVisibleTasks];
}

- (void)addTask:(id)sender {
    (void)sender;
    NSString *title = [self.inputField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (title.length == 0 || ![self canAddInCurrentTab]) {
        return;
    }

    NSInteger estimatedMinutes = [self estimatedMinutesFromInputs];
    NSString *customListID = [self currentCustomListID];
    if (customListID != nil) {
        [self.todoList addTaskWithTitle:title customListID:customListID estimatedMinutes:estimatedMinutes now:[NSDate date]];
    } else {
        [self.todoList addTaskWithTitle:title
                                 bucket:TDTaskBucketToday
                       estimatedMinutes:estimatedMinutes
                               dayOffset:[self currentDayOffset]
                                    now:[NSDate date]
                               calendar:self.calendar
                     todayCutoffMinutes:self.todayCutoffMinutes];
    }
    self.inputField.stringValue = @"";
    self.hoursField.stringValue = @"";
    self.minutesField.stringValue = @"";
    [self saveTasks];
    [self reloadVisibleTasksAnimated:YES];
    [self.window makeFirstResponder:self.inputField];
}

- (void)searchChanged:(NSSearchField *)sender {
    self.searchQuery = sender.stringValue ?: @"";
    [self reloadVisibleTasksAnimated:NO];
}

- (void)toggleSelectedTask:(id)sender {
    (void)sender;
    NSInteger row = self.tableView.clickedRow >= 0 ? self.tableView.clickedRow : self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)self.visibleTasks.count) {
        return;
    }

    TDTodoTask *task = self.visibleTasks[(NSUInteger)row];
    [self.todoList toggleCompletionForTaskID:task.identifier atDate:[NSDate date]];
    if (task.completedAt != nil) {
        [self cancelTimerForTaskID:task.identifier];
    }
    [self saveTasks];
    [self reloadVisibleTasksAnimated:YES];
}

- (void)deleteSelectedTask:(id)sender {
    (void)sender;
    [self deleteTaskAtRow:self.tableView.selectedRow animated:YES];
}

- (void)renameSelectedTask:(id)sender {
    (void)sender;
    NSInteger row = self.tableView.clickedRow >= 0 ? self.tableView.clickedRow : self.tableView.selectedRow;
    [self renameTaskAtRow:row];
}

- (void)renameTaskAtRow:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.visibleTasks.count) {
        return;
    }

    TDTodoTask *task = self.visibleTasks[(NSUInteger)row];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"重新命名";
    alert.informativeText = @"輸入新的事項名稱。";
    [alert addButtonWithTitle:@"儲存"];
    [alert addButtonWithTitle:@"取消"];

    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 280, 28)];
    textField.stringValue = task.title;
    alert.accessoryView = textField;

    NSModalResponse response = [alert runModal];
    if (response != NSAlertFirstButtonReturn) {
        return;
    }
    if ([self.todoList renameTaskWithID:task.identifier title:textField.stringValue]) {
        [self saveTasks];
        [self reloadVisibleTasksAnimated:YES];
    }
}

- (void)focusAddTaskField:(id)sender {
    (void)sender;
    if (![self canAddInCurrentTab]) {
        return;
    }
    [self.window makeFirstResponder:self.inputField];
}

- (void)moveVisiblePastIncompleteBackToToday:(id)sender {
    (void)sender;
    if ([self currentTab] != TDTaskTabPastIncomplete) {
        return;
    }
    NSArray<TDTodoTask *> *movedTasks = [self.todoList moveTasksBackToToday:self.visibleTasks
                                                                        now:[NSDate date]
                                                                   calendar:self.calendar
                                                         todayCutoffMinutes:self.todayCutoffMinutes];
    if (movedTasks.count == 0) {
        return;
    }
    [self saveTasks];
    [self reloadVisibleTasksAnimated:YES];
}

- (void)promptForTodayCutoffTime:(id)sender {
    (void)sender;
    NSDate *now = [NSDate date];
    NSArray<NSString *> *todayTaskIDs = [self taskIDsForTab:TDTaskTabToday now:now todayCutoffMinutes:self.todayCutoffMinutes];
    NSArray<NSString *> *tomorrowTaskIDs = [self taskIDsForTab:TDTaskTabTomorrow now:now todayCutoffMinutes:self.todayCutoffMinutes];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"今日到期時間";
    alert.informativeText = @"輸入 24 小時制時間，例如 0000、0600 或 06:00。";
    [alert addButtonWithTitle:@"儲存"];
    [alert addButtonWithTitle:@"取消"];

    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 180, 28)];
    textField.stringValue = [self cutoffTimeTextForMinutes:self.todayCutoffMinutes];
    textField.placeholderString = @"0600";
    alert.accessoryView = textField;

    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }

    NSNumber *minutes = [self cutoffMinutesFromString:textField.stringValue];
    if (minutes == nil) {
        NSAlert *errorAlert = [[NSAlert alloc] init];
        errorAlert.messageText = @"時間格式錯誤";
        errorAlert.informativeText = @"請輸入 0000 至 2359，例如 0600 或 06:00。";
        [errorAlert addButtonWithTitle:@"知道"];
        [errorAlert runModal];
        return;
    }

    NSInteger newCutoffMinutes = minutes.integerValue;
    self.todayCutoffMinutes = newCutoffMinutes;
    [NSUserDefaults.standardUserDefaults setInteger:newCutoffMinutes forKey:TDTodayCutoffMinutesDefaultsKey];
    [self.todoList retargetTasksWithIDs:todayTaskIDs
                            toDayOffset:0
                                    now:now
                               calendar:self.calendar
                     todayCutoffMinutes:newCutoffMinutes];
    [self.todoList retargetTasksWithIDs:tomorrowTaskIDs
                            toDayOffset:1
                                    now:now
                               calendar:self.calendar
                     todayCutoffMinutes:newCutoffMinutes];
    [self saveTasks];
    [self reloadVisibleTasksAnimated:YES];
}

- (void)toggleTimerForSelectedTask:(id)sender {
    (void)sender;
    NSInteger row = self.tableView.clickedRow >= 0 ? self.tableView.clickedRow : self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)self.visibleTasks.count) {
        return;
    }
    [self toggleTimerForTask:self.visibleTasks[(NSUInteger)row]];
    [self.tableView reloadData];
}

- (void)cancelTimerForSelectedTask:(id)sender {
    (void)sender;
    NSInteger row = self.tableView.clickedRow >= 0 ? self.tableView.clickedRow : self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)self.visibleTasks.count) {
        return;
    }
    [self cancelTimerForTaskID:self.visibleTasks[(NSUInteger)row].identifier];
    [self.tableView reloadData];
}

- (void)switchTabFromShortcut:(NSNumber *)shortcutIndex {
    NSInteger index = shortcutIndex.integerValue;
    if (index < 0 || index >= (NSInteger)self.tabOrder.count) {
        return;
    }
    self.selectedTabIndex = index;
    self.previousSelectedTabIndex = index;
    [self refreshTabButtonStyles];
    [self reloadVisibleTasksAnimated:YES];
}

- (void)deleteTaskAtRow:(NSInteger)row animated:(BOOL)animated {
    if (row < 0 || row >= (NSInteger)self.visibleTasks.count) {
        return;
    }

    TDTodoTask *task = self.visibleTasks[(NSUInteger)row];
    [self cancelTimerForTaskID:task.identifier];
    for (TDTodoTask *descendant in [self.todoList descendantsForTaskID:task.identifier]) {
        [self cancelTimerForTaskID:descendant.identifier];
    }
    [self.todoList deleteTaskWithID:task.identifier];
    [self saveTasks];
    [self reloadVisibleTasksAnimated:animated];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return (NSInteger)self.visibleTasks.count;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    (void)tableView;
    if (row < 0 || row >= (NSInteger)self.visibleTasks.count) {
        return 82;
    }

    return 82;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    (void)tableColumn;
    TDTaskCellView *cell = [tableView makeViewWithIdentifier:@"TaskCell" owner:self];
    if (cell == nil) {
        cell = [[TDTaskCellView alloc] initWithFrame:NSZeroRect];
        cell.identifier = @"TaskCell";
    }
    TDTodoTask *task = self.visibleTasks[(NSUInteger)row];
    NSTimeInterval remainingSeconds = [self remainingSecondsForTask:task];
    NSString *timerState = [self timerStateForTask:task];
    BOOL hasChildren = [self.todoList childrenForTaskID:task.identifier].count > 0;
    BOOL collapsed = [self isTaskCollapsed:task.identifier];
    [cell configureWithTask:task
           remainingSeconds:remainingSeconds
                 timerState:timerState
                hasChildren:hasChildren
                  collapsed:collapsed];
    cell.timerButton.target = self;
    cell.timerButton.action = @selector(toggleTimerForTaskButton:);
    cell.timerButton.tag = row;
    cell.disclosureButton.target = self;
    cell.disclosureButton.action = @selector(toggleCollapseForTaskButton:);
    cell.disclosureButton.tag = row;
    cell.descriptionButton.target = self;
    cell.descriptionButton.action = @selector(editDescriptionForTaskButton:);
    cell.descriptionButton.tag = row;
    return cell;
}

- (void)editDescriptionForTaskButton:(NSButton *)sender {
    NSInteger row = sender.tag;
    if (row < 0 || row >= (NSInteger)self.visibleTasks.count) {
        return;
    }
    [self editDescriptionForTaskAtRow:row];
}

- (void)editDescriptionForTaskAtRow:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.visibleTasks.count) {
        return;
    }

    TDTodoTask *task = self.visibleTasks[(NSUInteger)row];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"事項資料";
    alert.informativeText = [NSString stringWithFormat:@"修改「%@」的描述和預計時間。", task.title];
    [alert addButtonWithTitle:@"儲存"];
    [alert addButtonWithTitle:@"清除"];
    [alert addButtonWithTitle:@"取消"];

    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 136)];

    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.hasVerticalScroller = YES;
    NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 320, 84)];
    textView.string = task.taskDescription ?: @"";
    textView.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    scrollView.documentView = textView;
    [container addSubview:scrollView];

    NSTextField *hoursField = [self durationFieldWithPlaceholder:@"0"];
    hoursField.integerValue = task.estimatedMinutes / 60;
    NSTextField *hoursLabel = [NSTextField labelWithString:@"hr"];
    hoursLabel.translatesAutoresizingMaskIntoConstraints = NO;
    hoursLabel.textColor = TDMinimalColor(112, 112, 108, 1);
    NSTextField *minutesField = [self durationFieldWithPlaceholder:@"0"];
    minutesField.integerValue = task.estimatedMinutes % 60;
    NSTextField *minutesLabel = [NSTextField labelWithString:@"min"];
    minutesLabel.translatesAutoresizingMaskIntoConstraints = NO;
    minutesLabel.textColor = TDMinimalColor(112, 112, 108, 1);
    [container addSubview:hoursField];
    [container addSubview:hoursLabel];
    [container addSubview:minutesField];
    [container addSubview:minutesLabel];

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [scrollView.heightAnchor constraintEqualToConstant:86],

        [hoursField.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [hoursField.topAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:16],
        [hoursField.widthAnchor constraintEqualToConstant:58],
        [hoursField.heightAnchor constraintEqualToConstant:28],

        [hoursLabel.leadingAnchor constraintEqualToAnchor:hoursField.trailingAnchor constant:6],
        [hoursLabel.centerYAnchor constraintEqualToAnchor:hoursField.centerYAnchor],

        [minutesField.leadingAnchor constraintEqualToAnchor:hoursLabel.trailingAnchor constant:18],
        [minutesField.topAnchor constraintEqualToAnchor:hoursField.topAnchor],
        [minutesField.widthAnchor constraintEqualToConstant:58],
        [minutesField.heightAnchor constraintEqualToConstant:28],

        [minutesLabel.leadingAnchor constraintEqualToAnchor:minutesField.trailingAnchor constant:6],
        [minutesLabel.centerYAnchor constraintEqualToAnchor:minutesField.centerYAnchor]
    ]];
    alert.accessoryView = container;

    NSModalResponse response = [alert runModal];
    if (response == NSAlertThirdButtonReturn) {
        return;
    }

    NSString *description = response == NSAlertSecondButtonReturn ? @"" : textView.string;
    NSInteger estimatedMinutes = response == NSAlertSecondButtonReturn ? 0 : [self estimatedMinutesFromHoursField:hoursField minutesField:minutesField];
    if ([self.todoList updateDetailsForTaskID:task.identifier description:description estimatedMinutes:estimatedMinutes]) {
        [self saveTasks];
        [self reloadVisibleTasksAnimated:YES];
    }
}

- (void)toggleCollapseForTaskButton:(NSButton *)sender {
    NSInteger row = sender.tag;
    if (row < 0 || row >= (NSInteger)self.visibleTasks.count) {
        return;
    }
    TDTodoTask *task = self.visibleTasks[(NSUInteger)row];
    if (task.parentTaskID.length > 0 || [self.todoList childrenForTaskID:task.identifier].count == 0) {
        return;
    }
    if ([self.collapsedTaskIDs containsObject:task.identifier]) {
        [self.collapsedTaskIDs removeObject:task.identifier];
    } else {
        [self.collapsedTaskIDs addObject:task.identifier];
    }
    [self persistCollapsedTaskIDs];
    [self reloadVisibleTasksAnimated:YES];
}

- (NSArray<NSTableViewRowAction *> *)tableView:(NSTableView *)tableView
                            rowActionsForRow:(NSInteger)row
                                        edge:(NSTableRowActionEdge)edge {
    (void)tableView;
    if (row < 0 || row >= (NSInteger)self.visibleTasks.count) {
        return @[];
    }
    if (edge == NSTableRowActionEdgeLeading) {
        NSTableViewRowAction *subtaskAction = [NSTableViewRowAction rowActionWithStyle:NSTableViewRowActionStyleRegular
                                                                                 title:@"子任務"
                                                                               handler:^(__kindof NSTableViewRowAction *action, NSInteger actionRow) {
            (void)action;
            [self promptForSubtaskAtRow:actionRow];
        }];
        subtaskAction.backgroundColor = TDMinimalColor(28, 28, 28, 1);
        return @[subtaskAction];
    }
    if (edge != NSTableRowActionEdgeTrailing) {
        return @[];
    }

    NSTableViewRowAction *deleteAction = [NSTableViewRowAction rowActionWithStyle:NSTableViewRowActionStyleDestructive
                                                                            title:@"刪除"
                                                                          handler:^(__kindof NSTableViewRowAction *action, NSInteger actionRow) {
        (void)action;
        [self deleteTaskAtRow:actionRow animated:YES];
    }];
    deleteAction.backgroundColor = TDMinimalColor(28, 28, 28, 1);
    return @[deleteAction];
}

- (void)promptForSubtaskAtRow:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.visibleTasks.count) {
        return;
    }

    TDTodoTask *task = self.visibleTasks[(NSUInteger)row];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"新增子任務";
    alert.informativeText = [NSString stringWithFormat:@"加到「%@」下面。", task.title];
    [alert addButtonWithTitle:@"新增"];
    [alert addButtonWithTitle:@"取消"];

    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 66)];

    NSTextField *textField = [[NSTextField alloc] init];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.placeholderString = @"子任務名稱";
    [container addSubview:textField];

    NSTextField *hoursField = [self durationFieldWithPlaceholder:@"0"];
    NSTextField *hoursLabel = [NSTextField labelWithString:@"hr"];
    hoursLabel.translatesAutoresizingMaskIntoConstraints = NO;
    hoursLabel.textColor = TDMinimalColor(112, 112, 108, 1);
    NSTextField *minutesField = [self durationFieldWithPlaceholder:@"0"];
    NSTextField *minutesLabel = [NSTextField labelWithString:@"min"];
    minutesLabel.translatesAutoresizingMaskIntoConstraints = NO;
    minutesLabel.textColor = TDMinimalColor(112, 112, 108, 1);
    [container addSubview:hoursField];
    [container addSubview:hoursLabel];
    [container addSubview:minutesField];
    [container addSubview:minutesLabel];

    [NSLayoutConstraint activateConstraints:@[
        [textField.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [textField.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [textField.topAnchor constraintEqualToAnchor:container.topAnchor],
        [textField.heightAnchor constraintEqualToConstant:28],

        [hoursField.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [hoursField.topAnchor constraintEqualToAnchor:textField.bottomAnchor constant:10],
        [hoursField.widthAnchor constraintEqualToConstant:58],
        [hoursField.heightAnchor constraintEqualToConstant:28],

        [hoursLabel.leadingAnchor constraintEqualToAnchor:hoursField.trailingAnchor constant:6],
        [hoursLabel.centerYAnchor constraintEqualToAnchor:hoursField.centerYAnchor],

        [minutesField.leadingAnchor constraintEqualToAnchor:hoursLabel.trailingAnchor constant:18],
        [minutesField.topAnchor constraintEqualToAnchor:hoursField.topAnchor],
        [minutesField.widthAnchor constraintEqualToConstant:58],
        [minutesField.heightAnchor constraintEqualToConstant:28],

        [minutesLabel.leadingAnchor constraintEqualToAnchor:minutesField.trailingAnchor constant:6],
        [minutesLabel.centerYAnchor constraintEqualToAnchor:minutesField.centerYAnchor]
    ]];
    alert.accessoryView = container;

    NSModalResponse response = [alert runModal];
    if (response != NSAlertFirstButtonReturn) {
        return;
    }

    NSString *title = [textField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (title.length == 0) {
        return;
    }

    NSInteger estimatedMinutes = [self estimatedMinutesFromHoursField:hoursField minutesField:minutesField];
    [self.todoList addSubtaskWithTitle:title parentTaskID:task.identifier estimatedMinutes:estimatedMinutes now:[NSDate date]];
    [self saveTasks];
    [self reloadVisibleTasksAnimated:YES];
}

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pasteboard {
    (void)tableView;
    if (![self canReorderCurrentTab] || rowIndexes.count == 0) {
        return NO;
    }
    self.draggedRows = rowIndexes;
    self.liveDraggedRowIndex = (NSInteger)rowIndexes.firstIndex;
    self.draggedTaskID = self.liveDraggedRowIndex >= 0 && self.liveDraggedRowIndex < (NSInteger)self.visibleTasks.count
        ? self.visibleTasks[(NSUInteger)self.liveDraggedRowIndex].identifier
        : nil;
    [pasteboard declareTypes:@[TDTaskDragType] owner:nil];
    [pasteboard setString:@"task-row" forType:TDTaskDragType];
    return YES;
}

- (void)tableView:(NSTableView *)tableView
  draggingSession:(NSDraggingSession *)session
 willBeginAtPoint:(NSPoint)screenPoint
    forRowIndexes:(NSIndexSet *)rowIndexes {
    (void)tableView;
    (void)session;
    (void)screenPoint;
    self.draggedRows = rowIndexes;
    self.liveDraggedRowIndex = (NSInteger)rowIndexes.firstIndex;
    self.draggedTaskID = self.liveDraggedRowIndex >= 0 && self.liveDraggedRowIndex < (NSInteger)self.visibleTasks.count
        ? self.visibleTasks[(NSUInteger)self.liveDraggedRowIndex].identifier
        : nil;
    self.preDragTaskSortOrders = [self taskSortOrderSnapshot];
    self.blockDragAccepted = NO;
    [self setDraggedRowsDimmed:YES];
}

- (void)tableView:(NSTableView *)tableView
  draggingSession:(NSDraggingSession *)session
     endedAtPoint:(NSPoint)screenPoint
        operation:(NSDragOperation)operation {
    (void)tableView;
    (void)session;
    (void)screenPoint;
    if (operation != NSDragOperationMove && !self.blockDragAccepted) {
        [self restoreTaskSortOrdersFromSnapshot];
        [self reloadVisibleTasksAnimated:YES];
    }
    [self clearDragFeedback];
}

- (NSDragOperation)tableView:(NSTableView *)tableView
                validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    (void)info;
    if (![self canReorderCurrentTab] || dropOperation != NSTableViewDropAbove) {
        self.tableView.showsDropIndicator = NO;
        return NSDragOperationNone;
    }
    self.tableView.showsDropIndicator = NO;
    [self liveReflowDraggedBlockToDropRow:row];
    [tableView setDropRow:row dropOperation:NSTableViewDropAbove];
    return NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)tableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)dropOperation {
    (void)tableView;
    (void)info;
    (void)dropOperation;
    if (![self canReorderCurrentTab] || self.draggedRows.count == 0) {
        [self clearDragFeedback];
        return NO;
    }

    self.blockDragAccepted = YES;
    [self saveTasks];
    [self clearDragFeedback];
    [self.tableView reloadData];
    return YES;
}

- (void)liveReflowDraggedBlockToDropRow:(NSInteger)dropRow {
    if (self.draggedTaskID.length == 0 || self.liveDraggedRowIndex < 0 || self.liveDraggedRowIndex >= (NSInteger)self.visibleTasks.count) {
        return;
    }

    NSInteger clampedDropRow = MAX(0, MIN(dropRow, (NSInteger)self.visibleTasks.count));
    if (clampedDropRow == self.liveDraggedRowIndex || clampedDropRow == self.liveDraggedRowIndex + 1) {
        return;
    }

    NSUInteger sourceIndex = (NSUInteger)self.liveDraggedRowIndex;
    NSUInteger destinationIndex = (NSUInteger)clampedDropRow;
    NSString *customListID = [self currentCustomListID];
    if (customListID != nil) {
        [self.todoList moveVisibleTaskFromIndex:sourceIndex toIndex:destinationIndex customListID:customListID];
    } else {
        [self.todoList moveVisibleTaskFromIndex:sourceIndex
                                        toIndex:destinationIndex
                                            tab:[self currentTab]
                                            now:[NSDate date]
                                       calendar:self.calendar
                             todayCutoffMinutes:self.todayCutoffMinutes];
    }

    NSString *draggedTaskID = self.draggedTaskID;
    [self refreshVisibleTasksOnly];
    NSInteger newIndex = [self indexOfVisibleTaskID:draggedTaskID];
    if (newIndex < 0) {
        [self.tableView reloadData];
        return;
    }

    NSInteger oldIndex = self.liveDraggedRowIndex;
    self.liveDraggedRowIndex = newIndex;
    self.draggedRows = [NSIndexSet indexSetWithIndex:(NSUInteger)newIndex];
    if (oldIndex == newIndex) {
        [self.tableView reloadData];
        return;
    }

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.14;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.tableView beginUpdates];
        if (oldIndex >= 0 && oldIndex < self.tableView.numberOfRows && newIndex >= 0 && newIndex < self.tableView.numberOfRows) {
            [self.tableView moveRowAtIndex:oldIndex toIndex:newIndex];
        }
        [self.tableView endUpdates];
    } completionHandler:^{
        [self setDraggedRowsDimmed:YES];
    }];
}

- (void)setDraggedRowsDimmed:(BOOL)dimmed {
    [self.draggedRows enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
        (void)stop;
        NSTableRowView *rowView = [self.tableView rowViewAtRow:(NSInteger)index makeIfNecessary:NO];
        if (rowView == nil) {
            return;
        }
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = dimmed ? 0.12 : 0.08;
            rowView.animator.alphaValue = dimmed ? 0.36 : 1.0;
        } completionHandler:nil];
    }];
}

- (void)clearDragFeedback {
    [self setDraggedRowsDimmed:NO];
    self.draggedRows = nil;
    self.draggedTaskID = nil;
    self.preDragTaskSortOrders = nil;
    self.liveDraggedRowIndex = -1;
    self.blockDragAccepted = NO;
    self.tableView.showsDropIndicator = NO;
    self.tableView.dropIndicatorRow = -1;
}

- (NSDictionary<NSString *, NSNumber *> *)taskSortOrderSnapshot {
    NSMutableDictionary<NSString *, NSNumber *> *snapshot = [NSMutableDictionary dictionaryWithCapacity:self.todoList.tasks.count];
    for (TDTodoTask *task in self.todoList.tasks) {
        snapshot[task.identifier] = @(task.sortOrder);
    }
    return snapshot;
}

- (void)restoreTaskSortOrdersFromSnapshot {
    for (TDTodoTask *task in self.todoList.tasks) {
        NSNumber *sortOrder = self.preDragTaskSortOrders[task.identifier];
        if (sortOrder != nil) {
            task.sortOrder = sortOrder.integerValue;
        }
    }
}

- (void)reloadVisibleTasks {
    [self reloadVisibleTasksAnimated:NO];
}

- (void)refreshVisibleTasksOnly {
    NSString *customListID = [self currentCustomListID];
    NSArray<TDTodoTask *> *tasks = customListID != nil
        ? [self.todoList tasksForCustomListID:customListID]
        : [self.todoList tasksForTab:[self currentTab] now:[NSDate date] calendar:self.calendar todayCutoffMinutes:self.todayCutoffMinutes];
    self.visibleTasks = [self filteredTasksFromTasks:tasks];
}

- (NSArray<TDTodoTask *> *)filteredTasksFromTasks:(NSArray<TDTodoTask *> *)tasks {
    NSString *query = [[self.searchQuery stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    if (query.length == 0) {
        NSMutableArray<TDTodoTask *> *result = [NSMutableArray arrayWithCapacity:tasks.count];
        for (TDTodoTask *task in tasks) {
            if (task.parentTaskID.length > 0 && [self.collapsedTaskIDs containsObject:task.parentTaskID]) {
                continue;
            }
            [result addObject:task];
        }
        return result;
    }

    NSMutableDictionary<NSString *, TDTodoTask *> *tasksByID = [NSMutableDictionary dictionaryWithCapacity:tasks.count];
    NSMutableDictionary<NSString *, NSMutableArray<TDTodoTask *> *> *childrenByParentID = [NSMutableDictionary dictionary];
    for (TDTodoTask *task in tasks) {
        tasksByID[task.identifier] = task;
    }
    for (TDTodoTask *task in tasks) {
        if (task.parentTaskID.length == 0 || tasksByID[task.parentTaskID] == nil) {
            continue;
        }
        NSMutableArray<TDTodoTask *> *children = childrenByParentID[task.parentTaskID];
        if (children == nil) {
            children = [NSMutableArray array];
            childrenByParentID[task.parentTaskID] = children;
        }
        [children addObject:task];
    }

    NSMutableArray<TDTodoTask *> *result = [NSMutableArray array];
    NSMutableSet<NSString *> *addedTaskIDs = [NSMutableSet set];
    for (TDTodoTask *task in tasks) {
        if (task.parentTaskID.length > 0 && tasksByID[task.parentTaskID] != nil) {
            continue;
        }

        BOOL parentMatches = [self task:task matchesSearchQuery:query];
        NSArray<TDTodoTask *> *children = childrenByParentID[task.identifier] ?: @[];
        NSMutableArray<TDTodoTask *> *matchingChildren = [NSMutableArray array];
        for (TDTodoTask *child in children) {
            if ([self task:child matchesSearchQuery:query]) {
                [matchingChildren addObject:child];
            }
        }

        if (parentMatches || matchingChildren.count > 0) {
            [self addTask:task toFilteredResult:result addedTaskIDs:addedTaskIDs];
            NSArray<TDTodoTask *> *childrenToAdd = parentMatches ? children : matchingChildren;
            for (TDTodoTask *child in childrenToAdd) {
                [self addTask:child toFilteredResult:result addedTaskIDs:addedTaskIDs];
            }
        } else if (task.parentTaskID.length > 0 && [self task:task matchesSearchQuery:query]) {
            [self addTask:task toFilteredResult:result addedTaskIDs:addedTaskIDs];
        }
    }
    return result;
}

- (BOOL)task:(TDTodoTask *)task matchesSearchQuery:(NSString *)query {
    return [[task.title lowercaseString] containsString:query];
}

- (void)addTask:(TDTodoTask *)task
toFilteredResult:(NSMutableArray<TDTodoTask *> *)result
   addedTaskIDs:(NSMutableSet<NSString *> *)addedTaskIDs {
    if ([addedTaskIDs containsObject:task.identifier]) {
        return;
    }
    [result addObject:task];
    [addedTaskIDs addObject:task.identifier];
}

- (BOOL)isTaskCollapsed:(NSString *)taskID {
    NSString *query = [self.searchQuery stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return query.length == 0 && [self.collapsedTaskIDs containsObject:taskID];
}

- (void)persistCollapsedTaskIDs {
    [NSUserDefaults.standardUserDefaults setObject:self.collapsedTaskIDs.allObjects forKey:TDCollapsedTaskIDsDefaultsKey];
}

- (NSInteger)indexOfVisibleTaskID:(NSString *)taskID {
    __block NSInteger foundIndex = -1;
    [self.visibleTasks enumerateObjectsUsingBlock:^(TDTodoTask *task, NSUInteger index, BOOL *stop) {
        if ([task.identifier isEqualToString:taskID]) {
            foundIndex = (NSInteger)index;
            *stop = YES;
        }
    }];
    return foundIndex;
}

- (void)reloadVisibleTasksAnimated:(BOOL)animated {
    [self refreshVisibleTasksOnly];

    if (!animated) {
        self.tableView.alphaValue = 1.0;
        [self.tableView reloadData];
        [self updateBottomBar];
        return;
    }

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.10;
        self.tableView.animator.alphaValue = 0.82;
    } completionHandler:^{
        [self.tableView reloadData];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.16;
            self.tableView.animator.alphaValue = 1.0;
        } completionHandler:nil];
    }];
    [self updateBottomBar];
}

- (void)animateMovedRowFromIndex:(NSUInteger)sourceIndex toDropIndex:(NSUInteger)dropIndex {
    NSString *customListID = [self currentCustomListID];
    self.visibleTasks = customListID != nil
        ? [self.todoList tasksForCustomListID:customListID]
        : [self.todoList tasksForTab:[self currentTab] now:[NSDate date] calendar:self.calendar todayCutoffMinutes:self.todayCutoffMinutes];

    NSUInteger destinationRow = sourceIndex < dropIndex ? dropIndex - 1 : dropIndex;
    if (sourceIndex < (NSUInteger)self.tableView.numberOfRows && destinationRow < self.visibleTasks.count) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.22;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [self.tableView beginUpdates];
            [self.tableView moveRowAtIndex:sourceIndex toIndex:destinationRow];
            [self.tableView endUpdates];
        } completionHandler:^{
            [self.tableView reloadData];
        }];
    } else {
        [self reloadVisibleTasksAnimated:YES];
    }
    [self updateBottomBar];
}

- (void)updateBottomBar {
    BOOL canAdd = [self canAddInCurrentTab];
    self.inputField.hidden = !canAdd;
    self.hoursField.hidden = !canAdd;
    self.hoursLabel.hidden = !canAdd;
    self.minutesField.hidden = !canAdd;
    self.minutesLabel.hidden = !canAdd;
    self.addButton.hidden = !canAdd;
    self.reviewButton.hidden = canAdd || [self currentTab] != TDTaskTabPastIncomplete || self.visibleTasks.count == 0;
    self.statusLabel.hidden = canAdd;

    TDCustomList *customList = [self currentCustomList];
    if (customList != nil) {
        self.inputField.placeholderString = [NSString stringWithFormat:@"加入「%@」事項", customList.name];
    } else if ([self currentTab] == TDTaskTabTomorrow) {
        self.inputField.placeholderString = @"加入明天事項";
    } else {
        self.inputField.placeholderString = @"加入今日事項";
    }
    self.statusLabel.stringValue = self.visibleTasks.count == 0 ? @"沒有紀錄" : [NSString stringWithFormat:@"%lu 項紀錄", (unsigned long)self.visibleTasks.count];
}

- (NSInteger)estimatedMinutesFromInputs {
    return [self estimatedMinutesFromHoursField:self.hoursField minutesField:self.minutesField];
}

- (NSInteger)estimatedMinutesFromHoursField:(NSTextField *)hoursField minutesField:(NSTextField *)minutesField {
    NSInteger hours = MAX(0, hoursField.integerValue);
    NSInteger minutes = MAX(0, MIN(59, minutesField.integerValue));
    return hours * 60 + minutes;
}

- (NSInteger)currentDayOffset {
    return [self currentTab] == TDTaskTabTomorrow ? 1 : 0;
}

- (NSInteger)savedTodayCutoffMinutes {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:TDTodayCutoffMinutesDefaultsKey];
    if (![value isKindOfClass:NSNumber.class]) {
        return 0;
    }
    return MAX(0, MIN(((NSNumber *)value).integerValue, 23 * 60 + 59));
}

- (NSString *)cutoffTimeTextForMinutes:(NSInteger)minutes {
    NSInteger clampedMinutes = MAX(0, MIN(minutes, 23 * 60 + 59));
    return [NSString stringWithFormat:@"%02ld%02ld", (long)(clampedMinutes / 60), (long)(clampedMinutes % 60)];
}

- (NSNumber *)cutoffMinutesFromString:(NSString *)string {
    NSString *trimmed = [[string ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] stringByReplacingOccurrencesOfString:@":" withString:@""];
    if (trimmed.length != 4) {
        return nil;
    }

    NSCharacterSet *nonDigits = NSCharacterSet.decimalDigitCharacterSet.invertedSet;
    if ([trimmed rangeOfCharacterFromSet:nonDigits].location != NSNotFound) {
        return nil;
    }

    NSInteger hour = [[trimmed substringToIndex:2] integerValue];
    NSInteger minute = [[trimmed substringFromIndex:2] integerValue];
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        return nil;
    }
    return @(hour * 60 + minute);
}

- (NSArray<NSString *> *)taskIDsForTab:(TDTaskTab)tab now:(NSDate *)now todayCutoffMinutes:(NSInteger)todayCutoffMinutes {
    NSArray<TDTodoTask *> *tasks = [self.todoList tasksForTab:tab now:now calendar:self.calendar todayCutoffMinutes:todayCutoffMinutes];
    NSMutableArray<NSString *> *taskIDs = [NSMutableArray arrayWithCapacity:tasks.count];
    for (TDTodoTask *task in tasks) {
        [taskIDs addObject:task.identifier];
    }
    return taskIDs;
}

- (void)toggleTimerForTaskButton:(NSButton *)sender {
    NSInteger row = sender.tag;
    if (row < 0 || row >= (NSInteger)self.visibleTasks.count) {
        return;
    }

    TDTodoTask *task = self.visibleTasks[(NSUInteger)row];
    [self toggleTimerForTask:task];
    [self.tableView reloadData];
}

- (NSTimeInterval)remainingSecondsForTask:(TDTodoTask *)task {
    if (task.completedAt != nil) {
        return 0;
    }
    NSNumber *pausedSeconds = self.pausedTimerRemainingSeconds[task.identifier];
    if (pausedSeconds != nil) {
        return MAX(0, pausedSeconds.doubleValue);
    }
    NSDate *deadline = self.runningTimerDeadlines[task.identifier];
    if (deadline == nil) {
        return 0;
    }
    return MAX(0, [deadline timeIntervalSinceNow]);
}

- (NSString *)timerStateForTask:(TDTodoTask *)task {
    if (task.completedAt != nil) {
        return nil;
    }
    if (self.runningTimerDeadlines[task.identifier] != nil) {
        return @"running";
    }
    if (self.pausedTimerRemainingSeconds[task.identifier] != nil) {
        return @"paused";
    }
    return nil;
}

- (void)toggleTimerForTask:(TDTodoTask *)task {
    if (task.estimatedMinutes <= 0 || task.completedAt != nil) {
        return;
    }

    NSString *state = [self timerStateForTask:task];
    if ([state isEqualToString:@"running"]) {
        [self pauseTimerForTask:task];
    } else if ([state isEqualToString:@"paused"]) {
        [self resumeTimerForTask:task];
    } else {
        [self startTimerForTask:task];
    }
}

- (void)startTimerForTask:(TDTodoTask *)task {
    NSTimeInterval seconds = MAX(1, task.estimatedMinutes * 60);
    self.runningTimerDeadlines[task.identifier] = [NSDate dateWithTimeIntervalSinceNow:seconds];
    [self.pausedTimerRemainingSeconds removeObjectForKey:task.identifier];
    [self ensureCountdownTimerRunning];
    [self scheduleNotificationForTask:task seconds:seconds];
}

- (void)pauseTimerForTask:(TDTodoTask *)task {
    NSTimeInterval remainingSeconds = [self remainingSecondsForTask:task];
    [self.runningTimerDeadlines removeObjectForKey:task.identifier];
    [self removePendingNotificationForTaskID:task.identifier];
    if (remainingSeconds > 0) {
        self.pausedTimerRemainingSeconds[task.identifier] = @(remainingSeconds);
    }
    [self stopCountdownTimerIfIdle];
}

- (void)resumeTimerForTask:(TDTodoTask *)task {
    NSTimeInterval seconds = [self remainingSecondsForTask:task];
    if (seconds <= 0) {
        seconds = MAX(1, task.estimatedMinutes * 60);
    }
    self.runningTimerDeadlines[task.identifier] = [NSDate dateWithTimeIntervalSinceNow:seconds];
    [self.pausedTimerRemainingSeconds removeObjectForKey:task.identifier];
    [self ensureCountdownTimerRunning];
    [self scheduleNotificationForTask:task seconds:seconds];
}

- (void)cancelTimerForTaskID:(NSString *)taskID {
    [self.runningTimerDeadlines removeObjectForKey:taskID];
    [self.pausedTimerRemainingSeconds removeObjectForKey:taskID];
    [self removePendingNotificationForTaskID:taskID];
    [self stopCountdownTimerIfIdle];
}

- (void)ensureCountdownTimerRunning {
    if (self.countdownTimer != nil) {
        return;
    }
    self.countdownTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                          target:self
                                                        selector:@selector(countdownTick:)
                                                        userInfo:nil
                                                         repeats:YES];
}

- (void)countdownTick:(NSTimer *)timer {
    (void)timer;
    NSDate *now = [NSDate date];
    for (NSString *taskID in self.runningTimerDeadlines.allKeys) {
        if ([self.runningTimerDeadlines[taskID] timeIntervalSinceDate:now] <= 0) {
            [self.runningTimerDeadlines removeObjectForKey:taskID];
        }
    }
    [self.tableView reloadData];
    [self stopCountdownTimerIfIdle];
}

- (void)stopCountdownTimerIfIdle {
    if (self.runningTimerDeadlines.count > 0) {
        return;
    }
    [self.countdownTimer invalidate];
    self.countdownTimer = nil;
}

- (void)configureNotifications {
    UNUserNotificationCenter.currentNotificationCenter.delegate = self;
}

- (void)scheduleNotificationForTask:(TDTodoTask *)task seconds:(NSTimeInterval)seconds {
    NSString *taskTitle = [task.title copy];
    NSString *taskID = [task.identifier copy];
    [self removePendingNotificationForTaskID:taskID];
    NSString *identifier = [NSString stringWithFormat:@"tododesk-%@-%@", taskID, [NSUUID UUID].UUIDString];
    self.timerNotificationIDs[taskID] = identifier;
    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;

    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                          completionHandler:^(BOOL granted, NSError *error) {
        if (![self.timerNotificationIDs[taskID] isEqualToString:identifier]) {
            return;
        }
        if (granted && error == nil) {
            UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
            content.title = @"TodoDesk 計時完成";
            content.body = [NSString stringWithFormat:@"「%@」預計時間已完結。", taskTitle];
            content.sound = UNNotificationSound.defaultSound;

            UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:seconds repeats:NO];
            UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
            [center addNotificationRequest:request withCompletionHandler:^(NSError *requestError) {
                if (requestError != nil) {
                    [self showTimerFallbackAfter:seconds taskID:taskID notificationID:identifier taskTitle:taskTitle];
                }
            }];
        } else {
            [self showTimerFallbackAfter:seconds taskID:taskID notificationID:identifier taskTitle:taskTitle];
        }
    }];
}

- (void)removePendingNotificationForTaskID:(NSString *)taskID {
    NSString *identifier = self.timerNotificationIDs[taskID];
    if (identifier.length > 0) {
        [UNUserNotificationCenter.currentNotificationCenter removePendingNotificationRequestsWithIdentifiers:@[identifier]];
    }
    [self.timerNotificationIDs removeObjectForKey:taskID];
}

- (void)showTimerFallbackAfter:(NSTimeInterval)seconds taskID:(NSString *)taskID notificationID:(NSString *)notificationID taskTitle:(NSString *)taskTitle {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (![self.timerNotificationIDs[taskID] isEqualToString:notificationID]) {
            return;
        }
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"TodoDesk 計時完成";
        alert.informativeText = [NSString stringWithFormat:@"「%@」預計時間已完結。", taskTitle];
        [alert addButtonWithTitle:@"知道"];
        [alert runModal];
    });
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    (void)center;
    (void)notification;
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionList | UNNotificationPresentationOptionSound);
}

- (void)saveTasks {
    NSError *error = nil;
    if (![self.fileStore saveTodoList:self.todoList error:&error]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"儲存失敗";
        alert.informativeText = error.localizedDescription ?: @"未知錯誤";
        [alert runModal];
    }
}

- (void)exportTodoData:(id)sender {
    (void)sender;
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.nameFieldStringValue = @"TodoDesk-backup.json";
    panel.allowedContentTypes = @[[UTType typeWithIdentifier:@"public.json"]];
    NSModalResponse response = [panel runModal];
    if (response != NSModalResponseOK || panel.URL == nil) {
        return;
    }

    NSError *error = nil;
    NSData *data = [self.fileStore dataForTodoList:self.todoList error:&error];
    if (data == nil || ![data writeToURL:panel.URL options:NSDataWritingAtomic error:&error]) {
        [self showErrorWithTitle:@"匯出失敗" error:error];
    }
}

- (void)importTodoData:(id)sender {
    (void)sender;
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.allowedContentTypes = @[[UTType typeWithIdentifier:@"public.json"]];
    NSModalResponse response = [panel runModal];
    if (response != NSModalResponseOK || panel.URL == nil) {
        return;
    }

    NSAlert *confirmAlert = [[NSAlert alloc] init];
    confirmAlert.messageText = @"匯入會取代目前資料";
    confirmAlert.informativeText = @"建議先匯出備份，再繼續匯入。";
    [confirmAlert addButtonWithTitle:@"匯入"];
    [confirmAlert addButtonWithTitle:@"取消"];
    if ([confirmAlert runModal] != NSAlertFirstButtonReturn) {
        return;
    }

    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:panel.URL options:0 error:&error];
    if (data == nil) {
        [self showErrorWithTitle:@"匯入失敗" error:error];
        return;
    }

    TDTodoList *importedList = [self.fileStore todoListFromData:data error:&error];
    if (importedList == nil || error != nil) {
        [self showErrorWithTitle:@"匯入失敗" error:error];
        return;
    }

    self.todoList = importedList;
    [self.runningTimerDeadlines removeAllObjects];
    [self.pausedTimerRemainingSeconds removeAllObjects];
    [self.timerNotificationIDs removeAllObjects];
    [self.collapsedTaskIDs removeAllObjects];
    [self persistCollapsedTaskIDs];
    [self stopCountdownTimerIfIdle];
    [self saveTasks];
    [self configureTabsPreservingSelection:NO];
    [self reloadVisibleTasksAnimated:YES];
}

- (void)showErrorWithTitle:(NSString *)title error:(NSError *)error {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = error.localizedDescription ?: @"未知錯誤";
    [alert addButtonWithTitle:@"知道"];
    [alert runModal];
}

- (void)openDataFolder:(id)sender {
    (void)sender;
    NSURL *directoryURL = [self.fileStore.fileURL URLByDeletingLastPathComponent];
    NSError *error = nil;
    if (![NSFileManager.defaultManager createDirectoryAtURL:directoryURL
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:&error]) {
        [self showErrorWithTitle:@"無法打開資料夾" error:error];
        return;
    }
    if (![NSWorkspace.sharedWorkspace openURL:directoryURL]) {
        [self showErrorWithTitle:@"無法打開資料夾" error:nil];
    }
}

- (void)configureTabsPreservingSelection:(BOOL)preserveSelection {
    NSString *selectedTabID = preserveSelection ? [self currentTabID] : TDTabTodayID;
    self.tabOrder = [self sanitizedTabOrder];
    for (NSView *view in self.tabStackView.arrangedSubviews) {
        [self.tabStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [self.tabButtons removeAllObjects];

    [self.tabOrder enumerateObjectsUsingBlock:^(NSString *tabID, NSUInteger index, BOOL *stop) {
        (void)stop;
        NSButton *button = [self tabButtonWithTitle:[self labelForTabID:tabID] index:(NSInteger)index tabID:tabID];
        [self.tabStackView addArrangedSubview:button];
        [self.tabButtons addObject:button];
    }];

    NSButton *addButton = [self tabButtonWithTitle:@"+" index:[self addSegmentIndex] tabID:nil];
    [self.tabStackView addArrangedSubview:addButton];
    [self.tabButtons addObject:addButton];
    [self constrainRegularTabButtonsEqually];

    NSInteger restoredIndex = [self indexOfTabID:selectedTabID];
    if (restoredIndex < 0) {
        restoredIndex = [self indexOfTabID:TDTabTodayID];
    }
    if (restoredIndex < 0) {
        restoredIndex = 0;
    }
    self.selectedTabIndex = restoredIndex;
    self.previousSelectedTabIndex = restoredIndex;
    [self refreshTabButtonStyles];
}

- (NSButton *)tabButtonWithTitle:(NSString *)title index:(NSInteger)index tabID:(NSString *)tabID {
    BOOL addButton = index == [self addSegmentIndex];
    NSButton *button = [[TDTabButton alloc] init];
    button.title = title;
    button.target = self;
    button.action = @selector(tabButtonPressed:);
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = index;
    button.bezelStyle = NSBezelStyleRegularSquare;
    button.bordered = NO;
    button.focusRingType = NSFocusRingTypeNone;
    button.lineBreakMode = NSLineBreakByTruncatingTail;
    button.wantsLayer = YES;
    button.layer.cornerRadius = 15;
    button.layer.masksToBounds = YES;
    if (!addButton) {
        NSPanGestureRecognizer *panGesture = [[NSPanGestureRecognizer alloc] initWithTarget:self action:@selector(tabPanChanged:)];
        panGesture.delaysPrimaryMouseButtonEvents = NO;
        [button addGestureRecognizer:panGesture];
    }
    NSString *customListID = [self customListIDForTabID:tabID];
    if (customListID.length > 0) {
        button.menu = [self menuForCustomTabWithListID:customListID];
    }
    [button.heightAnchor constraintEqualToConstant:addButton ? 30 : 34].active = YES;
    if (addButton) {
        [button.widthAnchor constraintEqualToConstant:46].active = YES;
        [button setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
        [button setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    } else {
        [button setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        [button setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    }
    return button;
}

- (NSMenu *)menuForCustomTabWithListID:(NSString *)listID {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"清單"];
    NSMenuItem *renameItem = [[NSMenuItem alloc] initWithTitle:@"重新命名清單" action:@selector(renameCustomTabFromMenu:) keyEquivalent:@""];
    renameItem.target = self;
    renameItem.representedObject = listID;
    [menu addItem:renameItem];

    NSMenuItem *deleteItem = [[NSMenuItem alloc] initWithTitle:@"刪除清單" action:@selector(deleteCustomTabFromMenu:) keyEquivalent:@""];
    deleteItem.target = self;
    deleteItem.representedObject = listID;
    [menu addItem:deleteItem];
    return menu;
}

- (void)renameCustomTabFromMenu:(NSMenuItem *)sender {
    NSString *listID = [sender.representedObject isKindOfClass:NSString.class] ? sender.representedObject : nil;
    if (listID.length == 0) {
        return;
    }
    TDCustomList *list = [self customListForID:listID];
    if (list == nil) {
        return;
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"重新命名清單";
    alert.informativeText = @"輸入新的清單名稱。";
    [alert addButtonWithTitle:@"儲存"];
    [alert addButtonWithTitle:@"取消"];

    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 260, 28)];
    textField.stringValue = list.name;
    alert.accessoryView = textField;

    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }
    if ([self.todoList renameCustomListWithID:listID name:textField.stringValue]) {
        [self saveTasks];
        [self configureTabsPreservingSelection:YES];
        [self reloadVisibleTasksAnimated:NO];
    }
}

- (void)deleteCustomTabFromMenu:(NSMenuItem *)sender {
    NSString *listID = [sender.representedObject isKindOfClass:NSString.class] ? sender.representedObject : nil;
    if (listID.length == 0) {
        return;
    }
    TDCustomList *list = [self customListForID:listID];
    if (list == nil) {
        return;
    }

    NSUInteger taskCount = [self taskCountForCustomListID:listID];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"刪除清單？";
    alert.informativeText = [NSString stringWithFormat:@"「%@」同入面 %lu 個事項會一併刪除。", list.name, (unsigned long)taskCount];
    [alert addButtonWithTitle:@"刪除"];
    [alert addButtonWithTitle:@"取消"];
    alert.alertStyle = NSAlertStyleWarning;
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }

    for (TDTodoTask *task in [self.todoList.tasks copy]) {
        if ([task.listID isEqualToString:listID]) {
            [self cancelTimerForTaskID:task.identifier];
            [self.collapsedTaskIDs removeObject:task.identifier];
        }
    }
    if ([self.todoList deleteCustomListWithID:listID]) {
        [self persistCollapsedTaskIDs];
        [self saveTasks];
        [self configureTabsPreservingSelection:YES];
        [self persistTabOrder];
        [self reloadVisibleTasksAnimated:YES];
    }
}

- (NSMutableArray<NSString *> *)sanitizedTabOrder {
    NSMutableSet<NSString *> *validIDs = [NSMutableSet setWithArray:[self defaultTabIDs]];
    for (TDCustomList *list in self.todoList.customLists) {
        [validIDs addObject:[self customTabIDForListID:list.identifier]];
    }

    NSMutableArray<NSString *> *order = [NSMutableArray array];
    NSArray *savedOrder = [NSUserDefaults.standardUserDefaults arrayForKey:TDTabOrderDefaultsKey];
    for (id item in savedOrder) {
        if (![item isKindOfClass:NSString.class] || ![validIDs containsObject:item] || [order containsObject:item]) {
            continue;
        }
        [order addObject:item];
    }

    for (NSString *tabID in [self defaultTabIDs]) {
        if (![order containsObject:tabID]) {
            if ([tabID isEqualToString:TDTabTomorrowID] && [order containsObject:TDTabTodayID]) {
                NSUInteger todayIndex = [order indexOfObject:TDTabTodayID];
                [order insertObject:tabID atIndex:MIN(todayIndex + 1, order.count)];
            } else {
                [order addObject:tabID];
            }
        }
    }
    for (TDCustomList *list in self.todoList.customLists) {
        NSString *tabID = [self customTabIDForListID:list.identifier];
        if (![order containsObject:tabID]) {
            [order addObject:tabID];
        }
    }
    return order;
}

- (NSArray<NSString *> *)defaultTabIDs {
    return @[TDTabPastCompletedID, TDTabPastIncompleteID, TDTabTodayID, TDTabTomorrowID];
}

- (NSString *)labelForTabID:(NSString *)tabID {
    if ([tabID isEqualToString:TDTabPastCompletedID]) {
        return @"過往完成";
    }
    if ([tabID isEqualToString:TDTabPastIncompleteID]) {
        return @"過往未完成";
    }
    if ([tabID isEqualToString:TDTabTodayID]) {
        return @"今日";
    }
    if ([tabID isEqualToString:TDTabTomorrowID]) {
        return @"明天";
    }

    NSString *listID = [self customListIDForTabID:tabID];
    for (TDCustomList *list in self.todoList.customLists) {
        if ([list.identifier isEqualToString:listID]) {
            return list.name;
        }
    }
    return @"自訂";
}

- (NSString *)currentTabID {
    if (self.selectedTabIndex >= 0 && self.selectedTabIndex < (NSInteger)self.tabOrder.count) {
        return self.tabOrder[(NSUInteger)self.selectedTabIndex];
    }
    return TDTabTodayID;
}

- (NSString *)customTabIDForListID:(NSString *)listID {
    return [TDTabCustomPrefix stringByAppendingString:listID ?: @""];
}

- (NSString *)customListIDForTabID:(NSString *)tabID {
    if (![tabID hasPrefix:TDTabCustomPrefix]) {
        return nil;
    }
    return [tabID substringFromIndex:TDTabCustomPrefix.length];
}

- (NSInteger)indexOfTabID:(NSString *)tabID {
    NSUInteger index = [self.tabOrder indexOfObject:tabID];
    return index == NSNotFound ? -1 : (NSInteger)index;
}

- (void)constrainRegularTabButtonsEqually {
    NSInteger addIndex = [self addSegmentIndex];
    if (addIndex <= 1 || self.tabButtons.count == 0) {
        return;
    }

    NSButton *firstButton = self.tabButtons.firstObject;
    for (NSInteger index = 1; index < addIndex; index += 1) {
        [self.tabButtons[(NSUInteger)index].widthAnchor constraintEqualToAnchor:firstButton.widthAnchor].active = YES;
    }
}

- (void)refreshTabButtonStyles {
    [self.tabButtons enumerateObjectsUsingBlock:^(NSButton *button, NSUInteger index, BOOL *stop) {
        (void)stop;
        BOOL selected = (NSInteger)index == self.selectedTabIndex;
        BOOL addButton = (NSInteger)index == [self addSegmentIndex];
        button.layer.backgroundColor = selected ? TDMinimalColor(12, 12, 12, 1).CGColor : NSColor.clearColor.CGColor;
        button.layer.borderWidth = addButton && !selected ? 1 : 0;
        button.layer.borderColor = TDMinimalColor(28, 28, 28, 0.58).CGColor;

        NSColor *textColor = selected ? TDMinimalColor(252, 252, 250, 1) : (addButton ? TDMinimalColor(18, 18, 18, 1) : TDMinimalColor(112, 112, 108, 1));
        NSFont *font = selected || addButton
            ? [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold]
            : [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
        NSDictionary<NSAttributedStringKey, id> *attributes = @{
            NSForegroundColorAttributeName: textColor,
            NSFontAttributeName: font
        };
        button.attributedTitle = [[NSAttributedString alloc] initWithString:button.title attributes:attributes];
    }];
}

- (void)tabPanChanged:(NSPanGestureRecognizer *)gesture {
    NSButton *button = (NSButton *)gesture.view;
    if (![button isKindOfClass:NSButton.class] || button.tag == [self addSegmentIndex]) {
        return;
    }

    if (gesture.state == NSGestureRecognizerStateBegan) {
        self.draggedTabIndex = button.tag;
        self.pendingTabDropIndex = button.tag;
        self.draggedTabButton = button;
        self.preDragTabOrder = [self.tabOrder copy];
        self.tabOrderChangedDuringDrag = NO;
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.10;
            button.animator.alphaValue = 0.38;
        } completionHandler:nil];
    } else if (gesture.state == NSGestureRecognizerStateChanged) {
        NSPoint point = [gesture locationInView:self.tabBarView];
        self.pendingTabDropIndex = [self tabInsertionIndexForPoint:point];
        self.tabDropIndicator.hidden = YES;
        [self liveReflowDraggedTabToInsertionIndex:self.pendingTabDropIndex];
    } else if (gesture.state == NSGestureRecognizerStateEnded) {
        [self finishTabDragApplyingReorder:YES];
    } else if (gesture.state == NSGestureRecognizerStateCancelled || gesture.state == NSGestureRecognizerStateFailed) {
        [self finishTabDragApplyingReorder:NO];
    }
}

- (NSInteger)tabInsertionIndexForPoint:(NSPoint)point {
    NSInteger tabCount = (NSInteger)self.tabOrder.count;
    for (NSInteger index = 0; index < tabCount; index += 1) {
        NSButton *button = self.tabButtons[(NSUInteger)index];
        NSRect frame = [self.tabBarView convertRect:button.bounds fromView:button];
        if (point.x < NSMidX(frame)) {
            return index;
        }
    }
    return tabCount;
}

- (void)showTabDropIndicatorAtIndex:(NSInteger)index {
    NSInteger tabCount = (NSInteger)self.tabOrder.count;
    if (tabCount == 0) {
        self.tabDropIndicator.hidden = YES;
        return;
    }

    NSInteger clampedIndex = MAX(0, MIN(index, tabCount));
    NSButton *referenceButton = self.tabButtons[(NSUInteger)MIN(clampedIndex, tabCount - 1)];
    NSRect referenceFrame = [self.tabBarView convertRect:referenceButton.bounds fromView:referenceButton];
    CGFloat x = clampedIndex >= tabCount ? NSMaxX(referenceFrame) + 5 : NSMinX(referenceFrame) - 5;
    self.tabDropIndicator.frame = NSMakeRect(x - 1.5, 2, 3, 30);
    self.tabDropIndicator.hidden = NO;
}

- (void)liveReflowDraggedTabToInsertionIndex:(NSInteger)insertionIndex {
    if (self.draggedTabIndex < 0 || self.draggedTabIndex >= (NSInteger)self.tabOrder.count) {
        return;
    }

    NSInteger clampedInsertionIndex = MAX(0, MIN(insertionIndex, (NSInteger)self.tabOrder.count));
    NSInteger destinationIndex = clampedInsertionIndex > self.draggedTabIndex ? clampedInsertionIndex - 1 : clampedInsertionIndex;
    destinationIndex = MAX(0, MIN(destinationIndex, (NSInteger)self.tabOrder.count - 1));
    if (destinationIndex == self.draggedTabIndex) {
        return;
    }

    NSString *selectedTabID = [self currentTabID];
    NSString *movingTabID = self.tabOrder[(NSUInteger)self.draggedTabIndex];
    NSButton *movingButton = self.tabButtons[(NSUInteger)self.draggedTabIndex];

    [self.tabOrder removeObjectAtIndex:(NSUInteger)self.draggedTabIndex];
    [self.tabOrder insertObject:movingTabID atIndex:(NSUInteger)destinationIndex];
    [self.tabButtons removeObjectAtIndex:(NSUInteger)self.draggedTabIndex];
    [self.tabButtons insertObject:movingButton atIndex:(NSUInteger)destinationIndex];

    [self.tabStackView removeArrangedSubview:movingButton];
    [self.tabStackView insertArrangedSubview:movingButton atIndex:(NSUInteger)destinationIndex];
    self.draggedTabIndex = destinationIndex;
    self.selectedTabIndex = [self indexOfTabID:selectedTabID];
    self.previousSelectedTabIndex = self.selectedTabIndex;
    self.tabOrderChangedDuringDrag = YES;
    [self updateTabButtonTags];
    [self refreshTabButtonStyles];
    movingButton.alphaValue = 0.38;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.14;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.tabStackView.animator layoutSubtreeIfNeeded];
    } completionHandler:nil];
}

- (void)updateTabButtonTags {
    [self.tabButtons enumerateObjectsUsingBlock:^(NSButton *button, NSUInteger index, BOOL *stop) {
        (void)stop;
        button.tag = (NSInteger)index;
    }];
}

- (void)finishTabDragApplyingReorder:(BOOL)applyReorder {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.10;
        self.draggedTabButton.animator.alphaValue = 1.0;
    } completionHandler:nil];
    self.tabDropIndicator.hidden = YES;

    if (applyReorder && self.tabOrderChangedDuringDrag) {
        [self persistTabOrder];
        [self applyCustomListSortOrderFromTabOrder];
        [self saveTasks];
        [self refreshTabButtonStyles];
    } else if (!applyReorder && self.tabOrderChangedDuringDrag) {
        NSString *selectedTabID = [self currentTabID];
        self.tabOrder = [self.preDragTabOrder mutableCopy];
        self.selectedTabIndex = [self indexOfTabID:selectedTabID];
        if (self.selectedTabIndex < 0) {
            self.selectedTabIndex = [self indexOfTabID:TDTabTodayID];
        }
        self.previousSelectedTabIndex = self.selectedTabIndex;
        [self configureTabsPreservingSelection:YES];
    }

    self.draggedTabIndex = -1;
    self.pendingTabDropIndex = -1;
    self.draggedTabButton = nil;
    self.preDragTabOrder = nil;
    self.tabOrderChangedDuringDrag = NO;
}

- (void)persistTabOrder {
    [NSUserDefaults.standardUserDefaults setObject:self.tabOrder forKey:TDTabOrderDefaultsKey];
}

- (void)applyCustomListSortOrderFromTabOrder {
    NSInteger sortOrder = 0;
    for (NSString *tabID in self.tabOrder) {
        NSString *listID = [self customListIDForTabID:tabID];
        if (listID == nil) {
            continue;
        }
        for (TDCustomList *list in self.todoList.customLists) {
            if ([list.identifier isEqualToString:listID]) {
                list.sortOrder = sortOrder;
                sortOrder += 1;
                break;
            }
        }
    }
    [self.todoList.customLists sortUsingComparator:^NSComparisonResult(TDCustomList *left, TDCustomList *right) {
        if (left.sortOrder < right.sortOrder) {
            return NSOrderedAscending;
        }
        if (left.sortOrder > right.sortOrder) {
            return NSOrderedDescending;
        }
        return [left.createdAt compare:right.createdAt];
    }];
}

- (void)promptForNewCustomList {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"新增清單";
    alert.informativeText = @"輸入一個你想管理的清單名稱。";
    [alert addButtonWithTitle:@"新增"];
    [alert addButtonWithTitle:@"取消"];

    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 260, 28)];
    textField.placeholderString = @"例如：工作、學習、購物";
    alert.accessoryView = textField;

    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSString *name = [textField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length > 0) {
            TDCustomList *list = [self.todoList addCustomListNamed:name now:[NSDate date]];
            [self saveTasks];
            [self configureTabsPreservingSelection:NO];
            NSInteger index = [self indexOfTabID:[self customTabIDForListID:list.identifier]];
            self.selectedTabIndex = index >= 0 ? index : [self indexOfTabID:TDTabTodayID];
            self.previousSelectedTabIndex = self.selectedTabIndex;
            [self refreshTabButtonStyles];
            [self reloadVisibleTasksAnimated:YES];
            return;
        }
    }

    self.selectedTabIndex = self.previousSelectedTabIndex;
    [self refreshTabButtonStyles];
}

- (TDTaskTab)currentTab {
    NSString *tabID = [self currentTabID];
    if ([tabID isEqualToString:TDTabPastCompletedID]) {
        return TDTaskTabPastCompleted;
    }
    if ([tabID isEqualToString:TDTabPastIncompleteID]) {
        return TDTaskTabPastIncomplete;
    }
    if ([tabID isEqualToString:TDTabTomorrowID]) {
        return TDTaskTabTomorrow;
    }
    return TDTaskTabToday;
}

- (BOOL)canAddInCurrentTab {
    TDTaskTab tab = [self currentTab];
    return tab == TDTaskTabToday || tab == TDTaskTabTomorrow || [self currentCustomListID] != nil;
}

- (BOOL)canReorderCurrentTab {
    return [self canAddInCurrentTab];
}

- (NSInteger)addSegmentIndex {
    return (NSInteger)self.tabOrder.count;
}

- (TDCustomList *)currentCustomList {
    NSString *listID = [self customListIDForTabID:[self currentTabID]];
    if (listID.length == 0) {
        return nil;
    }
    return [self customListForID:listID];
}

- (TDCustomList *)customListForID:(NSString *)listID {
    if (listID.length == 0) {
        return nil;
    }
    for (TDCustomList *list in self.todoList.customLists) {
        if ([list.identifier isEqualToString:listID]) {
            return list;
        }
    }
    return nil;
}

- (NSString *)currentCustomListID {
    return [self currentCustomList].identifier;
}

- (NSUInteger)taskCountForCustomListID:(NSString *)listID {
    __block NSUInteger count = 0;
    [self.todoList.tasks enumerateObjectsUsingBlock:^(TDTodoTask *task, NSUInteger index, BOOL *stop) {
        (void)index;
        (void)stop;
        if ([task.listID isEqualToString:listID]) {
            count += 1;
        }
    }];
    return count;
}

- (NSInteger)indexOfCustomListID:(NSString *)listID {
    __block NSInteger foundIndex = -1;
    [self.todoList.customLists enumerateObjectsUsingBlock:^(TDCustomList *list, NSUInteger index, BOOL *stop) {
        if ([list.identifier isEqualToString:listID]) {
            foundIndex = (NSInteger)index;
            *stop = YES;
        }
    }];
    return foundIndex;
}

@end
