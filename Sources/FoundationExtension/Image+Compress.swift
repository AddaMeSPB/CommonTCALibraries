//
//  Image+Compress.swift
//  AddaMeIOS
//
//  Created by Saroar Khandoker on 19.11.2020.
//

import AVFoundation
import SwiftUI
import os.log

/// if isHeicSupported, let heicData = image.heic {
///     // write your heic image data to disk
/// }
/// or adding compression to your image:
///
/// if isHeicSupported, let heicData = image.heic(compressionQuality: 0.75) {
///     // write your compressed heic image data to disk
/// }

#if os(iOS)
import UIKit
#elseif os(OSX)
import AppKit
import Cocoa

typealias UIImage = NSImage
extension NSImage {
    var cgImage: CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)

        return cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil)
    }

    convenience init?(named name: String) {
        self.init(named: Name(name))
    }
}

#endif

enum ImageCompressionError: Error {
    case compressionFailed
    case invalidImageData
}

public enum CompressionQuality: CGFloat {
    case lowest = 0
    case low = 0.25
    case medium = 0.5
    case high = 0.75
    case highest = 1
}

public enum ImageType: String {
    case jpeg, png
}

/**
 icon

 29x29
 58x58 (@2x)
 Appears in the mail app, and in notifications about the pass, but not on the pass itself
 This image is mandatory, the package will not open without it
 logo

 30x30 to 300x30
 60x60 to 600x60 (@2x)
 strip

 StoreCard - 310 x 123 or 620 x 246 (@2x)
 EventTicket - 310 x 84 or 620 x 168 (@2x)
 Will be center-cropped if it is too high
 thumbnail

 up to 80x90
 up to 160x180 (@2x)
 will be downscaled if too big, will not be upscaled if smaller than the max dimensions. So an 80x80 icon will appear as 80x80.
 background

 312x398
 624x796 (@2x)
 This appears blurred behind the pass.
 I'm not 100% sure about these dimensions, its hard to tell because of the blurring, but they seem to work.
 */
public enum PassImagesType: String {
    case icon, logo, strip, thumbnail
}

extension UIImage {

    private var isHeicSupported: Bool {
        // swiftlint:disable force_cast
        (CGImageDestinationCopyTypeIdentifiers() as! [String]).contains("public.heic")
    }

    private func heicToPng(
        heicData: Data,
        passImagesType: PassImagesType
    ) throws -> Data {
        guard
            let image = UIImage(data: heicData),
            let resizeImage = image.resizeImage(passImagesType: passImagesType)
        else {
            throw HEICError.invalidHEICData
        }

        guard let pngData = resizeImage.pngData() else {
            throw HEICError.couldNotConvertToPNG
        }

        return pngData
    }

    /**
     Compresses an image to JPEG or PNG format.

     - Parameter compressionQuality: The quality of the compressed image.
     - Parameter imageType: The desired output image type.
     - Returns: A tuple containing the compressed image data and its file extension, or throws an error if compression fails.
     */
    public func compressImage(
        compressionQuality: CompressionQuality,
        imageType: ImageType,
        passImagesType: PassImagesType
    ) throws -> (Data, String) {

        let heicData = try heic(compressionQuality: compressionQuality)

        if isHeicSupported {
            if imageType == .png {
                do {
                    let pngData = try heicToPng(heicData: heicData, passImagesType: passImagesType)
                    return (pngData, imageType.rawValue)
                } catch {
                    print("Error converting HEIC to PNG: \(error)")
                    throw HEICError.couldNotConvertToPNG
                }
            }

            return (heicData, "heic")
            
        } else {
            guard let jpegData = jpegData(compressionQuality: compressionQuality.rawValue) else {
                throw ImageCompressionError.compressionFailed
            }

            switch imageType {
            case .jpeg:
                return (jpegData, imageType.rawValue)

            case .png:
                guard
                    let image = UIImage(data: jpegData),
                    let resizeImage = image.resizeImage(passImagesType: passImagesType)
                else {
                    throw ImageCompressionError.invalidImageData
                }

                if let pngData = resizeImage.pngData() {
                    return (pngData, imageType.rawValue)
                } else {
                    throw ImageCompressionError.compressionFailed
                }
            }
        }
    }

}
extension UIImage {
    private func calculateSize(from passImagesType: PassImagesType) -> CGSize {
        switch passImagesType {
        case .icon:
            return CGSize(width: 29, height: 29)
        case .logo:
            return CGSize(width: 30, height: 30)
        case .strip:
            return CGSize(width: 310, height: 123) // StoreCard
        case .thumbnail:
            return CGSize(width: 80, height: 90)
        }
    }

    public func resizeImage(passImagesType: PassImagesType) -> UIImage? {
        let size = self.size
        let targetSize =  calculateSize(from: passImagesType)

        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height

        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }

        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}

extension UIImage {
    public enum HEICError: Error {
        case heicNotSupported
        case cgImageMissing
        case couldNotFinalize
        case invalidHEICData
        case couldNotConvertToPNG
    }
}

extension UIImage {

    /**
     Compresses the image to HEIC format.

     - Parameter compressionQuality: The quality of the compressed image.
     - Returns: The compressed HEIC image data, or throws an error if compression fails.
     */
    private func heic(compressionQuality: CompressionQuality) throws -> Data {

        guard
            let mutableData = CFDataCreateMutable(nil, 0),
            let destination = CGImageDestinationCreateWithData(mutableData, "public.heic" as CFString, 1, nil),
            let cgImage = cgImage
        else {
            logger.debug("heic compressionQuality mutableData, destination or cgImage nil")
            throw HEICError.cgImageMissing
        }

        CGImageDestinationAddImage(
            destination,
            cgImage,
            [
                kCGImageDestinationLossyCompressionQuality: compressionQuality.rawValue,
                kCGImagePropertyOrientation: cgImageOrientation.rawValue
            ] as CFDictionary
        )

        guard
            CGImageDestinationFinalize(destination)
        else {
            logger.debug("CGImageDestinationFinalize nil")
            throw HEICError.couldNotFinalize
        }

        return mutableData as Data
    }

}

extension UIImage {
    var cgImageOrientation: CGImagePropertyOrientation { .init(imageOrientation) }
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
        @unknown default:
            logger.error("unknown default uiOrientation missing")
            fatalError()
        }
    }
}

fileprivate let logger = Logger(subsystem: "com.addame.AddaMeIOS", category: "Image+Compress")
