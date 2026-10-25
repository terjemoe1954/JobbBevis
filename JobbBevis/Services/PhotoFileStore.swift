import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

struct PhotoFileStore: Sendable {
    nonisolated static let maximumPixelDimension = 2_400
    nonisolated static let jpegQuality = 0.82

    func importImageData(_ sourceData: Data, jobID: UUID) async throws -> String {
        let processedData = try await Task.detached {
            try Self.processedJPEG(from: sourceData)
        }.value

        let directory = try photoDirectory(jobID: jobID)
        let fileName = "\(UUID().uuidString).jpg"
        let destination = directory.appending(path: fileName)
        try processedData.write(to: destination, options: .atomic)
        return "Photos/\(jobID.uuidString)/\(fileName)"
    }

    func thumbnailData(relativePath: String, maximumPixelSize: Int) async -> Data? {
        guard let url = try? fileURL(relativePath: relativePath) else { return nil }
        return await Task.detached {
            Self.downsampledJPEG(at: url, maximumPixelSize: maximumPixelSize)
        }.value
    }

    func data(relativePath: String) -> Data? {
        guard let url = try? fileURL(relativePath: relativePath) else { return nil }
        return try? Data(contentsOf: url)
    }

    func remove(relativePath: String) throws {
        let url = try fileURL(relativePath: relativePath)
        if FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func stageRemoval(relativePath: String) throws -> StagedPhotoRemoval {
        let originalURL = try fileURL(relativePath: relativePath)
        guard FileManager.default.fileExists(atPath: originalURL.path()) else {
            return StagedPhotoRemoval(originalURL: originalURL, stagedURL: nil)
        }
        let trashDirectory = try applicationDirectory()
            .appending(path: "PendingDeletion", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
        let stagedURL = trashDirectory.appending(path: "\(UUID().uuidString).jpg")
        try FileManager.default.moveItem(at: originalURL, to: stagedURL)
        return StagedPhotoRemoval(originalURL: originalURL, stagedURL: stagedURL)
    }

    func removeAll(for job: JobRecord) throws {
        for photo in job.photos {
            try remove(relativePath: photo.relativePath)
        }
        let directory = try applicationDirectory()
            .appending(path: "Photos", directoryHint: .isDirectory)
            .appending(path: job.id.uuidString, directoryHint: .isDirectory)
        if FileManager.default.fileExists(atPath: directory.path()) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    private func photoDirectory(jobID: UUID) throws -> URL {
        let directory = try applicationDirectory()
            .appending(path: "Photos", directoryHint: .isDirectory)
            .appending(path: jobID.uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func fileURL(relativePath: String) throws -> URL {
        try applicationDirectory().appending(path: relativePath)
    }

    private func applicationDirectory() throws -> URL {
        let supportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return supportURL.appending(path: "JobbBevis", directoryHint: .isDirectory)
    }

    nonisolated private static func processedJPEG(from data: Data) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw PhotoFileError.unreadableImage
        }

        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, CGFloat(maximumPixelDimension) / longestSide)
        let targetSize = CGSize(
            width: max(1, image.size.width * scale),
            height: max(1, image.size.height * scale)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let normalizedImage = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let jpeg = normalizedImage.jpegData(compressionQuality: jpegQuality) else {
            throw PhotoFileError.encodingFailed
        }
        return jpeg
    }

    nonisolated private static func downsampledJPEG(at url: URL, maximumPixelSize: Int) -> Data? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}

struct StagedPhotoRemoval {
    let originalURL: URL
    let stagedURL: URL?

    func commit() throws {
        guard let stagedURL else { return }
        try FileManager.default.removeItem(at: stagedURL)
    }

    func restore() throws {
        guard let stagedURL, FileManager.default.fileExists(atPath: stagedURL.path()) else { return }
        try FileManager.default.createDirectory(
            at: originalURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.moveItem(at: stagedURL, to: originalURL)
    }
}

enum PhotoFileError: LocalizedError {
    case unreadableImage
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            String(localized: "The selected image could not be read.")
        case .encodingFailed:
            String(localized: "The image could not be processed.")
        }
    }
}
