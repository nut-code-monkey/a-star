#import <Foundation/Foundation.h>

@class AStarSearch;

@protocol AStarSearchDelegate <NSObject>

-(BOOL)search:( AStarSearch* )search availableMovesForPath:( NSIndexPath* )path;

@optional

// used manhattan distance by default: ABS(x1-x2) + ABS(y1-y2)
-(CGFloat)search:(AStarSearch*)search distanceEstimateFrom:( NSIndexPath* )first to:( NSIndexPath* )second;
// return 1 by default
-(CGFloat)search:(AStarSearch*)search moveCoastFrom:( NSIndexPath* )first to:( NSIndexPath* )second;

@end

@interface AStarSearch : NSObject

@property (weak, nonatomic) id<AStarSearchDelegate> delegate;

+(instancetype)aStarSearchWitDelegate:( id<AStarSearchDelegate> )delegate;

-(void)cancelSearch;

// Set Start and goal states
-(NSArray*)findPathFromStart:( NSIndexPath* )start goal:( NSIndexPath* )goal;

// User calls this to add an available moves to a list of available moves
// caled from -search:availableMovesForPath:
-(void)addAvailableMove:( NSIndexPath* )path;

@end
