// SPDiffable.h

@class SPGhost;
@class SPBucket;

@protocol SPDiffable <NSObject>

@required
@property (nonatomic, strong) SPGhost *ghost;
@property (nonatomic, copy) NSString *ghostData;
@property (nonatomic, copy) NSString *simperiumKey;
@property (nonatomic, weak) SPBucket *bucket;
@property (nonatomic, copy, readonly) NSDictionary *dictionary;
@property (nonatomic, copy, readonly) NSString *version;

- (void)simperiumSetValue:(id)value forKey:(NSString *)key;
- (id)simperiumValueForKey:(NSString *)key;
- (void)loadMemberData:(NSDictionary *)data;
- (void)willBeRead;
- (id)object;

@optional
- (NSString *)getSimperiumKeyFromLegacyKey;
- (BOOL)shouldOverwriteLocalChangesFromIndex;

@end
