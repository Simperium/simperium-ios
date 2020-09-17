//
//  Constants.h
//
//  Created by Michael Johnston on 11-02-11.
//  Copyright 2011 Simperium. All rights reserved.
//
//  A simple system for shared state. See http://simperium.com for details.

#import "SPEnvironment.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

/// Production
///
NSString* const SPBaseURL = @"https://api.simperium.com/1/";
NSString* const SPAuthURL = @"https://auth.simperium.com/1/";
NSString* const SPWebsocketURL = @"wss://api.simperium.com/sock/1";
NSString* const SPTermsOfServiceURL = @"https://simperium.com/tos/";

NSString* const SPAPIVersion = @"1.1";

#if TARGET_OS_IPHONE
NSString* const SPLibraryID = @"ios";
#else
NSString* const SPLibraryID = @"osx";
#endif

// TODO: Update this automatically via a script that looks at current git tag
NSString* const SPLibraryVersion = @"1.0.0";

/// SSL Pinning
///
/// 1. Extract the PEM:
///     > openssl s_client -showcerts -host api.simperium.com -port 443
/// 2. Calculate the Public Key Hash
///     > ./External/TrustKit/get_pin_from_certificate.py certificate.pem
/// 3. Verify PEM Expiration Date
///     > openssl x509 -enddate -noout -in certificate.pem
///
NSString* const SPPinnedDomain = @"api.simperium.com";
NSString* const SPPinnedPublicKeyHash = @"T97MoWLAydq7mqpZDJ4t6zRNZIUAD3alp/vqGkVPUIw=";
