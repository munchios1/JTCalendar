//
//  JTCalendar.m
//  JTCalendar
//
//  Created by Jonathan Tribouharet
//

#import "JTCalendar.h"

#define NUMBER_PAGES_LOADED 5 // Must be the same in JTCalendarView, JTCalendarMenuView, JTCalendarContentView

@interface JTCalendar(){
    BOOL cacheLastWeekMode;
    NSUInteger cacheFirstWeekDay;
}
@property (nonatomic, assign)CGFloat lastContentOffset;
@property (nonatomic, assign)BOOL preventLoadPrevious;
@property (nonatomic, assign)BOOL preventLoadNext;
@property (nonatomic, assign)BOOL isLoaded;

@end

@implementation JTCalendar

- (instancetype)init
{
    self = [super init];
    if(!self){
        return nil;
    }
    
    self->_currentDate = [NSDate date];
    self->_todayDate = [NSDate date];
    self->_calendarAppearance = [JTCalendarAppearance new];
    self->_dataCache = [JTCalendarDataCache new];
    self.dataCache.calendarManager = self;
    
    self.contentView.bounces = false;
    
    return self;
}

// Bug in iOS
- (void)dealloc
{
    [self->_menuMonthsView setDelegate:nil];
    [self->_contentView setDelegate:nil];
}

- (void)setMenuMonthsView:(JTCalendarMenuView *)menuMonthsView
{
    [self->_menuMonthsView setDelegate:nil];
    [self->_menuMonthsView setCalendarManager:nil];
    
    self->_menuMonthsView = menuMonthsView;
    [self->_menuMonthsView setDelegate:self];
    [self->_menuMonthsView setCalendarManager:self];
    
    cacheLastWeekMode = self.calendarAppearance.isWeekMode;
    cacheFirstWeekDay = self.calendarAppearance.calendar.firstWeekday;
    
    [self.menuMonthsView setCurrentDate:self.currentDate];
    [self.menuMonthsView reloadAppearance];
}

- (void)setContentView:(JTCalendarContentView *)contentView
{
    [self->_contentView setDelegate:nil];
    [self->_contentView setCalendarManager:nil];
    
    self->_contentView = contentView;
    [self->_contentView setDelegate:self];
    [self->_contentView setCalendarManager:self];
    
    [self.contentView setCurrentDate:self.currentDate];
    [self.contentView reloadAppearance];
}

- (void)reloadData
{
    // Erase cache
    [self.dataCache reloadData];
    
    [self repositionViews];
    [self.contentView reloadData];
}

- (void)reloadAppearance
{
    [self.menuMonthsView reloadAppearance];
    [self.contentView reloadAppearance];
    
    if(cacheLastWeekMode != self.calendarAppearance.isWeekMode || cacheFirstWeekDay != self.calendarAppearance.calendar.firstWeekday){
        cacheLastWeekMode = self.calendarAppearance.isWeekMode;
        cacheFirstWeekDay = self.calendarAppearance.calendar.firstWeekday;
        
        if(self.calendarAppearance.focusSelectedDayChangeMode && self.currentDateSelected){
            [self setCurrentDate:self.currentDateSelected];
        }
        else{
            [self setCurrentDate:self.currentDate];
        }
    }
}

- (void)setCurrentDate:(NSDate *)currentDate
{
    NSAssert(currentDate, @"JTCalendar currentDate cannot be null");

    self->_currentDate = currentDate;
    
    [self.menuMonthsView setCurrentDate:currentDate];
    [self.contentView setCurrentDate:currentDate];
    
    [self repositionViews];
    [self.contentView reloadData];
}

#pragma mark - UIScrollView delegate

- (void)scrollViewDidScroll:(UIScrollView *)sender
{
    if(self.calendarAppearance.isWeekMode){
        
        float delta = self.lastContentOffset - sender.contentOffset.x;
        
        if (delta > 0.0){
            if (_preventLoadPrevious) {
                [sender setContentOffset:CGPointMake(self.lastContentOffset, sender.contentOffset.y) animated:NO];
            }
        }
        else if (delta < 0.0){
            if (_preventLoadNext) {
                [sender setContentOffset:CGPointMake(self.lastContentOffset, sender.contentOffset.y) animated:NO];
            }
        }
        
        if (!_isLoaded) {
            [self updatePage];
            _isLoaded = true;
        }
        
        return;
    }
    
    CGFloat ratio = CGRectGetWidth(self.contentView.frame) / CGRectGetWidth(self.menuMonthsView.frame);
    if(isnan(ratio)){
        ratio = 1.;
    }
    ratio *= self.calendarAppearance.ratioContentMenu;
    
    if(sender == self.menuMonthsView && self.menuMonthsView.scrollEnabled){
        self.contentView.contentOffset = CGPointMake(sender.contentOffset.x * ratio, self.contentView.contentOffset.y);
    }
    else if(sender == self.contentView && self.contentView.scrollEnabled){
        self.menuMonthsView.contentOffset = CGPointMake(sender.contentOffset.x / ratio, self.menuMonthsView.contentOffset.y);
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    self.lastContentOffset = scrollView.contentOffset.x;
    
    if(scrollView == self.contentView){
        self.menuMonthsView.scrollEnabled = NO;
    }
    else if(scrollView == self.menuMonthsView){
        self.contentView.scrollEnabled = NO;
    }
}

// Use for scroll with scrollRectToVisible or setContentOffset
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self updatePage];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self updatePage];
}

- (void)updatePage
{
    CGFloat pageWidth = CGRectGetWidth(self.contentView.frame);
    CGFloat fractionalPage = self.contentView.contentOffset.x / pageWidth;
        
    int currentPage = roundf(fractionalPage);
    if (currentPage == (NUMBER_PAGES_LOADED / 2)){
        if(!self.calendarAppearance.isWeekMode){
            self.menuMonthsView.scrollEnabled = YES;
        }
        self.contentView.scrollEnabled = YES;
        
        [self setUpScrollRangeForCurrentPage:currentPage];
        
        return;
    }
    
    NSCalendar *calendar = self.calendarAppearance.calendar;
    NSDateComponents *dayComponent = [NSDateComponents new];
    
    dayComponent.month = 0;
    dayComponent.day = 0;
    
    if(!self.calendarAppearance.isWeekMode){
        dayComponent.month = currentPage - (NUMBER_PAGES_LOADED / 2);
    }
    else{
        dayComponent.day = 7 * (currentPage - (NUMBER_PAGES_LOADED / 2));
    }
    
    if(self.calendarAppearance.readFromRightToLeft){
        dayComponent.month *= -1;
        dayComponent.day *= -1;
    }
    
    [self setUpScrollRangeForCurrentPage:currentPage];
        
    NSDate *currentDate = [calendar dateByAddingComponents:dayComponent toDate:self.currentDate options:0];
    
    [self setCurrentDate:currentDate];
    
    if(!self.calendarAppearance.isWeekMode){
        self.menuMonthsView.scrollEnabled = YES;
    }
    
    self.contentView.scrollEnabled = YES;
    
    if(currentPage < (NUMBER_PAGES_LOADED / 2)){
        if([self.dataSource respondsToSelector:@selector(calendarDidLoadPreviousPage)]){
            [self.dataSource calendarDidLoadPreviousPage];
        }
    }
    else if(currentPage > (NUMBER_PAGES_LOADED / 2)){
        if([self.dataSource respondsToSelector:@selector(calendarDidLoadNextPage)]){
            [self.dataSource calendarDidLoadNextPage];
        }
    }
}

- (void)scrollRangeForSender:(UIScrollView *)scrollView {
    
    CGFloat pageWidth = CGRectGetWidth(self.contentView.frame);
    CGFloat fractionalPage = self.contentView.contentOffset.x / pageWidth;
    int currentPage = roundf(fractionalPage);
    
    [self setUpScrollRangeForCurrentPage:currentPage];
}

- (void)setUpScrollRangeForCurrentPage:(int)currentPage {
    
    NSCalendar *calendar = self.calendarAppearance.calendar;
    NSDateComponents *dayComponent = [NSDateComponents new];
    
    dayComponent.month = 0;
    dayComponent.day = 0;
    
    if(!self.calendarAppearance.isWeekMode){
        dayComponent.month = currentPage - (NUMBER_PAGES_LOADED / 2);
    }
    else{
        dayComponent.day = 7 * (currentPage - (NUMBER_PAGES_LOADED / 2));
    }
    
    if(self.calendarAppearance.readFromRightToLeft){
        dayComponent.month *= -1;
        dayComponent.day *= -1;
    }
    
    NSDate *weekStartDate = [calendar dateByAddingComponents:dayComponent toDate:self.currentDate options:0];
    
    NSDateComponents *weekEndDateComponent = [dayComponent copy];
    weekEndDateComponent.day += 6;
    
    NSDate *weekEndDate = [calendar dateByAddingComponents:weekEndDateComponent toDate:self.currentDate options:0];
    
    [self scrollRangeWithStart:weekStartDate toEnd:weekEndDate];
}

- (void)scrollRangeWithStart:(NSDate *)weekStartDate toEnd:(NSDate *)weekEndDate {
    
    if ([self.dataSource respondsToSelector:@selector(calendarEndDateLimit)]) {
        NSDate *limitDate = [self.dataSource calendarEndDateLimit];
        _preventLoadNext = [self rangeEnd:limitDate isLessThanEquals:weekEndDate];
    }
    
    if ([self.dataSource respondsToSelector:@selector(calendarStartDateLimit)]) {
        NSDate *limitDate = [self.dataSource calendarStartDateLimit];
        _preventLoadPrevious = [self rangeStart:limitDate isGreaterThanEquals:weekStartDate];
    }
}

- (BOOL )rangeStart:(NSDate *)rangeStart isGreaterThanEquals:(NSDate *)weekStart {
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSInteger comps = (NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit);
    
    NSDateComponents *weekStartComponent = [calendar components:comps
                                                    fromDate: weekStart];
    NSDateComponents *rangeStartComponent = [calendar components:comps
                                                    fromDate: rangeStart];
    
    weekStart = [calendar dateFromComponents:weekStartComponent];
    rangeStart = [calendar dateFromComponents:rangeStartComponent];
    
    NSComparisonResult result = [weekStart compare:rangeStart];
    
    if (result == NSOrderedAscending || result == NSOrderedSame) {
        return true;
    }
    
    return false;
}

- (BOOL )rangeEnd:(NSDate *)rangeEnd isLessThanEquals:(NSDate *)weekEnd {
 
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSInteger comps = (NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit);
    
    NSDateComponents *date1Components = [calendar components:comps
                                                    fromDate: weekEnd];
    NSDateComponents *date2Components = [calendar components:comps
                                                    fromDate: rangeEnd];
    
    weekEnd = [calendar dateFromComponents:date1Components];
    rangeEnd = [calendar dateFromComponents:date2Components];
    
    NSComparisonResult result = [weekEnd compare:rangeEnd];
    
    if (result == NSOrderedDescending || result == NSOrderedSame) {
        return true;
    }
    
    return false;
}

- (void)repositionViews
{
    // Position to the middle page
    CGFloat pageWidth = CGRectGetWidth(self.contentView.frame);
    self.contentView.contentOffset = CGPointMake(pageWidth * ((NUMBER_PAGES_LOADED / 2)), self.contentView.contentOffset.y);
    
    CGFloat menuPageWidth = CGRectGetWidth([self.menuMonthsView.subviews.firstObject frame]);
    self.menuMonthsView.contentOffset = CGPointMake(menuPageWidth * ((NUMBER_PAGES_LOADED / 2)), self.menuMonthsView.contentOffset.y);
}

- (void)loadNextMonth
{
    [self loadNextPage];
}

- (void)loadPreviousMonth
{
    [self loadPreviousPage];
}

- (void)loadNextPage
{
    self.menuMonthsView.scrollEnabled = NO;
    
    CGRect frame = self.contentView.frame;
    frame.origin.x = frame.size.width * ((NUMBER_PAGES_LOADED / 2) + 1);
    frame.origin.y = 0;
    [self.contentView scrollRectToVisible:frame animated:YES];
}

- (void)loadPreviousPage
{
    self.menuMonthsView.scrollEnabled = NO;
    
    CGRect frame = self.contentView.frame;
    frame.origin.x = frame.size.width * ((NUMBER_PAGES_LOADED / 2) - 1);
    frame.origin.y = 0;
    [self.contentView scrollRectToVisible:frame animated:YES];
}

@end
