Simple A* algorithm implementation
==================================

A* (a star) algorithm implementation for Objective-C

Usage:
------

Create instance of AStarSearch: 
```
    NSUInteger start[] = {1, 2};
    NSIndexPath* startIndexPath = [NSIndexPath indexPathWithIndexes:start
                                                             length:sizeof(start)/sizeof(start[0])];
    NSUInteger goal[] = {3, 4};
    NSIndexPath* goalIndexPath = [NSIndexPath indexPathWithIndexes:goal
                                                            length:sizeof(goal)/sizeof(goal[0])];
    
    NSArray* path = [[AStarSearch aStarSearchWitDelegate:self] findPathFromStart:startIndexPath
                                                                            goal:goalIndexPath];
```
and implement AStarSearchDelegate - for each available move call -addAvailableMove:
```
-(BOOL)search:(AStarSearch *)search availableMovesForPath:(NSIndexPath *)current{

    NSUInteger xPosition = [current indexAtPosition:0]; 
    NSUInteger yPosition = [current indexAtPosition:1]; 

    NSUInteger move[] = {xPosition + 1, yPosition}; // for example increse x position
    NSIndexPath* moveIndexPath = [NSIndexPath indexPathWithIndexes:move
                                                            length:sizeof(move)/sizeof(move[0])];

    if ( [self canMoveFrom:current to:moveIndexPath] ) { // and check move availability
        [search addAvailableMove:[]]
    }
//...

    return YES;
}
```



