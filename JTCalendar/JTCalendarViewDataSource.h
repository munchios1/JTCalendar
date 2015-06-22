//
//  JTCalendarDataSource.h
//  JTCalendar
//
//  Created by Jonathan Tribouharet
//

#import <Foundation/Foundation.h>

@class JTCalendar;

@protocol JTCalendarDataSource <NSObject>
- (void)calendarDidDateSelected:(JTCalendar *)calendar date:(NSDate *)date;
@optional
- (void)calendarDidDateSelected:(JTCalendar *)calendar dateString:(NSString *)dateString;
- (BOOL)calendarHaveEvent:(JTCalendar *)calendar date:(NSDate *)date;
- (BOOL)calendar:(JTCalendar *)calendar canSelectDate:(NSDate *)date;

- (void)calendarDidLoadPreviousPage;
- (void)calendarDidLoadNextPage;

- (NSDate *)calendarStartDateLimit;
- (NSDate *)calendarEndDateLimit;
@end
