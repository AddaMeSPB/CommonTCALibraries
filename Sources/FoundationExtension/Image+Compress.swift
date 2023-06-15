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

extension UIImage {

    private var isHeicSupported: Bool {
        // swiftlint:disable force_cast
        (CGImageDestinationCopyTypeIdentifiers() as! [String]).contains("public.heic")
    }

    /**
     Compresses an image to JPEG or PNG format.

     - Parameter compressionQuality: The quality of the compressed image.
     - Parameter imageType: The desired output image type.
     - Returns: A tuple containing the compressed image data and its file extension, or throws an error if compression fails.
     */
    public func compressImage(compressionQuality: CompressionQuality, imageType: ImageType) throws -> (Data, String) {

        let heicData = try heic(compressionQuality: compressionQuality)

        if isHeicSupported {
            return (heicData, "heic")
        } else {
            guard let jpegData = jpegData(compressionQuality: compressionQuality.rawValue) else {
                throw ImageCompressionError.compressionFailed
            }

            switch imageType {
            case .jpeg:
                return (jpegData, imageType.rawValue)

            case .png:
                guard let image = UIImage(data: jpegData) else {
                    throw ImageCompressionError.invalidImageData
                }

                if let pngData = image.pngData() {
                    return (pngData, imageType.rawValue)
                } else {
                    throw ImageCompressionError.compressionFailed
                }
            }
        }
    }



}

extension UIImage {
    public enum HEICError: Error {
        case heicNotSupported
        case cgImageMissing
        case couldNotFinalize
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
            [kCGImageDestinationLossyCompressionQuality: compressionQuality.rawValue, kCGImagePropertyOrientation: cgImageOrientation.rawValue] as CFDictionary
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
