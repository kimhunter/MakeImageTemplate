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
        var hexValue: UInt32 = 0
        let hexLength = countElements(hex)
        var scanner = NSScanner.scannerWithString(hex)

        let validLenghts = [1,2,3,6]
        if contains(validLenghts, hexLength) && scanner.scanHexInt(&hexValue)
        {
            hexValue = expandComponentValues(hexValue, hexLength: UInt32(hexLength))
            red = UInt8((value >> 16) & 0xFF)
            green = UInt8((value >> 8) & 0xFF)
            blue = UInt8(value & 0xFF)
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
            return (value | (value << 4))
        }
        
        var resValue = value & 0xFF_FF_FF
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
    if (!(pixelByteSize == 4 && pixelBits == 32))
    {
        println("can only handle 4 byte pixels and 32 bits per pixel, \(srcPath) = {pixelByteSize=\(pixelByteSize), pixelBits=\(pixelBits)} ")
        return false
    }
    
    var bitmapData = imageRep.bitmapData
    
    for _ in 0..<totalPixels
    {
        if bitmapData[3] != 0
        {
            bitmapData[0] = fillColor.red
            bitmapData[1] = fillColor.green
            bitmapData[2] = fillColor.blue
        }
        bitmapData += pixelByteSize
    }
    
    if let imageData = imageRep.representationUsingType(.NSPNGFileType, properties: [NSImageGamma : 0])
    {
        return imageData.writeToFile(destPath, atomically: true)
    }
    return false
}

func paintColorFromArguments() -> ColorComponents
{
    if let hexString = NSUserDefaults.standardUserDefaults().stringForKey("Hex")
    {
        // a good string will be trimmed to nothing
        let hasBadChars = countElements(hexString.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "0123456789ABCDEFabcdef"))) == 0
        if hasBadChars
        {
            return ColorComponents(hex: hexString)
        }
    }
    return ColorComponents()
}

let args = Process.arguments
let fileMan = NSFileManager.defaultManager()

// Parse params
let pngFilePaths = Process.arguments.filter { $0.pathExtension.lowercaseString == "png" && fileMan.fileExistsAtPath($0) }
let overwrite = contains(Process.arguments, "-overwrite")
let paintColor = paintColorFromArguments()


var failedConversions = Int64(pngFilePaths.count)
for pngPath in pngFilePaths
{
    let destPath = overwrite ? pngPath : pngPath.stringByDeletingPathExtension.stringByAppendingString(".template").stringByAppendingPathExtension(pngPath.pathExtension)
    
    if (convertImageToColoredTemplate(pngPath, destPath, paintColor))
    {
        OSAtomicDecrement64(&failedConversions)
    }
}


exit(failedConversions == 0 ? 0 : 1)
