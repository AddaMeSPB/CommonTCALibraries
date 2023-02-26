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

extension UIImage {
  public enum JPEGQuality: CGFloat {
    case lowest = 0
    case low = 0.25
    case medium = 0.5
    case high = 0.75
    case highest = 1
  }

  private var isHeicSupported: Bool {
    // swiftlint:disable force_cast
      (CGImageDestinationCopyTypeIdentifiers() as! [String]).contains("public.heic")
  }

  public func compressImage(_ compressionQuality: JPEGQuality = .medium) -> (Data?, String) {

      if isHeicSupported, let heicData = heic(compressionQuality: compressionQuality) {
          // write your heic image data to disk
          return (heicData, "heic")
      } else {
          #if os(iOS)
            guard let data = jpegData(compressionQuality: compressionQuality.rawValue) else {
              return (nil, "")
            }

            return (data, "jpeg")

          #elseif os(OSX)
            fatalError("Value of type 'NSImage' has no member 'jpegData'")
          #endif
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

    func heic(compressionQuality: JPEGQuality) -> Data? {
        // AVFileType.heic == "public.heic"
        guard
            let mutableData = CFDataCreateMutable(nil, 0),
            let destination = CGImageDestinationCreateWithData(mutableData, "public.heic" as CFString, 1, nil),
            let cgImage = cgImage
        else {
            logger.debug("heic compressionQuality mutableData, destination or cgImage nil")
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: compressionQuality, kCGImagePropertyOrientation: cgImageOrientation.rawValue] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            logger.debug("CGImageDestinationFinalize nil")
            return nil
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
