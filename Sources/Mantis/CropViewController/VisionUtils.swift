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

enum CRPVisionError: Error, LocalizedError {
    case failedToEncodeImage
    case noBackgroundDetected
    case failedToSegmentedBackground
    case noPeopleDetected
    case tooManyPeopleDetected
    case failedToRemoveBackground
    case failedToGenerateForegroundImage1
    case failedToGenerateForegroundImage2
    
    var errorDescription: String? {
        switch self {
        case .failedToEncodeImage:
            return "Failed to load the image. Please try again later."
        case .noBackgroundDetected:
            return "No foreground content detected in the image."
        case .failedToSegmentedBackground:
            return "No background content detected in the image."
        case .noPeopleDetected:
            return "No people detected in the image."
        case .tooManyPeopleDetected:
            return "More than one person detected in the image."
        case .failedToRemoveBackground:
            return "Internal Failure(1)"
        case .failedToGenerateForegroundImage1:
            return "Internal Failure(2)"
        case .failedToGenerateForegroundImage2:
            return "Internal Failure(3)"
        }
    }
}

func CRPExtractForegroundImage(sourceImage: UIImage, targetSize: CGSize?) async throws -> UIImage {
    let inputImage = try sourceImage.toCIImage()
    
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(ciImage: inputImage)
    
    try handler.perform([request])
    
    guard let result = request.results?.first else {
        throw CRPVisionError.noBackgroundDetected
    }
    
    let instances = result.allInstances
    guard let maskBuffer = try? result.generateScaledMaskForImage(forInstances: instances, from: handler) else {
        throw CRPVisionError.failedToRemoveBackground
    }
    
    let image = try inputImage.applyMaskBuffer(maskBuffer)
    return try await CRPTrimTransparentPixelsInImage(sourceImage: image, targetSize: targetSize)
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

func CRPCropPersonInImage(sourceImage: UIImage, targetSize: CGSize?) async throws -> UIImage {
    try autoreleasepool {
        let inputImage = try sourceImage.toCIImage()
        
        var segmentationRequest = VNGeneratePersonSegmentationRequest()
        segmentationRequest.qualityLevel = .accurate
        
        var faceRequest = VNDetectFaceRectanglesRequest()
        faceRequest.revision = VNDetectFaceRectanglesRequestRevision3
        
        let handler = VNImageRequestHandler(ciImage: inputImage)
        try handler.perform([segmentationRequest, faceRequest])
        
        let faceResults = faceRequest.results ?? []
        if faceResults.count == 0 {
            throw CRPVisionError.noPeopleDetected
        }
        if faceResults.count > 1 {
            throw CRPVisionError.tooManyPeopleDetected
        }
        guard let result = segmentationRequest.results?.first else {
            throw CRPVisionError.failedToSegmentedBackground
        }
        
        var image = try inputImage.applyMaskBuffer(result.pixelBuffer)
            
        image = image.cropAlpha()
        return image
    }
}

extension CIImage {
    func applyMaskBuffer(_ buffer: CVPixelBuffer) throws -> UIImage {
        let maskImage = CIImage(cvPixelBuffer: buffer)
        
        let maskScaleX = self.extent.width / maskImage.extent.width
        let maskScaleY = self.extent.height / maskImage.extent.height
        let maskScaled = maskImage.transformed(by: CGAffineTransform(maskScaleX, 0, 0, maskScaleY, 0, 0))
        
        let blendWithMaskFilter = CIFilter.blendWithMask()
        blendWithMaskFilter.inputImage = self
        blendWithMaskFilter.backgroundImage = CIImage(color: .clear)
        blendWithMaskFilter.maskImage = maskScaled
        guard let foregroundResult = blendWithMaskFilter.outputImage else {
            throw CRPVisionError.failedToGenerateForegroundImage1
        }
        
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(foregroundResult,
                                                  from: CGRect(origin: .zero, size: self.extent.size)) else {
            throw CRPVisionError.failedToGenerateForegroundImage2
        }

        let result = UIImage(cgImage: cgImage)
        return result
    }
}

extension UIImage {
    func toCIImage() throws -> CIImage {
        let orientation = CGImagePropertyOrientation(self.imageOrientation).rawValue
        guard let inputImage = CIImage(image: self,
                                       options: [.applyOrientationProperty: true,
                                                 .properties: [kCGImagePropertyOrientation: orientation]]) else {
            throw CRPVisionError.failedToEncodeImage
        }
        return inputImage
    }
    
    func cropAlpha() -> UIImage {
        let cgImage = self.cgImage!
        
        let width = cgImage.width
        let height = cgImage.height
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel: Int = 4
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
    
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(self.size.width), Int(self.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard status == kCVReturnSuccess else {
            return nil
        }
        
        if let pixelBuffer = pixelBuffer {
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
            
            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
            let context = CGContext(data: pixelData, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
            
            context?.translateBy(x: 0, y: self.size.height)
            context?.scaleBy(x: 1.0, y: -1.0)
            
            UIGraphicsPushContext(context!)
            self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
            UIGraphicsPopContext()
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            
            return pixelBuffer
        }
        
        return nil
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
