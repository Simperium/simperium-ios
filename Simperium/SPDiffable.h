// SPDiffable.h

@class SPGhost;
@class SPBucket;

@protocol SPDiffable <NSObject>

@required
@property (nonatomic, retain) SPGhost *ghost;
@property (nonatomic, copy) NSString *ghostData;
@property (nonatomic, copy) NSString *simperiumKey;
@property (nonatomic, assign) SPBucket *bucket;

-(void)simperiumSetValue:(id)value forKey:(NSString *)key;
-(id)simperiumValueForKey:(NSString *)key;
-(void)loadMemberData:(NSDictionary *)data;
-(void)willBeRead;
-(NSDictionary *)dictionary;
-(NSString *)version;
-(id)object;

@end