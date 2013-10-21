//
//  SPMemberBinaryInfo.h
//  Simperium
//
//  Created by Michael Johnston on 11-11-24.
//  Copyright (c) 2011 Simperium. All rights reserved.
//

#import "SPMember.h"


extern NSString* const SPMemberBinaryInfoSuffix;

@interface SPMemberBinaryInfo : SPMember
@property (nonatomic, strong, readonly)  NSString *dataKey;
@property (nonatomic, strong, readonly)  NSString *infoKey;
@end
