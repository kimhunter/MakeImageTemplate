//
//  main.swift
//  swiftMakeImageTemplate
//
//  Created by Kim Hunter on 12/07/2014.
//  Copyright (c) 2014 Kim Hunter. All rights reserved.
//

import Foundation
import Cocoa

struct ColorComponents {
    var red: UInt8 = 0
    var green: UInt8 = 0
    var blue: UInt8 = 0
    
    init()
    {
        self.init()
    }
    
    init(r: UInt8, g: UInt8, b: UInt8)
    {
        red = r
        green = g
        blue = b
    }
    
    init(hex: String)
    {
        self.init(r: 3, g: 4, b: 5)
    }
}

func colorComponentsFromString(hexString: String) -> ColorComponents
{
    var components = ColorComponents()
    let hexLength = hexString.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
    
    
    var scanner = NSScanner.scannerWithString(hexString)
    var hexValue : UInt32 = 0;
    if (hexLength == 3 || hexLength == 6)
    {
        if (scanner.scanHexInt(&hexValue))
        {
            var mask : UInt32 = 0xFF;
            var bitPerComponent : UInt32 = 8;
            if (hexLength == 3)
            {
                bitPerComponent = 4;
                mask = 0xF;
            }
            components.red   = UInt8((hexValue >> (bitPerComponent * 2)) & mask);
            components.green = UInt8((hexValue >> (bitPerComponent * 1)) & mask);
            components.blue  = UInt8((hexValue >> (bitPerComponent * 0)) & mask);
            if (hexLength == 3)
            {
                let shift = UInt8(bitPerComponent)
                components.red   |= (components.red   << shift);
                components.green |= (components.green << shift);
                components.blue  |= (components.blue  << shift);
            }
        }
    }
    return components;
}

func convertImageToColoredTemplate(srcPath: String, destPath: String, fillColor: ColorComponents) -> Bool
{
    var imageRep:NSBitmapImageRep = NSBitmapImageRep(data: NSData.dataWithContentsOfFile(srcPath, options: .UncachedRead, error: nil))
    let totalPixels = imageRep.pixelsHigh * imageRep.pixelsWide
    let pixelBits = imageRep.bitsPerPixel
    let pixelByteSize = pixelBits / imageRep.bitsPerSample
    if (!(pixelByteSize == 4 && pixelBits == 32)) {
        println("can only handle 4 byte pixels and 32 bits per pixel, \(srcPath) = {pixelByteSize=\(pixelByteSize), pixelBits=\(pixelBits)} ")
        return false;
    }
    
    var bitmapData = imageRep.bitmapData
    
    for _ in 0..<totalPixels {
        if bitmapData[3] != 0 {
            bitmapData[0] = fillColor.red
            bitmapData[1] = fillColor.green
            bitmapData[2] = fillColor.blue
        }
        bitmapData += pixelByteSize
    }
    
    if let imageData = imageRep.representationUsingType(.NSPNGFileType, properties: [NSImageGamma : 0]) {
        return imageData.writeToFile(destPath, atomically: true)
    }
    return false
}

let fm = NSFileManager.defaultManager()
let pngFilePaths = Process.arguments.filter {$0.pathExtension.lowercaseString == "png" && fm.fileExistsAtPath($0)}
let paintColor = ColorComponents()
var failedConversions = Int64(pngFilePaths.count)
for pngPath in pngFilePaths
{
    let basePath = pngPath.stringByDeletingPathExtension
    let destPath = basePath.stringByAppendingString(".template").stringByAppendingPathExtension(pngPath.pathExtension)
    if (convertImageToColoredTemplate(pngPath, destPath, paintColor))
    {
        OSAtomicDecrement64(&failedConversions);
    }
}


exit(failedConversions == 0 ? 0 : 1)
