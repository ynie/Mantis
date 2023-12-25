//
//  VisionUtils.swift
//
//
//  Created by Steven Nie on 12/25/23.
//

import Foundation
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

func CRPExtractForegroundImage(sourceImage: UIImage) async throws -> UIImage {
    enum RemoveBackgroundError: Error, LocalizedError {
        case failedToEncodeImage
        case noBackgroundDetected
        case failedToRemoveBackground
        case failedToGenerateForegroundImage1
        case failedToGenerateForegroundImage2
    }
    let orientation = CGImagePropertyOrientation(sourceImage.imageOrientation).rawValue
    guard let inputImage = CIImage(image: sourceImage,
                                   options: [.applyOrientationProperty: true,
                                             .properties: [kCGImagePropertyOrientation: orientation]]) else {
        throw RemoveBackgroundError.failedToEncodeImage
    }
    
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(ciImage: inputImage)
    
    try handler.perform([request])
    
    guard let result = request.results?.first else {
        throw RemoveBackgroundError.noBackgroundDetected
    }
    
    let instances = result.allInstances
    guard let maskBuffer = try? result.generateScaledMaskForImage(forInstances: instances, from: handler) else {
        throw RemoveBackgroundError.failedToRemoveBackground
    }
    
    let maskImage = CIImage(cvPixelBuffer: maskBuffer)
    
    let blendWithMaskFilter = CIFilter.blendWithMask()
    blendWithMaskFilter.inputImage = inputImage
    blendWithMaskFilter.backgroundImage = CIImage(color: .clear)
    blendWithMaskFilter.maskImage = maskImage
    guard let foregroundResult = blendWithMaskFilter.outputImage else {
        throw RemoveBackgroundError.failedToGenerateForegroundImage1
    }
    
    let context = CIContext(options: nil)
    guard let cgImage = context.createCGImage(foregroundResult,
                                              from: CGRect(origin: .zero, size: inputImage.extent.size)) else {
        throw RemoveBackgroundError.failedToGenerateForegroundImage2
    }

    let foregroundImage = UIImage(cgImage: cgImage)
    return foregroundImage
}

func CRPTrimTransparentPixelsInImage(sourceImage: UIImage, targetSize: CGSize?) async throws -> UIImage {
    var croppedImage = sourceImage.cropAlpha()
    if let targetSize = targetSize {
        let croppedImageSize = croppedImage.size
        var canvasSize: CGSize = .zero
        if croppedImageSize.width < croppedImageSize.height {
            canvasSize.height = croppedImageSize.height
            canvasSize.width = targetSize.width * croppedImageSize.height / targetSize.height
        } else {
            canvasSize.width = croppedImageSize.width
            canvasSize.height = targetSize.height * croppedImageSize.width / targetSize.width
        }
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        if let format = renderer.format as? UIGraphicsImageRendererFormat {
            format.scale = 1.0
        }
        return renderer.image { context in
            croppedImage.draw(in: CGRect(x: (canvasSize.width - croppedImage.size.width) / 2.0,
                                         y: (canvasSize.height - croppedImage.size.height) / 2.0,
                                         width: croppedImage.size.width,
                                         height: croppedImage.size.height))
        }
    } else {
        return croppedImage
    }
}

extension UIImage {
    func cropAlpha() -> UIImage {
        let cgImage = self.cgImage!
        
        let width = cgImage.width
        let height = cgImage.height
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel:Int = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo),
              let ptr = context.data?.assumingMemoryBound(to: UInt8.self) else {
            return self
        }
        
        context.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var minX = width
        var minY = height
        var maxX: Int = 0
        var maxY: Int = 0
        
        for x in 1 ..< width {
            for y in 1 ..< height {
                
                let i = bytesPerRow * Int(y) + bytesPerPixel * Int(x)
                let a = CGFloat(ptr[i + 3]) / 255.0
                
                if(a>0) {
                    if (x < minX) { minX = x }
                    if (x > maxX) { maxX = x }
                    if (y < minY) { minY = y}
                    if (y > maxY) { maxY = y}
                }
            }
        }
        
        let rect = CGRect(x: CGFloat(minX),y: CGFloat(minY), width: CGFloat(maxX-minX), height: CGFloat(maxY-minY))
        let imageScale:CGFloat = self.scale
        let croppedImage =  self.cgImage!.cropping(to: rect)!
        let ret = UIImage(cgImage: croppedImage, scale: imageScale, orientation: self.imageOrientation)
        return ret
    }
}

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
            case .up: self = .up
            case .upMirrored: self = .upMirrored
            case .down: self = .down
            case .downMirrored: self = .downMirrored
            case .left: self = .left
            case .leftMirrored: self = .leftMirrored
            case .right: self = .right
            case .rightMirrored: self = .rightMirrored
        }
    }
}
