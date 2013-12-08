#import "AStar.h"

// A node represents a possible state in the search
@class ASNode;
@interface ASNode : NSObject

@property (weak, nonatomic) ASNode* parent; // used during the search to record the parent of successor nodes
@property (assign, nonatomic) CGFloat g; // cost of this node + it's predecessors
@property (assign, nonatomic) CGFloat heuristicDistanceToGoal; // heuristic estimate of distance to goal
@property (assign, nonatomic) CGFloat cummulativeMoveCoast; // sum of cumulative cost of predecessors and self and heuristic
@property (strong, nonatomic) NSIndexPath* path;

+(instancetype)nodeWithPath:( NSIndexPath* )path;

@end

@implementation ASNode

+(instancetype)nodeWithPath:(NSIndexPath *)path
{
    ASNode* node = [[ASNode alloc] init];
    node.parent = nil;
    node.g = 0;
    node.heuristicDistanceToGoal = 0;
    node.cummulativeMoveCoast = 0;
    node.path = path;
    return node;
}

-(NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %@>", NSStringFromClass([self class]), self.path];
}

@end

// The AStar search class. UserState is the users state space type
typedef enum
{
    SEARCH_STATE_NOT_INITIALISED,
    SEARCH_STATE_SEARCHING,
    SEARCH_STATE_SUCCEEDED,
    SEARCH_STATE_FAILED,
    SEARCH_STATE_OUT_OF_MEMORY,
    SEARCH_STATE_INVALID
}
AStarSearchState;

@interface AStarSearch ()

 // Heap (simple vector but used as a heap, cf. Steve Rabin's game gems article)
@property (strong, nonatomic) NSMutableArray* openList;
// Closed list is a vector.
@property (strong, nonatomic) NSMutableArray* closedList;
// Successors is a vector filled out by the user each type successors to a node
// are generated
@property (strong, nonatomic) NSMutableArray* availableMoves;
// State
@property (assign, nonatomic) AStarSearchState state;
// Counts steps
@property (assign, nonatomic) NSUInteger steps;
// Start and goal state pointers
@property (strong, nonatomic) ASNode* start;
@property (strong, nonatomic) ASNode* goal;
@property (strong, nonatomic) ASNode* currentSolutionNode;

@property (assign, nonatomic) BOOL cancelRequest;

@end

@implementation AStarSearch

+(instancetype)aStarSearchWitDelegate:( id<AStarSearchDelegate> )delegate;
{
    AStarSearch* search = [[self alloc] init];
    search.state = SEARCH_STATE_NOT_INITIALISED;
    search.currentSolutionNode = NULL;
    search.cancelRequest = NO;
    search.delegate = delegate;
    search.openList = [NSMutableArray array];
    search.closedList = [NSMutableArray array];
    search.availableMoves = [NSMutableArray array];
	return search;
}

-(NSArray*)findPath
{
    NSMutableArray* steps = [NSMutableArray array];
    
    AStarSearchState searchState = self.state;
    NSUInteger searchSteps = 0;
    do
    {
        searchState = [self searchStep];
        searchSteps++;
    }
    while( searchState == SEARCH_STATE_SEARCHING );
        
    if( searchState == SEARCH_STATE_SUCCEEDED )
    {
        NSIndexPath* path = [self solutionStart];
        [steps addObject:path];
        for( ;; )
        {
            path = [self solutionNext];
            if( !path ) break;
            
            [steps addObject:path];
        };
        
        // Once you're done with the solution you can free the nodes up
        [self freeSolutionNodes];
    }
    else if( searchState == SEARCH_STATE_FAILED )
    {
        NSLog(@"Search terminated. Did not find goal state");
        return @[];
    }

    return [NSArray arrayWithArray:steps];
}

-(void)cancelSearch
{
    self.cancelRequest = YES;
}

-(NSArray*)findPathFromStart:( NSIndexPath* )start goal:( NSIndexPath* )goal
{
    self.cancelRequest = false;
    self.start = [ASNode nodeWithPath:start];
    self.goal = [ASNode nodeWithPath:goal];
    
    self.state = SEARCH_STATE_SEARCHING;
    
    // Initialise the AStar specific parts of the Start Node
    // The user only needs fill out the state information
    self.start.g = 0;
    
    self.start.heuristicDistanceToGoal = [self distanceFrom:start to:goal];
    if ([self.delegate respondsToSelector:@selector(search:distanceEstimateFrom:to:)])
    {
        self.start.heuristicDistanceToGoal = [self.delegate search:self distanceEstimateFrom:start to:goal];
    }
    
    self.start.cummulativeMoveCoast = self.start.g + self.start.heuristicDistanceToGoal;
    self.start.parent = nil;
    
    // Push the start node on the Open list
    
    [self.openList addObject:self.start]; // heap now unsorted
    
    // Initialise counter for search steps
    self.steps = 0;
    
    return [[[self findPath] reverseObjectEnumerator] allObjects];
}

-(void)addAvailableMove:( NSIndexPath* )path
{
    [self.availableMoves addObject:path];
}

// This call is made by the search class when the search ends. A lot of nodes may be
// created that are still present when the search ends. They will be deleted by this
// routine once the search ends
-(void)freeSolutionNodes;
{
    [self.openList removeAllObjects];
    [self.closedList removeAllObjects];
}

-(NSIndexPath*)solutionStart
{
    self.currentSolutionNode = self.goal;
    return self.goal ? self.goal.path : nil;
}

-(NSIndexPath*)solutionNext
{
    if( self.currentSolutionNode )
    {
        if( self.currentSolutionNode.parent )
        {
            ASNode *parent = self.currentSolutionNode.parent;
            self.currentSolutionNode = self.currentSolutionNode.parent;
            return parent.path;
        }
    }
    return nil;
}

// Get end node
-(NSIndexPath*)solutionEnd
{
    self.currentSolutionNode = self.start;
    return ( self.start ) ? self.start.path : nil;
}

static NSComparator nodesComparedByCummulativeMoveCoast = ^(ASNode *x, ASNode *y )
{
    return [@(x.cummulativeMoveCoast) compare: @(y.cummulativeMoveCoast)];
};

-(CGFloat)distanceFrom:(NSIndexPath*)from to:(NSIndexPath*)to
{
    NSAssert(from.length == to.length, nil);
    
    NSUInteger h = 0;
    for (NSUInteger i = 0; i < from.length; ++i)
    {
        h += MAX([from indexAtPosition:i], [to indexAtPosition:i])
           - MIN([from indexAtPosition:i], [to indexAtPosition:i]);
    }
    return h;
}

-(AStarSearchState)searchStep
{
    // Firstly break if the user has not initialised the search
    NSAssert(self.state > SEARCH_STATE_NOT_INITIALISED, nil);
    NSAssert(self.state < SEARCH_STATE_INVALID, nil);
    
    // Next I want it to be safe to do a searchstep once the search has succeeded...
    if((self.state == SEARCH_STATE_SUCCEEDED) || (self.state == SEARCH_STATE_FAILED))
    {
        return self.state;
    }
    
    // Failure is defined as emptying the open list as there is nothing left to
    // search...
    if(  self.openList.count == 0 || self.cancelRequest )
    {
        [self freeSolutionNodes];
        self.state = SEARCH_STATE_FAILED;
        return self.state;
    }
    
    // Incremement step count
    self.steps ++;
    
    // Pop the best node (the one with the lowest f)
    ASNode *node = [self.openList firstObject]; // get pointer to the node
    [self.openList removeObjectAtIndex:0];

    // Check for the goal, once we pop that we're done
    if( [self.goal.path isEqual:node.path] )
    {
        // The user is going to use the Goal Node he passed in
        // so copy the parent pointer of n
        self.goal.parent = node.parent;
        self.goal.g = node.g;
        
        self.state = SEARCH_STATE_SUCCEEDED;
        
        return self.state;
    }
    else // not goal
    {
        // We now need to generate the successors of this node
        // The user helps us to do this, and we keep the new nodes in
        [self.availableMoves removeAllObjects]; // empty vector of successor nodes to n
        
        // User provides this functions and uses AddSuccessor to add each successor of
        // node 'n' to m_Successors
        BOOL ret = [self.delegate search:self availableMovesForPath:node.path];
        
        if( !ret )
        {
            [self.availableMoves removeAllObjects];
            self.state = SEARCH_STATE_OUT_OF_MEMORY;
            return self.state;
        }
        
        // Now handle each successor to the current node ...
        for( NSIndexPath* availableMove in self.availableMoves)
        {
            // 	The g value for this successor ...
            
            CGFloat newG = node.g + 1;
            if ( [self.delegate respondsToSelector:@selector(search:moveCoastFrom:to:)] )
                newG = node.g + [self.delegate search:self moveCoastFrom:node.path to:availableMove];
            
            // Now we need to find whether the node is on the open or closed lists
            // If it is but the node that is already on them is better (lower g)
            // then we can forget about this successor
            
            // First linear search of open list to find node
            
            __block ASNode* inOpenListNode = nil;
            [self.openList enumerateObjectsUsingBlock:^(ASNode* node, NSUInteger idx, BOOL *stop)
             {
                 if ( [node.path isEqual:availableMove] )
                 {
                     inOpenListNode = node;
                     *stop = YES;
                 }
             }];
            
            if( inOpenListNode )
            {
                // we found this state on open
                if (inOpenListNode.g <= newG)
                {
                    // the one on Open is cheaper than this one
                    continue;
                }
            }
            
            __block ASNode* inClosesListNode = nil;
            [self.closedList enumerateObjectsUsingBlock:^(ASNode* node, NSUInteger idx, BOOL *stop)
             {
                 if ([node.path isEqual:availableMove])
                 {
                     inClosesListNode = node;
                     *stop = YES;
                 }
             }];

            if( inClosesListNode )
            {
                // we found this state on closed
                if( inClosesListNode.g <= newG)
                {
                    // the one on Closed is cheaper than this one
                    continue;
                }
            }
            
            // This node is the best node so far with this particular state
            // so lets keep it and set up its AStar specific data ...
            
            ASNode* newNode = [ASNode nodeWithPath:availableMove];
            
            newNode.parent = node;
            newNode.g = newG;
            
            newNode.heuristicDistanceToGoal = [self distanceFrom:availableMove to:self.goal.path];
            if ([self.delegate respondsToSelector:@selector(search:distanceEstimateFrom:to:)])
            {
                newNode.heuristicDistanceToGoal = [self.delegate search:self distanceEstimateFrom:availableMove to:self.goal.path];
            }

            newNode.cummulativeMoveCoast = newNode.g + newNode.heuristicDistanceToGoal;
            
            // Remove successor from closed if it was on it
            if( inClosesListNode )
            {
                // remove it from Closed
                [self.closedList removeObject:inClosesListNode];
            }
            
            // Update old version of this node
            if( inOpenListNode )
            {	   
                [self.openList removeObject:inOpenListNode];
            }
            
            [self.openList addObject:newNode];
            
            // sort back element into heap
            [self.openList sortUsingComparator:nodesComparedByCummulativeMoveCoast];
        }
        
        // push none onto Closed, as we have expanded it now
        
        [self.closedList addObject:node];
        
    } // end else (not goal so expand)
    
    return self.state;
}

@end
