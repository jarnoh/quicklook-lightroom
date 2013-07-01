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

#include <sqlite3.h>
#include <mach/mach.h>
#include <mach/mach_time.h>


OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);

#define SQL_LIMIT "LIMIT 4000"

const char *SQL_PREVIEWS="SELECT uuid, digest, orientation from ImageCacheEntry ORDER BY imageId DESC " SQL_LIMIT ";";
const char *SQL_LRCAT_PREVIEW="select f.id_global, d.digest, i.orientation from aglibraryfile f, adobe_images i, Adobe_imageDevelopSettings d where d.id_local=i.developSettingsIDCache and i.rootFile=f.id_local ORDER BY i.id_local DESC " SQL_LIMIT ";";


/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    NSLog(@"GeneratePreviewForURL %@ uti %@", url, contentTypeUTI);
    
    static mach_timebase_info_data_t    sTimebaseInfo;
    if ( sTimebaseInfo.denom == 0 ) {
        (void) mach_timebase_info(&sTimebaseInfo);
    }
    
    NSURL *nsurl = (__bridge NSURL *)(url);
    LrPrevImageData *lrPrev = [[LrPrevImageData alloc] initWithLrCatPath:nsurl.path];
    
    uint64_t t0 = mach_absolute_time();
    
    
    if([@"com.capturemonkey.lightroom.lrcat" isEqualToString:(__bridge NSString *)(contentTypeUTI)] )
    {
        // FIXME how to take current bundle without hardcoding, mainbundle is not ours?
        NSBundle *bundle = [NSBundle bundleWithIdentifier:@"com.capturemonkey.quicklook-lightroom"];
        //        NSLog(@"bundle", bundle);
        NSData *html = [NSData dataWithContentsOfFile:[bundle pathForResource:@"LrCat" ofType:@"html"]];
        
        if(!html)
        {
            NSLog(@"no html template");
            return noErr;
        }
        
        NSMutableData *htmlEdit = [html mutableCopy];
        
        NSMutableDictionary *props = [[NSMutableDictionary alloc] init];
        NSMutableDictionary *items = [[NSMutableDictionary alloc] init];
        [props setObject:items forKey:(NSString *)kQLPreviewPropertyAttachmentsKey];
        
        [htmlEdit appendData:[@"<script>" dataUsingEncoding:NSUTF8StringEncoding]];
        
        int rows=0;
        
        sqlite3 *db=0;
        sqlite3_stmt *statement=0;
        
        //        NSLog(@"nsurl.path %@", nsurl.path);
        NSLog(@"open previews.db %@", lrPrev.lrPreviewsDbPath);
        int err = sqlite3_open_v2([lrPrev.lrPreviewsDbPath UTF8String], &db, SQLITE_OPEN_READONLY, 0);
        if(err==SQLITE_OK)
        {
            //            NSLog(@"prepare statement");
            err = sqlite3_prepare_v2(db, SQL_PREVIEWS, -1, &statement, 0);
        }
        else
        {
         	// previews.db did not open, use alternative method
            NSLog(@"open lrcat %@",lrPrev.catalogPath);
            int err = sqlite3_open_v2([lrPrev.catalogPath UTF8String], &db, SQLITE_OPEN_READONLY, 0);
            if(err==SQLITE_OK)
            {
                //                NSLog(@"prepare statement");
                err = sqlite3_prepare_v2(db, SQL_LRCAT_PREVIEW, -1, &statement, 0);
                //                NSLog(@"prepare statement %d %x", err, statement);
                
                if(err!=SQLITE_OK)
                {
                    NSLog(@"Error with statement %d", err);
                    sqlite3_close(db);
                    return noErr;
                }
                
            }
            else
            {
                NSLog(@"Error while opening lrcat db: %d", err);
                return noErr;
            }
        }
        
        
        int stepResult = sqlite3_step(statement);
        while (stepResult == SQLITE_ROW)
        {
            NSString *uuid = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
            NSString *digest = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, 1)];
            NSString *orientation = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, 2)];
            //            NSLog(@"stepResult %d - %@ %@ %@", stepResult, uuid, digest, orientation);
            
            NSURL *thumbUrl = [NSURL fileURLWithPath:[lrPrev previewUuid:uuid digest:digest]];
            
            
            NSData *imageData = [LrPrevImageData imageDataFromLrPrevMaxLevel:thumbUrl maxlevel:1];
            if(imageData)
            {
        	    NSMutableDictionary *item = [[NSMutableDictionary alloc] init];
	            [item setObject:@"image/jpeg" forKey:(NSString *)kQLPreviewPropertyMIMETypeKey];
	            [item setObject:imageData forKey:(NSString *)kQLPreviewPropertyAttachmentDataKey];
                
                NSString *tag = [NSString stringWithFormat:@"%d", rows];
                //                NSLog(@"tag %@ %@",tag,orientation);
                
                [items setObject:item forKey:tag];
                rows++;
                
                NSData *callData = [[NSString stringWithFormat:@"addThumb('%@', '%@');", uuid, orientation] dataUsingEncoding:NSUTF8StringEncoding];
                [htmlEdit appendData:callData];
                
            }
            
            // allow running max 950ms, osx cuts off at 1 sec
            uint64_t dt = mach_absolute_time()-t0;
            uint64_t elapsedNano = dt * sTimebaseInfo.numer / sTimebaseInfo.denom;
            //            NSLog(@"elapsedNano %ld", elapsedNano);
        	if(elapsedNano>950000000)
            {
                NSLog(@"timeout");
                break;
            }
            
            
            stepResult = sqlite3_step(statement);
        }
        sqlite3_finalize(statement);
        
        sqlite3_close(db);
        
        [htmlEdit appendData:[@"</script>" dataUsingEncoding:NSUTF8StringEncoding]];
        
        NSLog(@"rows %d",rows);
        if(rows==0)
        {
            NSLog(@"no rows, bailing out before setting preview");
        	return noErr;
        }
        
        QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)htmlEdit,
                                              kUTTypeHTML,
                                              (__bridge CFDictionaryRef)(props));
        
        
        return noErr;
    }
    
    // TODO lrdata is not working, how to setup Info.plist?
    if([@"com.capturemonkey.lightroom.lrdata" isEqualToString:(__bridge NSString *)(contentTypeUTI)] )
    {
        return noErr;
    }
    
    // lrprev file
    NSData *data = [LrPrevImageData imageDataFromLrPrevMaxLevel:nsurl maxlevel:255];
    QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)(data), kUTTypeImage, nil);
    
    return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
    // Implement only if supported
}
