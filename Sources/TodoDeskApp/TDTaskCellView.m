#import "TDTaskCellView.h"
#import "TDTimeFormatting.h"

static NSColor *TDMinimalColor(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha) {
    return [NSColor colorWithCalibratedRed:red / 255.0 green:green / 255.0 blue:blue / 255.0 alpha:alpha];
}

@interface TDTaskCellView ()

@property (nonatomic, strong) NSView *cardView;
@property (nonatomic, strong) NSView *accentView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *descriptionLabel;
@property (nonatomic, strong) NSTextField *detailLabel;
@property (nonatomic, strong, readwrite) NSButton *timerButton;
@property (nonatomic, strong, readwrite) NSButton *disclosureButton;
@property (nonatomic, strong, readwrite) NSButton *descriptionButton;
@property (nonatomic, strong) NSLayoutConstraint *cardLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *disclosureWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *descriptionTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *descriptionHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *detailTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *detailHeightConstraint;

@end

@implementation TDTaskCellView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self buildViews];
    }
    return self;
}

- (void)buildViews {
    self.cardView = [[NSView alloc] init];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.wantsLayer = YES;
    self.cardView.layer.cornerRadius = 8;
    self.cardView.layer.borderWidth = 1;
    [self addSubview:self.cardView];

    self.accentView = [[NSView alloc] init];
    self.accentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.accentView.wantsLayer = YES;
    self.accentView.layer.cornerRadius = 2;
    [self.cardView addSubview:self.accentView];

    self.disclosureButton = [[NSButton alloc] init];
    self.disclosureButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.disclosureButton.bezelStyle = NSBezelStyleRegularSquare;
    self.disclosureButton.bordered = NO;
    self.disclosureButton.imagePosition = NSImageOnly;
    self.disclosureButton.contentTintColor = TDMinimalColor(68, 68, 64, 1);
    [self.cardView addSubview:self.disclosureButton];

    self.titleLabel = [NSTextField labelWithString:@""];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [NSFont systemFontOfSize:15 weight:NSFontWeightMedium];
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.maximumNumberOfLines = 1;
    [self.titleLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self.cardView addSubview:self.titleLabel];

    self.descriptionButton = [[NSButton alloc] init];
    self.descriptionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionButton.bezelStyle = NSBezelStyleRegularSquare;
    self.descriptionButton.bordered = NO;
    self.descriptionButton.image = [NSImage imageWithSystemSymbolName:@"pencil" accessibilityDescription:@"edit task details"];
    self.descriptionButton.imagePosition = NSImageOnly;
    self.descriptionButton.contentTintColor = TDMinimalColor(142, 142, 136, 1);
    [self.descriptionButton setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self.descriptionButton setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self.cardView addSubview:self.descriptionButton];

    self.descriptionLabel = [NSTextField labelWithString:@""];
    self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    self.descriptionLabel.textColor = TDMinimalColor(142, 142, 136, 1);
    self.descriptionLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.descriptionLabel.maximumNumberOfLines = 2;
    [self.cardView addSubview:self.descriptionLabel];

    self.detailLabel = [NSTextField labelWithString:@""];
    self.detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightRegular];
    self.detailLabel.textColor = TDMinimalColor(124, 124, 120, 1);
    [self.cardView addSubview:self.detailLabel];

    self.timerButton = [[NSButton alloc] init];
    self.timerButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.timerButton.bezelStyle = NSBezelStyleRegularSquare;
    self.timerButton.bordered = NO;
    self.timerButton.image = [NSImage imageWithSystemSymbolName:@"play.circle.fill" accessibilityDescription:@"start timer"];
    self.timerButton.imagePosition = NSImageOnly;
    self.timerButton.contentTintColor = TDMinimalColor(20, 20, 20, 1);
    [self.cardView addSubview:self.timerButton];

    [NSLayoutConstraint activateConstraints:@[
        self.cardLeadingConstraint = [self.cardView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
        [self.cardView.topAnchor constraintEqualToAnchor:self.topAnchor constant:5],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-5],

        [self.disclosureButton.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:8],
        [self.disclosureButton.centerYAnchor constraintEqualToAnchor:self.cardView.centerYAnchor],
        self.disclosureWidthConstraint = [self.disclosureButton.widthAnchor constraintEqualToConstant:0],
        [self.disclosureButton.heightAnchor constraintEqualToConstant:22],

        [self.accentView.leadingAnchor constraintEqualToAnchor:self.disclosureButton.trailingAnchor constant:4],
        [self.accentView.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:12],
        [self.accentView.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-12],
        [self.accentView.widthAnchor constraintEqualToConstant:4],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.accentView.trailingAnchor constant:12],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.descriptionButton.leadingAnchor constant:-6],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:12],

        [self.descriptionButton.leadingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor constant:6],
        [self.descriptionButton.trailingAnchor constraintLessThanOrEqualToAnchor:self.timerButton.leadingAnchor constant:-12],
        [self.descriptionButton.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [self.descriptionButton.widthAnchor constraintEqualToConstant:18],
        [self.descriptionButton.heightAnchor constraintEqualToConstant:18],

        [self.descriptionLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.descriptionLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.timerButton.leadingAnchor constant:-12],
        self.descriptionTopConstraint = [self.descriptionLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],

        [self.detailLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.detailLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.timerButton.leadingAnchor constant:-12],
        self.detailTopConstraint = [self.detailLabel.topAnchor constraintEqualToAnchor:self.descriptionLabel.bottomAnchor constant:3],
        [self.detailLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.cardView.bottomAnchor constant:-10],

        [self.timerButton.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-12],
        [self.timerButton.centerYAnchor constraintEqualToAnchor:self.cardView.centerYAnchor],
        [self.timerButton.widthAnchor constraintEqualToConstant:28],
        [self.timerButton.heightAnchor constraintEqualToConstant:28]
    ]];
    self.descriptionHeightConstraint = [self.descriptionLabel.heightAnchor constraintEqualToConstant:0];
    self.detailHeightConstraint = [self.detailLabel.heightAnchor constraintEqualToConstant:0];
}

- (void)configureWithTask:(TDTodoTask *)task {
    [self configureWithTask:task remainingSeconds:0 timerState:nil hasChildren:NO collapsed:NO];
}

- (void)configureWithTask:(TDTodoTask *)task
         remainingSeconds:(NSTimeInterval)remainingSeconds
               timerState:(NSString *)timerState
              hasChildren:(BOOL)hasChildren
                collapsed:(BOOL)collapsed {
    BOOL completed = task.completedAt != nil;
    BOOL timerRunning = [timerState isEqualToString:@"running"];
    BOOL timerPaused = [timerState isEqualToString:@"paused"];
    BOOL isSubtask = task.parentTaskID.length > 0;
    NSColor *ink = TDMinimalColor(18, 18, 18, 1);
    NSColor *muted = TDMinimalColor(128, 128, 124, 1);
    self.cardView.layer.backgroundColor = TDMinimalColor(250, 249, 246, 1).CGColor;
    self.cardView.layer.borderColor = TDMinimalColor(28, 28, 28, 0.58).CGColor;
    self.accentView.layer.backgroundColor = (completed ? muted : ink).CGColor;
    self.timerButton.hidden = completed || task.estimatedMinutes <= 0;
    self.timerButton.enabled = !self.timerButton.hidden;
    self.timerButton.contentTintColor = timerRunning ? muted : ink;
    self.timerButton.image = [NSImage imageWithSystemSymbolName:(timerRunning ? @"pause.circle.fill" : @"play.circle.fill")
                                       accessibilityDescription:(timerRunning ? @"pause timer" : @"start timer")];
    self.disclosureButton.hidden = isSubtask || !hasChildren;
    self.disclosureButton.enabled = !self.disclosureButton.hidden;
    self.disclosureWidthConstraint.constant = self.disclosureButton.hidden ? 0 : 18;
    self.disclosureButton.image = [NSImage imageWithSystemSymbolName:(collapsed ? @"chevron.right" : @"chevron.down")
                                            accessibilityDescription:(collapsed ? @"expand subtasks" : @"collapse subtasks")];
    self.cardLeadingConstraint.constant = isSubtask ? 46 : 10;

    self.titleLabel.attributedStringValue = [self titleTextForTask:task
                                                   remainingSeconds:remainingSeconds
                                                         timerState:timerState
                                                          completed:completed
                                                                ink:ink
                                                              muted:muted];
    BOOL hasDescription = task.taskDescription.length > 0;
    self.descriptionLabel.stringValue = @"";
    self.descriptionLabel.hidden = YES;
    self.descriptionHeightConstraint.active = YES;
    self.descriptionTopConstraint.constant = 0;
    self.descriptionButton.contentTintColor = task.taskDescription.length > 0 ? muted : TDMinimalColor(142, 142, 136, 1);
    self.detailLabel.textColor = (timerRunning || timerPaused) ? ink : TDMinimalColor(154, 154, 148, 1);
    self.detailLabel.stringValue = [self detailTextForTask:task remainingSeconds:remainingSeconds timerState:timerState];
    BOOL hasDetail = self.detailLabel.stringValue.length > 0;
    self.detailLabel.hidden = !hasDetail;
    self.detailHeightConstraint.active = !hasDetail;
    self.detailTopConstraint.constant = hasDetail ? (hasDescription ? 3 : 4) : 0;
}

- (NSAttributedString *)titleTextForTask:(TDTodoTask *)task
                        remainingSeconds:(NSTimeInterval)remainingSeconds
                               timerState:(NSString *)timerState
                                completed:(BOOL)completed
                                      ink:(NSColor *)ink
                                    muted:(NSColor *)muted {
    NSDictionary<NSAttributedStringKey, id> *titleAttributes = completed
        ? @{
            NSForegroundColorAttributeName: muted,
            NSFontAttributeName: self.titleLabel.font,
            NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle)
        }
        : @{
            NSForegroundColorAttributeName: ink,
            NSFontAttributeName: self.titleLabel.font
        };
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:task.title attributes:titleAttributes];

    NSString *suffix = nil;
    if ([timerState isEqualToString:@"running"]) {
        suffix = TDRemainingTimeTextForSeconds(remainingSeconds);
    } else if ([timerState isEqualToString:@"paused"]) {
        suffix = [NSString stringWithFormat:@"暫停 %@", TDRemainingTimeTextForSeconds(remainingSeconds)];
    } else if (task.estimatedMinutes > 0) {
        suffix = [self compactEstimateTextForMinutes:task.estimatedMinutes];
    }

    if (suffix.length > 0) {
        NSDictionary<NSAttributedStringKey, id> *suffixAttributes = @{
            NSForegroundColorAttributeName: muted,
            NSFontAttributeName: [NSFont systemFontOfSize:12 weight:NSFontWeightMedium]
        };
        [text appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"  %@", suffix]
                                                                     attributes:suffixAttributes]];
    }
    NSString *completionText = [self completionTextForTask:task];
    if (completionText.length > 0) {
        NSDictionary<NSAttributedStringKey, id> *completionAttributes = @{
            NSForegroundColorAttributeName: muted,
            NSFontAttributeName: [NSFont systemFontOfSize:12 weight:NSFontWeightMedium]
        };
        [text appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"  %@", completionText]
                                                                     attributes:completionAttributes]];
    }
    if (task.taskDescription.length > 0) {
        NSDictionary<NSAttributedStringKey, id> *descriptionAttributes = @{
            NSForegroundColorAttributeName: TDMinimalColor(154, 154, 148, 1),
            NSFontAttributeName: [NSFont systemFontOfSize:12 weight:NSFontWeightRegular]
        };
        [text appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"  %@", task.taskDescription]
                                                                     attributes:descriptionAttributes]];
    }
    return text;
}

- (NSString *)detailTextForTask:(TDTodoTask *)task remainingSeconds:(NSTimeInterval)remainingSeconds timerState:(NSString *)timerState {
    (void)remainingSeconds;
    (void)timerState;
    (void)task;
    return @"";
}

- (NSString *)completionTextForTask:(TDTodoTask *)task {
    if (task.completedAt != nil) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.locale = NSLocale.currentLocale;
        formatter.timeZone = NSTimeZone.localTimeZone;
        formatter.dateStyle = NSDateFormatterShortStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        return [NSString stringWithFormat:@"完成於 %@", [formatter stringFromDate:task.completedAt]];
    }

    return @"";
}

- (NSString *)compactEstimateTextForMinutes:(NSInteger)minutes {
    NSInteger hours = minutes / 60;
    NSInteger remainingMinutes = minutes % 60;
    if (hours > 0 && remainingMinutes > 0) {
        return [NSString stringWithFormat:@"%ld hr %ld min", (long)hours, (long)remainingMinutes];
    }
    if (hours > 0) {
        return [NSString stringWithFormat:@"%ld hr", (long)hours];
    }
    return [NSString stringWithFormat:@"%ld min", (long)remainingMinutes];
}

@end
