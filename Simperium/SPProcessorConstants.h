//
//  SPProcessorConstants.h
//  Simperium
//
//  Created by Michael Johnston on 9/9/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//


#pragma mark ====================================================================================
#pragma mark Notifications
#pragma mark ====================================================================================

extern NSString * const ProcessorDidAddObjectsNotification;
extern NSString * const ProcessorDidChangeObjectNotification;
extern NSString * const ProcessorDidDeleteObjectKeysNotification;
extern NSString * const ProcessorDidAcknowledgeObjectsNotification;
extern NSString * const ProcessorWillChangeObjectsNotification;
extern NSString * const ProcessorDidAcknowledgeDeleteNotification;


#pragma mark ====================================================================================
#pragma mark Changeset Errors
#pragma mark ====================================================================================

typedef NS_ENUM(NSInteger, SPProcessorErrors) {
    SPProcessorErrorsSentDuplicateChange,       // Should Re-Sync
    SPProcessorErrorsSentInvalidChange,         // Send Full Data: The backend couldn't apply our diff
    SPProcessorErrorsReceivedUnknownChange,     // No need to handle: We've received a change for an unknown entity
    SPProcessorErrorsReceivedInvalidChange,     // Should Redownload the Entity: We couldn't apply a remote diff
    SPProcessorErrorsClientOutOfSync,           // We received a change with an SV != local version: Reindex is required
    SPProcessorErrorsClientError,               // Should Nuke PendingChange: Catch-all client errors
    SPProcessorErrorsServerError                // Should Retry: Catch-all server errors
};

typedef NS_ENUM(NSUInteger, CH_ERRORS) {
    CH_ERRORS_INVALID_SCHEMA        = 400,
    CH_ERRORS_INVALID_PERMISSION    = 401,
    CH_ERRORS_NOT_FOUND             = 404,
    CH_ERRORS_BAD_VERSION           = 405,
    CH_ERRORS_DUPLICATE             = 409,
    CH_ERRORS_EMPTY_CHANGE          = 412,
    CH_ERRORS_DOCUMENT_TOO_lARGE    = 413,
    CH_ERRORS_EXPECTATION_FAILED    = 417,      // (e.g. foreign key doesn't exist just yet)
    CH_ERRORS_INVALID_DIFF          = 440,
    CH_ERRORS_THRESHOLD             = 503
};

// Internal Server Errors: [500-599]
static NSRange const CH_SERVER_ERROR_RANGE = {500, 99};
