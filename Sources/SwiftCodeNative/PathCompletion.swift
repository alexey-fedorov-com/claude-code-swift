import Foundation

public enum PathCompletion {
    public enum Kind: Sendable, Equatable { case file, directory }

    public struct Entry: Sendable, Equatable {
        public let name: String
        public let kind: Kind
        public init(name: String, kind: Kind) {
            self.name = name; self.kind = kind
        }
    }

    public static func complete(prefix: String, in directory: String) throws -> [Entry] {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: directory)
        let keys: [URLResourceKey] = [.isDirectoryKey]
        let entries = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [])
        let includeHidden = prefix.hasPrefix(".")
        let mapped: [Entry] = entries.compactMap { (entry: URL) -> Entry? in
            let name = entry.lastPathComponent
            if !includeHidden && name.hasPrefix(".") { return nil }
            if !prefix.isEmpty && !name.lowercased().hasPrefix(prefix.lowercased()) { return nil }
            let isDir = (try? entry.resourceValues(forKeys: Set(keys)))?.isDirectory ?? false
            return Entry(name: name, kind: isDir ? .directory : .file)
        }
        return mapped.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}
