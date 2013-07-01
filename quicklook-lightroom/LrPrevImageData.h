//
//  quicklook-lightroom
//
//  Created by Jarno Heikkinen on 6/29/13.
//  Copyright (c) 2013 Jarno Heikkinen. All rights reserved.
//

#pragma once

#include <Foundation/Foundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <CoreServices/CoreServices.h>



@interface LrPrevImageData : NSObject

-(id)initWithLrCatPath:(NSString*)path;
+(NSData*) imageDataFromLrPrevMaxLevel:(NSURL*)url maxlevel:(NSUInteger)maxlevel;


-(NSString*)catalogPath;
-(NSString*)lrPreviewsPath;
-(NSString*)lrPreviewsDbPath;
-(NSString*)previewUuid:(NSString*)guid digest:(NSString*)digest;


@end