//
//  SPGraphViewController.m
//  Simplestat
//
//  Created by Michael Johnston on 12-04-25.
//  Copyright (c) 2012 Simperium. All rights reserved.
//

#import "SPGraphViewController.h"
#import "Stat.h"
#import "SPAppDelegate.h"

@interface SPGraphViewController ()

@end

@implementation SPGraphViewController
@synthesize dataForPlot;
@synthesize statItem = _statItem;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

-(void)setStatItem:(Stat *)statItem {
    if (_statItem != statItem) {
        _statItem = statItem;        
    }    
}

-(void)receivedObjectForKey:(NSString *)key version:(NSString *)version data:(NSDictionary *)data {
    if ([key isEqualToString:_statItem.simperiumKey]) {        
        int x = [_statItem.version integerValue] - [version integerValue];
        int y = [[data objectForKey:@"value"] integerValue];
        
        NSMutableDictionary *statData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithInt: x], @"x",
                                         [NSNumber numberWithInt: y], @"y", nil];
        [self.dataForPlot addObject:statData];
        
        // Sort by value to get min/max (not efficient)
        NSSortDescriptor *aSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"y" ascending:YES];
        [self.dataForPlot sortUsingDescriptors:[NSArray arrayWithObject:aSortDescriptor]];
        int max = [[[self.dataForPlot lastObject] objectForKey:@"y"] integerValue];
        
        // Sort by X axis
        aSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"x" ascending:YES];
        [self.dataForPlot sortUsingDescriptors:[NSArray arrayWithObject:aSortDescriptor]];

        // Make the graph fit
        float rangeY = (int)((max+max*0.3) / 100) * 100;
        CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
        plotSpace.allowsUserInteraction = YES;
        plotSpace.xRange				= [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(-2.0) length:CPTDecimalFromFloat(14.0)];
        plotSpace.yRange				= [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(-2.0) length:CPTDecimalFromFloat(rangeY)];
        
        CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
        CPTXYAxis *yaxis = axisSet.yAxis;
        yaxis.majorIntervalLength = CPTDecimalFromFloat(rangeY/10.0);

        
        [graph reloadData];
    }
}

#pragma mark -
#pragma mark Initialization and teardown


-(void)viewDidLoad
{
	[super viewDidLoad];
    
    self.dataForPlot = [NSMutableArray arrayWithCapacity:30];
    
	// Create graph from theme
	graph = [[CPTXYGraph alloc] initWithFrame:CGRectZero];
	CPTTheme *theme = [CPTTheme themeNamed:kCPTDarkGradientTheme];
	[graph applyTheme:theme];
	CPTGraphHostingView *hostingView = (CPTGraphHostingView *)self.view;
	hostingView.collapsesLayers = NO; // Setting to YES reduces GPU memory usage, but can slow drawing/scrolling
	hostingView.hostedGraph		= graph;
    
	graph.paddingLeft	= 10.0;
	graph.paddingTop	= 10.0;
	graph.paddingRight	= 10.0;
	graph.paddingBottom = 10.0;
    
	// Setup plot space
	CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
	plotSpace.allowsUserInteraction = YES;
	plotSpace.xRange				= [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(-1.0) length:CPTDecimalFromFloat(12.0)];
	plotSpace.yRange				= [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(-1.0) length:CPTDecimalFromFloat(600.0)];
    
	// Axes
	CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
	CPTXYAxis *x		  = axisSet.xAxis;
	x.majorIntervalLength		  = CPTDecimalFromString(@"1.0");
	x.orthogonalCoordinateDecimal = CPTDecimalFromString(@"0");
	x.minorTicksPerInterval		  = 0;
//	NSArray *exclusionRanges = [NSArray arrayWithObjects:
//								[CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(1.99) length:CPTDecimalFromFloat(0.02)],
//								[CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(0.99) length:CPTDecimalFromFloat(0.02)],
//								[CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(2.99) length:CPTDecimalFromFloat(0.02)],
//								nil];
//	x.labelExclusionRanges = exclusionRanges;
    
	CPTXYAxis *y = axisSet.yAxis;
	y.majorIntervalLength		  = CPTDecimalFromString(@"60.0");
	y.minorTicksPerInterval		  = 1;
	y.orthogonalCoordinateDecimal = CPTDecimalFromString(@"0");
//	exclusionRanges				  = [NSArray arrayWithObjects:
//									 [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(1.99) length:CPTDecimalFromFloat(0.02)],
//									 [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(0.99) length:CPTDecimalFromFloat(0.02)],
//									 [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(3.99) length:CPTDecimalFromFloat(0.02)],
//									 nil];
//	y.labelExclusionRanges = exclusionRanges;
	y.delegate			   = self;
    
	// Create a blue plot area
	CPTScatterPlot *boundLinePlot  = [[CPTScatterPlot alloc] init];
	CPTMutableLineStyle *lineStyle = [CPTMutableLineStyle lineStyle];
	lineStyle.miterLimit		= 1.0f;
	lineStyle.lineWidth			= 3.0f;
	lineStyle.lineColor			= [CPTColor blueColor];
	boundLinePlot.dataLineStyle = lineStyle;
	boundLinePlot.identifier	= @"Blue Plot";
	boundLinePlot.dataSource	= self;
	[graph addPlot:boundLinePlot];
    
//	// Do a blue gradient
//	CPTColor *areaColor1	   = [CPTColor colorWithComponentRed:0.3 green:0.3 blue:1.0 alpha:0.8];
//	CPTGradient *areaGradient1 = [CPTGradient gradientWithBeginningColor:areaColor1 endingColor:[CPTColor clearColor]];
//	areaGradient1.angle = -90.0f;
//	CPTFill *areaGradientFill = [CPTFill fillWithGradient:areaGradient1];
//	boundLinePlot.areaFill		= areaGradientFill;
//	boundLinePlot.areaBaseValue = [[NSDecimalNumber zero] decimalValue];
    
	// Add plot symbols
	CPTMutableLineStyle *symbolLineStyle = [CPTMutableLineStyle lineStyle];
	symbolLineStyle.lineColor = [CPTColor blackColor];
	CPTPlotSymbol *plotSymbol = [CPTPlotSymbol ellipsePlotSymbol];
	plotSymbol.fill			 = [CPTFill fillWithColor:[CPTColor blueColor]];
	plotSymbol.lineStyle	 = symbolLineStyle;
	plotSymbol.size			 = CGSizeMake(10.0, 10.0);
	boundLinePlot.plotSymbol = plotSymbol;
    
//	// Create a green plot area
//	CPTScatterPlot *dataSourceLinePlot = [[CPTScatterPlot alloc] init];
//	lineStyle						 = [CPTMutableLineStyle lineStyle];
//	lineStyle.lineWidth				 = 3.f;
//	lineStyle.lineColor				 = [CPTColor greenColor];
//	lineStyle.dashPattern			 = [NSArray arrayWithObjects:[NSNumber numberWithFloat:5.0f], [NSNumber numberWithFloat:5.0f], nil];
//	dataSourceLinePlot.dataLineStyle = lineStyle;
//	dataSourceLinePlot.identifier	 = @"Green Plot";
//	dataSourceLinePlot.dataSource	 = self;
//    
//	// Put an area gradient under the plot above
//	CPTColor *areaColor		  = [CPTColor colorWithComponentRed:0.3 green:1.0 blue:0.3 alpha:0.8];
//	CPTGradient *areaGradient = [CPTGradient gradientWithBeginningColor:areaColor endingColor:[CPTColor clearColor]];
//	areaGradient.angle				 = -90.0f;
//	areaGradientFill				 = [CPTFill fillWithGradient:areaGradient];
//	dataSourceLinePlot.areaFill		 = areaGradientFill;
//	dataSourceLinePlot.areaBaseValue = CPTDecimalFromString(@"1.75");
//    
//	// Animate in the new plot, as an example
//	dataSourceLinePlot.opacity = 0.0f;
//	[graph addPlot:dataSourceLinePlot];
//    
//	CABasicAnimation *fadeInAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
//	fadeInAnimation.duration			= 1.0f;
//	fadeInAnimation.removedOnCompletion = NO;
//	fadeInAnimation.fillMode			= kCAFillModeForwards;
//	fadeInAnimation.toValue				= [NSNumber numberWithFloat:1.0];
//	[dataSourceLinePlot addAnimation:fadeInAnimation forKey:@"animateOpacity"];
    
	// Add some initial data
//	NSMutableArray *contentArray = [NSMutableArray arrayWithCapacity:100];
//	NSUInteger i;
//	for ( i = 0; i < 60; i++ ) {
//		id x = [NSNumber numberWithFloat:1 + i * 0.05];
//		id y = [NSNumber numberWithFloat:1.2 * rand() / (float)RAND_MAX + 1.2];
//		[contentArray addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:x, @"x", y, @"y", nil]];
//	}
//	self.dataForPlot = contentArray;
    
#ifdef PERFORMANCE_TEST
	[NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(changePlotRange) userInfo:nil repeats:YES];
#endif
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self.dataForPlot removeAllObjects];
    
    SPAppDelegate *appDelegate = (SPAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate.simperium getVersions:10 forObject:_statItem];
    [appDelegate.simperium addDelegate:self];

}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    SPAppDelegate *appDelegate = (SPAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate.simperium removeDelegate:self];
}

-(void)changePlotRange
{
	// Setup plot space
	CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
    
	plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(0.0) length:CPTDecimalFromFloat(3.0 + 2.0 * rand() / RAND_MAX)];
	plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(0.0) length:CPTDecimalFromFloat(3.0 + 2.0 * rand() / RAND_MAX)];
}

#pragma mark -
#pragma mark Plot Data Source Methods

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot
{
	return [dataForPlot count];
}

-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{
	NSString *key = (fieldEnum == CPTScatterPlotFieldX ? @"x" : @"y");
	NSNumber *num = [[dataForPlot objectAtIndex:index] valueForKey:key];
    
	// Green plot gets shifted above the blue
//	if ( [(NSString *)plot.identifier isEqualToString:@"Green Plot"] ) {
//		if ( fieldEnum == CPTScatterPlotFieldY ) {
//			num = [NSNumber numberWithDouble:[num doubleValue] + 1.0];
//		}
//	}
	return num;
}

#pragma mark -
#pragma mark Axis Delegate Methods

-(BOOL)axis:(CPTAxis *)axis shouldUpdateAxisLabelsAtLocations:(NSSet *)locations
{
	static CPTTextStyle *positiveStyle = nil;
	static CPTTextStyle *negativeStyle = nil;
    
	NSNumberFormatter *formatter = axis.labelFormatter;
	CGFloat labelOffset			 = axis.labelOffset;
	NSDecimalNumber *zero		 = [NSDecimalNumber zero];
    
	NSMutableSet *newLabels = [NSMutableSet set];
    
	for ( NSDecimalNumber *tickLocation in locations ) {
		CPTTextStyle *theLabelTextStyle;
        
		if ( [tickLocation isGreaterThanOrEqualTo:zero] ) {
			if ( !positiveStyle ) {
				CPTMutableTextStyle *newStyle = [axis.labelTextStyle mutableCopy];
				newStyle.color = [CPTColor greenColor];
				positiveStyle  = newStyle;
			}
			theLabelTextStyle = positiveStyle;
		}
		else {
			if ( !negativeStyle ) {
				CPTMutableTextStyle *newStyle = [axis.labelTextStyle mutableCopy];
				newStyle.color = [CPTColor redColor];
				negativeStyle  = newStyle;
			}
			theLabelTextStyle = negativeStyle;
		}
        
		NSString *labelString		= [formatter stringForObjectValue:tickLocation];
		CPTTextLayer *newLabelLayer = [[CPTTextLayer alloc] initWithText:labelString style:theLabelTextStyle];
        
		CPTAxisLabel *newLabel = [[CPTAxisLabel alloc] initWithContentLayer:newLabelLayer];
		newLabel.tickLocation = tickLocation.decimalValue;
		newLabel.offset		  = labelOffset;
        
		[newLabels addObject:newLabel];
	}
    
	axis.axisLabels = newLabels;
    
	return NO;
}


- (IBAction)done:(id)sender {
    [self.navigationController dismissModalViewControllerAnimated:YES];
}
@end
