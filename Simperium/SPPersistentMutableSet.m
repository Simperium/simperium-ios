//
//  SPPersistentMutableSet.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 1/14/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import "SPPersistentMutableSet.h"
#import "JSONKit+Simperium.h"
#import "SPLogger.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static SPLogLevels logLevel	= SPLogLevelsError;


#pragma mark ====================================================================================
#pragma mark Private Methods
#pragma mark ====================================================================================

@interface SPPersistentMutableSet ()
@property (nonatomic, strong, readwrite) NSString		*label;
@property (nonatomic, strong, readwrite) NSURL			*mutableSetURL;
@property (nonatomic, strong, readwrite) NSMutableSet	*contents;
@end


#pragma mark ====================================================================================
#pragma mark SPMutableSetStorage
#pragma mark ====================================================================================

@implementation SPPersistentMutableSet

- (id)initWithLabel:(NSString *)label {
	if ((self = [super init])) {
		self.label		= label;
		self.contents	= [NSMutableSet setWithCapacity:3];
	}
	
	return self;
}

- (void)addObject:(id)object {
	[self.contents addObject:object];
}

- (void)removeObject:(id)object {
	[self.contents removeObject:object];
}

- (NSArray *)allObjects {
	return self.contents.allObjects;
}

- (NSUInteger)count {
	return self.contents.count;
}

- (void)addObjectsFromArray:(NSArray *)array {
	[self.contents addObjectsFromArray:array];
}

- (void)minusSet:(NSSet *)otherSet {
	[self.contents minusSet:otherSet];
}

- (void)removeAllObjects {
	return [self.contents removeAllObjects];
}


#pragma mark ====================================================================================
#pragma mark NSFastEnumeration
#pragma mark ====================================================================================

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len {
	return [self.contents countByEnumeratingWithState:state objects:buffer count:len];
}


#pragma mark ====================================================================================
#pragma mark Persistance!
#pragma mark ====================================================================================

- (void)save {
    NSString *json = [[self.contents allObjects] sp_JSONString];
	
	NSError *error = nil;
	BOOL success = [json writeToURL:self.mutableSetURL atomically:NO encoding:NSUTF8StringEncoding error:&error];
	if (!success) {
		SPLogError(@"<> %@ :: %@", NSStringFromClass([self class]), error);
	}
}

+ (instancetype)loadSetWithLabel:(NSString *)label {
	SPPersistentMutableSet *loaded = [[SPPersistentMutableSet alloc] initWithLabel:label];
		
	[loaded migrateIfNeeded];
	[loaded loadFromFilesystem];
		
	return loaded;
}


#pragma mark ====================================================================================
#pragma mark Helpers
#pragma mark ====================================================================================

- (void)loadFromFilesystem {
	NSString *rawData	= [NSString stringWithContentsOfURL:self.mutableSetURL encoding:NSUTF8StringEncoding error:nil];
	NSArray *list		= [rawData sp_objectFromJSONString];
    if (list.count > 0) {
        [self addObjectsFromArray:list];
	}
}

// NOTE: This helper class used to rely on NSUserDefaults. Due to performance issues, we've moved to the filesystem!
- (void)migrateIfNeeded {
	
	// Load + Import
	NSArray *list = [[[NSUserDefaults standardUserDefaults] objectForKey:self.label] sp_objectFromJSONString];
	
    if (list.count == 0) {
		return;
	}
	
	[self addObjectsFromArray:list];
	[self save];
	
	// Nuke defaults
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:self.label];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSURL *)mutableSetURL {
	
	if (_mutableSetURL) {
		return _mutableSetURL;
	}
	
	@synchronized(self) {
		// If the baseURL doesn't exist, create it
		NSURL *baseURL	= self.baseURL;
		
		NSError *error	= nil;
		BOOL success	= [[NSFileManager defaultManager] createDirectoryAtURL:baseURL withIntermediateDirectories:YES attributes:nil error:&error];
		
		if (!success) {
			SPLogError(@"%@ could not create baseURL %@ :: %@", NSStringFromClass([self class]), baseURL, error);
			abort();
		}
		
		_mutableSetURL = [baseURL URLByAppendingPathComponent:self.filename];
	}
	
	return _mutableSetURL;
}

- (NSString *)filename {
	return [NSString stringWithFormat:@"SPMutableSet-%@.json", self.label];
}

#if TARGET_OS_IPHONE

- (NSURL *)baseURL {
	return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

#else

- (NSURL *)baseURL {
    NSURL *appSupportURL = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
	
	// NOTE:
	// While running UnitTests on OSX, the applicationSupport folder won't bear any application name.
	// This will cause, as a side effect, SPDictionaryStorage test-database's to get spread in the AppSupport folder.
	// As a workaround (until we figure out a better way of handling this), let's detect XCTestCase class, and append the Simperium-OSX name to the path.
	// That will generate an URL like this:
	//		- //Users/[USER]/Library/Application Support/Simperium-OSX/SPPersistentMutableSet/
	//
	if (NSClassFromString(@"XCTestCase") != nil) {
		NSBundle *bundle = [NSBundle bundleForClass:[self class]];
		appSupportURL = [appSupportURL URLByAppendingPathComponent:[bundle objectForInfoDictionaryKey:(NSString*)kCFBundleNameKey]];
	}
	
	return [appSupportURL URLByAppendingPathComponent:NSStringFromClass([self class])];
}

#endif

@end
