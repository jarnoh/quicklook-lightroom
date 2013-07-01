//
//  quicklook-lightroom
//
//  Created by Jarno Heikkinen on 6/29/13.
//  Copyright (c) 2013 Jarno Heikkinen. All rights reserved.
//

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import "LrPrevImageData.h"

const float BASELEVEL_LOG2 = 6.0f; // about log2f(64)

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail);

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
    NSLog(@"GenerateThumbnailForURL %@ uti %@ %dx%d", url, contentTypeUTI, (int)maxSize.width, (int)maxSize.height);
    
    if([@"com.capturemonkey.lightroom.lrcat" isEqualToString:(__bridge NSString *)(contentTypeUTI)] )
    {
        return noErr;
    }
    
    int maxLevel = (int)ceilf(log2f(maxSize.width>maxSize.height ? maxSize.width : maxSize.height)-BASELEVEL_LOG2);
    NSData *data = [LrPrevImageData imageDataFromLrPrevMaxLevel:(__bridge NSURL *)(url) maxlevel:maxLevel];
    QLThumbnailRequestSetImageWithData(thumbnail, (__bridge CFDataRef)(data), nil);
    return noErr;
}

void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail)
{
    // Implement only if supported
}
