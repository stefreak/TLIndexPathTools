//
//  TLFetchedResultsController.m
//  DealerCarStory
//
//  Created by Tim Moose on 5/17/13.
//
//

#import "TLFetchedResultsController.h"

@interface TLFetchedResultsController ()
@property (strong, nonatomic) dispatch_queue_t batchQueue;
@property (strong, nonatomic) NSLock *batchBarrier;
@property (strong, nonatomic) NSFetchedResultsController *backingController;
@property (strong, nonatomic, readonly) NSString *identifierKeyPath;
@property (nonatomic) BOOL isFetched;
@end

@implementation TLFetchedResultsController

- (void)dealloc {
    //the delegate property is an 'assign' property
    //not technically needed because the FRC will dealloc when we do, but it's a good idea.
    self.backingController.delegate = nil;
}

#pragma mark - Initialization

- (id)initWithFetchRequest:(NSFetchRequest *)fetchRequest managedObjectContext:(NSManagedObjectContext *)context sectionNameKeyPath:(NSString *)sectionNameKeyPath identifierKeyPath:(NSString *)identifierKeyPath cacheName:(NSString *)name
{    
    if (self = [super init]) {
        _backingController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:context sectionNameKeyPath:sectionNameKeyPath cacheName:name];
        _backingController.delegate = self;
        _batchQueue = dispatch_queue_create("tl-fetched-results-controller-queue", DISPATCH_QUEUE_SERIAL);
        _batchBarrier = [[NSLock alloc] init];        
    }
    return self;
}

#pragma mark - Fetching data

- (BOOL)performFetch:(NSError *__autoreleasing *)error
{
    BOOL result = [self.backingController performFetch:error];
    if (result) {
        NSArray *fetchedItems =  self.backingController.fetchedObjects;
        TLIndexPathDataModel *dataModel = [[TLIndexPathDataModel alloc] initWithItems:fetchedItems andSectionNameKeyPath:self.backingController.sectionNameKeyPath andIdentifierKeyPath:self.identifierKeyPath andCellIdentifierKeyPath:self.dataModel.cellIdentifierKeyPath];
        self.dataModel = dataModel;
        self.isFetched = YES;
    }
    return result;
}

#pragma mark - Configuration information

- (void)setFetchRequest:(NSFetchRequest *)fetchRequest
{
    if (![self.fetchRequest isEqual:fetchRequest]) {
        self.backingController = [[NSFetchedResultsController alloc]
                                  initWithFetchRequest:fetchRequest
                                  managedObjectContext:self.backingController.managedObjectContext
                                  sectionNameKeyPath:self.backingController.sectionNameKeyPath
                                  cacheName:self.backingController.cacheName];
        self.backingController.delegate = self;
    }
}

- (NSFetchRequest *)fetchRequest
{
    return self.backingController.fetchRequest;
}

- (void)setManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if (![self.managedObjectContext isEqual:managedObjectContext]) {
        self.backingController = [[NSFetchedResultsController alloc]
                                  initWithFetchRequest:self.backingController.fetchRequest
                                  managedObjectContext:managedObjectContext
                                  sectionNameKeyPath:self.backingController.sectionNameKeyPath
                                  cacheName:self.backingController.cacheName];
        self.backingController.delegate = self;
    }
}

- (NSManagedObjectContext *)managedObjectContext
{
    return self.backingController.managedObjectContext;
}

- (void)setCacheName:(NSString *)cacheName
{
    if (![self.cacheName isEqual:cacheName]) {
        self.backingController = [[NSFetchedResultsController alloc]
                                  initWithFetchRequest:self.backingController.fetchRequest
                                  managedObjectContext:self.backingController.managedObjectContext
                                  sectionNameKeyPath:self.backingController.sectionNameKeyPath
                                  cacheName:cacheName];
        self.backingController.delegate = self;
    }
}

- (NSString *)cacheName
{
    return self.backingController.cacheName;
}

+ (void)deleteCacheWithName:(NSString *)name
{
    [NSFetchedResultsController deleteCacheWithName:name];
}

- (NSString *)identifierKeyPath
{
    //fall back to objectID in case the data model doesn't have a value defined.
    //This is necessary because managed objects themselves cannot be used as
    //identifiers because identifiers are used as dictionary keys and therefore
    //must implement NSCoding (which NSManagedObject does not).
    NSString *identifierKeyPath = self.dataModel.identifierKeyPath ? self.dataModel.identifierKeyPath : @"objectID";
    return identifierKeyPath;
}

- (void)setIgnoreIncrementalChanges:(BOOL)ignoreIncrementalChanges
{
    if (_ignoreIncrementalChanges != ignoreIncrementalChanges) {
        _ignoreIncrementalChanges = ignoreIncrementalChanges;
        //if fetch was ever performed, automatically re-perform fetch when
        //ignoring is disabled.
        //TODO we might want to consider queueing up the incremental changes
        //that get reported by the backing controller while ignoring is enabled
        //and not having to perform a full fetch.
        if (NO == ignoreIncrementalChanges && self.isFetched) {
            [self performFetch:nil];
        }
    }
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if (!self.ignoreIncrementalChanges) {
        NSArray *fetchedItems =  self.backingController.fetchedObjects;
        TLIndexPathDataModel *dataModel = [[TLIndexPathDataModel alloc] initWithItems:fetchedItems andSectionNameKeyPath:self.backingController.sectionNameKeyPath andIdentifierKeyPath:self.identifierKeyPath andCellIdentifierKeyPath:self.dataModel.cellIdentifierKeyPath];
        self.dataModel = dataModel;
    }
}

- (NSString *)controller:(NSFetchedResultsController *)controller sectionIndexTitleForSectionName:(NSString *)sectionName
{
    return sectionName;
}

@end