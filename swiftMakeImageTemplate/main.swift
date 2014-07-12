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
    
    init() { self.init(r:0,g:0,b:0) }
    init(r: UInt8, g: UInt8, b: UInt8) { red = r; green = g; blue = b }
    init(white: UInt8) { self.init(r: white, g: white, b: white) }
    
    init(hex: String)
    {
        func hexByteValueAtOffset(value: UInt32, offset: UInt32) -> UInt8
        {
            let offset32 = UInt32(8 * offset)
            return UInt8((value >> offset32) & 0xFF)
        }
        
        let hexLength = hex.lengthOfBytesUsingEncoding(NSASCIIStringEncoding)
        var scanner = NSScanner.scannerWithString(hex)
        var hexValue: UInt32 = 0;
        
        if scanner.scanHexInt(&hexValue)
        {
            var len = UInt32(hexLength)
            hexValue = expandComponentValues(hexValue, hexLength: len)
            red = hexByteValueAtOffset(hexValue, 2)
            green = hexByteValueAtOffset(hexValue, 1)
            blue = hexByteValueAtOffset(hexValue, 0)
        }
    }
    // expand shorthand hex colors
    // colours: 0F0 -> 00FF00 
    // b&w: 0F -> 0F0F0F ; E -> EEEEEE
    func expandComponentValues(value: UInt32, hexLength:UInt32) -> UInt32
    {
        func expandedHalfByte(value: UInt32, offset: UInt32) -> UInt32
        {
            let value = (value >> (4 * offset)) & 0xF
            return (value | (value << 4));
        }
        
        var resValue = value & 0xFFFFFF;
        var length = hexLength
        
        switch length {
        case 1:
            resValue = expandedHalfByte(resValue, 0)
            fallthrough
        case 2:
            resValue |= resValue << 8 | resValue << 16
        case 3:
            resValue = (0..<3).map{ expandedHalfByte(resValue, $0) << ($0 * 8) }.reduce(0){ $0 | $1 }
        case 6:
            return resValue
        default:
            resValue = 0
        }
        return resValue
    }

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

func paintColorFromArguments() -> ColorComponents
{
    if let hexString = NSUserDefaults.standardUserDefaults().stringForKey("Hex")
    {
        return ColorComponents(hex: NSUserDefaults.standardUserDefaults().stringForKey("Hex"))
    }
    return ColorComponents();
}

let args = Process.arguments
let fm = NSFileManager.defaultManager()

// Parse params
let pngFilePaths = Process.arguments.filter {$0.pathExtension.lowercaseString == "png" && fm.fileExistsAtPath($0)}
let overwrite = contains(Process.arguments, "-overwrite")
var paintColor = paintColorFromArguments()


var failedConversions = Int64(pngFilePaths.count)
for pngPath in pngFilePaths
{
    let destPath = overwrite ? pngPath : pngPath.stringByDeletingPathExtension.stringByAppendingString(".template").stringByAppendingPathExtension(pngPath.pathExtension)
    
    if (convertImageToColoredTemplate(pngPath, destPath, paintColor))
    {
        OSAtomicDecrement64(&failedConversions);
    }
}


exit(failedConversions == 0 ? 0 : 1)
