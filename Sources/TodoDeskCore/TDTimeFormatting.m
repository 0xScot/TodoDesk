#import "TDTimeFormatting.h"
#import <math.h>

NSString *TDRemainingTimeTextForSeconds(NSTimeInterval seconds) {
    NSInteger remaining = MAX(0, (NSInteger)ceil(seconds));
    NSInteger hours = remaining / 3600;
    NSInteger minutes = (remaining % 3600) / 60;
    NSInteger secondsPart = remaining % 60;

    if (hours > 0) {
        return [NSString stringWithFormat:@"剩餘 %ld:%02ld:%02ld", (long)hours, (long)minutes, (long)secondsPart];
    }
    return [NSString stringWithFormat:@"剩餘 %ld:%02ld", (long)minutes, (long)secondsPart];
}
