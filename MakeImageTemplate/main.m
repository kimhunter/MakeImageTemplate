//
//    MakeImageTemplate
//    Turn those badly coloured template images into a normalized color
//
//
//    This program is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//  Created by Kim Hunter on 9/07/2014.
//  Copyright (c) 2014 Kim Hunter. All rights reserved.
//
//  # Compile with:
//  $ clang -o MakeImageTemplate -O3 -framework Foundation -framework Cocoa MakeImageTemplate.m
//
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <libkern/OSAtomic.h>

BOOL convertImageToColoredTemplate(NSString *srcPath, NSString *destPath, UInt8 r, UInt8 g, UInt8 b);

int main(int argc, const char * argv[]) {
    
    __block volatile int64_t failedConversions = 0;
    
    @autoreleasepool {
        
        NSArray *args = [[NSProcessInfo processInfo] arguments];
        
        // take only png files that exist
        NSArray *pngFiles = [args filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *maybePath, NSDictionary *bindings) {
            return [[[maybePath pathExtension] lowercaseString] hasSuffix:@"png"]
            && [[NSFileManager defaultManager] fileExistsAtPath:maybePath];
        }]];
        
        // dec each success which will leave us with the failings
        failedConversions = [pngFiles count];
        
        NSEnumerationOptions enumOptions = ([pngFiles count] > 2) ? NSEnumerationConcurrent : 0;
        [pngFiles enumerateObjectsWithOptions:enumOptions usingBlock:^(NSString *pngPath, NSUInteger idx, BOOL *stop) {
            NSString *basePath = [pngPath stringByDeletingPathExtension];
            NSString *destPath = [[basePath stringByAppendingString:@".template"] stringByAppendingPathExtension:[pngPath pathExtension]];
            if (convertImageToColoredTemplate(pngPath, destPath, 0, 0, 0))
            {
                OSAtomicDecrement64(&failedConversions);
            }
        }];
    }
    return (failedConversions == 0) ? 0 : 1;
}

#define RedPixel   0
#define GreenPixel 1
#define BluePixel  2
#define AlphaPixel 3

#define PixelIsNotTotalyTransparent(P) ((P)[AlphaPixel] != 0x00)
BOOL convertImageToColoredTemplate(NSString *srcPath, NSString *destPath, UInt8 r, UInt8 g, UInt8 b)
{
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithData:[[NSData alloc] initWithContentsOfFile:srcPath]];
    
    if (imageRep)
    {
        NSInteger totalPixels = imageRep.pixelsHigh * imageRep.pixelsWide;
        NSInteger pixelBits = imageRep.bitsPerPixel;
        NSInteger pixelByteSize = pixelBits / imageRep.bitsPerSample;
        
        if (!(pixelByteSize == 4 && pixelBits == 32))
        {
            NSLog(@"can only handle 4 byte pixels and 32 bits per pixel, %@ = {pixelByteSize=%ld, pixelBits=%ld} ",srcPath, (long)pixelByteSize, (long)pixelBits);
            return NO;
        }
        
        UInt8 *pixel = [imageRep bitmapData];
        for (NSInteger i = 0; i < totalPixels; ++i)
        {
            // we want to paint any pixel that isn't totally transparent
            if (PixelIsNotTotalyTransparent(pixel))
            {
                pixel[RedPixel]   = r;
                pixel[GreenPixel] = g;
                pixel[BluePixel]  = b;
            }
            pixel += pixelByteSize;
        }
        
        NSData *imageData = [imageRep representationUsingType:NSPNGFileType properties:@{ NSImageGamma : @0 }];
        return [imageData writeToFile:destPath atomically:YES];
    }
    
    return NO;
}
