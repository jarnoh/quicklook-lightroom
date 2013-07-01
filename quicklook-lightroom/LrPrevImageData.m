//
//  quicklook-lightroom
//
//  Created by Jarno Heikkinen on 6/29/13.
//  Copyright (c) 2013 Jarno Heikkinen. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "LrPrevImageData.h"


const int AGHG_HEADER_MAGIC = 0x41674867;
const int AGHG_HEADER_LEN = 32;

#define AGHG_PAD(x) (((x)+15)&~15)

@interface LrPrevImageData()
{
    NSString *lrcat;
}
@end


@implementation LrPrevImageData

-(NSString*)catalogPath
{
    return lrcat;
}

-(id)initWithLrCatPath:(NSString*)path
{
    self = [super init];
    if(self)
    {
        lrcat = path;
    }
    return self;
}


+(NSData*) imageDataFromLrPrevMaxLevel:(NSURL*)url maxlevel:(NSUInteger)maxlevel
{
//    NSLog(@"imageDataFromLrPrevMaxLevel %@ %d", url, (int)maxlevel);
    NSData *data=[[NSData alloc] initWithContentsOfURL:url options:NSDataReadingMappedAlways error:nil];
    if(!data) return 0;
    
    const int *p = (const int *)[data bytes];
    
    if(*p!=htonl(AGHG_HEADER_MAGIC))
    {
        NSLog(@"No AgHg found.");
        return 0;
    }
    
    int headerLen = htonl(p[3]);
//    NSLog(@"header %x", headerLen);
    
    int thumbOffset = AGHG_HEADER_LEN+AGHG_PAD(headerLen);
    int thumbLen=0;
    
//    int level=0;
    while(1)
    {
//        NSLog(@"level %x", level++);
        thumbLen = htonl(p[3+thumbOffset/4]);
//        NSLog(@"thumbOffset %x", thumbOffset);
//        NSLog(@"thumbLen %x", thumbLen);
        
        // see if there is more room in the file
        int nextPayload =  thumbOffset+thumbLen+AGHG_HEADER_LEN*2;
        
//        NSLog(@"computed %x data len %x", nextPayload, (int) [data length]);
        
        if(maxlevel--<=0 || nextPayload >= [data length])
        {
//            NSLog(@"bailout");
            break;
        }
        
        thumbOffset += AGHG_HEADER_LEN+AGHG_PAD(thumbLen);
        
    };
    
    
    NSRange range = {thumbOffset+AGHG_HEADER_LEN, thumbLen};
    NSData *data2 = [data subdataWithRange:range];
    
    return data2;
}



-(NSString*)lrPreviewsPath
{
    NSRange ext;
    ext.length=6; // ".lrcat"
    ext.location=lrcat.length-6;
    
	return [lrcat stringByReplacingCharactersInRange:ext withString:@" Previews.lrdata"];

}

-(NSString*)lrPreviewsDbPath
{
    return [self.lrPreviewsPath stringByAppendingPathComponent:@"previews.db"];
}


-(NSString*)previewUuid:(NSString*)guid digest:(NSString*)digest
{
    NSRange firstDigit = { 0, 1};
    NSRange firstWord = { 0, 4};
    NSString *path = [NSString stringWithFormat:@"%@/%@/%@/%@-%@.lrprev", self.lrPreviewsPath, [guid substringWithRange:firstDigit], [guid substringWithRange:firstWord], guid, digest ];
    return path;
}


@end

