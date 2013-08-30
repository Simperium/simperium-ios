//
//  NSArray+Simperium.m
//  Simperium
//
//  Created by Andrew Mackenzie-Ross on 19/07/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "NSArray+Simperium.h"
#import "SPMember.h"
#import "DiffMatchPatch.h"
#import "JSONKit.h"
#import "DDLog.h"


@implementation NSArray (Simperium)





#pragma mark - List Diff with Operations

// TODO: Implement?
//
//- (NSArray *)sp_arrayByApplyingDiff:(NSDictionary *)diff
//{
//	NSMutableArray *array = [self mutableCopy];
//	
//	NSArray *indexes = [[diff allKeys] sortedArrayUsingSelector:@selector(compare:)];
//	NSMutableIndexSet *indexesToReplace = [[NSMutableIndexSet alloc] init];
//	NSMutableArray *replacementObjects = [[NSMutableArray alloc] init];
//	NSMutableIndexSet *indexesToRemove = [[NSMutableIndexSet alloc] init];
//	NSMutableIndexSet *indexesToInsert = [[NSMutableIndexSet alloc] init];
//	NSMutableArray *insertedObjects = [[NSMutableArray alloc] init];
//	for (NSNumber *index in indexes) {
//		NSDictionary *elementDiff = [diff objectForKey:index];
//		
//		NSString *operation = [elementDiff objectForKey:OP_OP];
//		if ([operation isEqualToString:OP_REPLACE]) {
//			[replacementObjects addObject:[elementDiff objectForKey:OP_VALUE]];
//			[indexesToReplace addIndex:[index integerValue]];
//		} else if ([operation isEqualToString:OP_LIST_DELETE]) {
//			[indexesToRemove addIndex:[index integerValue]];
//		} else if ([operation isEqualToString:OP_LIST_INSERT]) {
//			[insertedObjects addObject:[elementDiff objectForKey:OP_VALUE]];
//			[indexesToInsert addIndex:[index integerValue]];
//		} else {
//			NSAssert(NO, @"Diff operation %@ is not supported within lists.", operation);
//		}
//	}
//	
//	[array replaceObjectsAtIndexes:indexesToReplace withObjects:replacementObjects];
//	[array removeObjectsAtIndexes:indexesToRemove];
//	[array insertObjects:insertedObjects atIndexes:indexesToInsert];
//	
//	return array;
//}
//
//- (NSDictionary *)sp_diffWithArray:(NSArray *)obj2
//{
//	if ([self isEqualToArray:obj2]) return @{};
//	NSArray *obj1 = self;
//	
//	NSMutableDictionary *diffs = [[NSMutableDictionary alloc] init];
//	
//	NSInteger prefixCount = [obj1 sp_countOfObjectsCommonWithArray:obj2 options:0];
//	obj1 = [obj1 subarrayWithRange:NSMakeRange(prefixCount, [obj1 count] - prefixCount)];
//	obj2 = [obj2 subarrayWithRange:NSMakeRange(prefixCount, [obj2 count] - prefixCount)];
//	
//	NSInteger suffixCount = [obj1 sp_countOfObjectsCommonWithArray:obj2 options:NSEnumerationReverse];
//	obj1 = [obj1 subarrayWithRange:NSMakeRange(0, [obj1 count] - suffixCount)];
//	obj2 = [obj2 subarrayWithRange:NSMakeRange(0, [obj2 count] - suffixCount)];
//	
//	NSInteger obj1Count = [obj1 count];
//	NSInteger obj2Count = [obj2 count];
//	for (int i = 0; i < MAX(obj1Count, obj2Count); i++) {
//		if (i < obj1Count && i < obj2Count) {
//			if ([obj1[i] isEqual:obj2[i]] == NO) {
//				diffs[@(i + prefixCount)] = @{ OP_OP: OP_REPLACE, OP_VALUE: obj2[i] };
//			}
//		} else if (i < obj1Count) {
//			diffs[@(i + prefixCount)] = @{ OP_OP: OP_LIST_DELETE };
//		} else if (i < obj2Count) {
//			diffs[@(i + prefixCount)] = @{ OP_OP: OP_LIST_INSERT, OP_VALUE: obj2[i] };
//		}
//	}
//	
//	return diffs;
//}
//
//
//
//- (NSInteger)sp_countOfObjectsCommonWithArray:(NSArray *)b options:(NSEnumerationOptions)options
//{
//	NSAssert(options ^ NSEnumerationConcurrent, @"%s doesn't support NSEnumerationConcurrent",__PRETTY_FUNCTION__);
//	__block NSInteger count = 0;
//	NSArray *a = self;
//	NSInteger shift = (options & NSEnumerationReverse) ? [b count] - [a count] : 0;
//	[self enumerateObjectsWithOptions:options usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//		NSInteger idxIntoB = idx + shift;
//		if (idxIntoB >= [b count] || idxIntoB < 0 || ![obj isEqual:b[idxIntoB]]) {
//			*stop = YES;
//		} else {
//			count++;
//		}
//	}];
//	
//	return count;
//}



@end
