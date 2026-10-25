import Foundation

struct ManagedFileStore {
    private let fileManager = FileManager.default

    func saveLogo(_ data: Data, replacing oldRelativePath: String?) throws -> String {
        let directory = try logoDirectory()
        let fileName = "\(UUID().uuidString).image"
        let destination = directory.appending(path: fileName)
        try data.write(to: destination, options: .atomic)

        if let oldRelativePath {
            try? removeFile(relativePath: oldRelativePath)
        }
        return "Logos/\(fileName)"
    }

    func data(relativePath: String?) -> Data? {
        guard let relativePath else { return nil }
        guard let directory = try? applicationDirectory() else { return nil }
        return try? Data(contentsOf: directory.appending(path: relativePath))
    }

    func removeFile(relativePath: String) throws {
        let url = try applicationDirectory().appending(path: relativePath)
        if fileManager.fileExists(atPath: url.path()) {
            try fileManager.removeItem(at: url)
        }
    }

    private func logoDirectory() throws -> URL {
        let directory = try applicationDirectory().appending(path: "Logos", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func applicationDirectory() throws -> URL {
        let supportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return supportURL.appending(path: "JobbBevis", directoryHint: .isDirectory)
    }
}
