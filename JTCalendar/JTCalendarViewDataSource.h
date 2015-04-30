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

- (BOOL)calendarHaveEvent:(JTCalendar *)calendar date:(NSDate *)date;
- (BOOL)calendar:(JTCalendar *)calendar canSelectDate:(NSDate *)date;

- (void)calendarDidLoadPreviousPage;
- (void)calendarDidLoadNextPage;

@end
