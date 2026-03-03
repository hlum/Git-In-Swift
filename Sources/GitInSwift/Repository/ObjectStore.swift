import Foundation

struct ObjectStore {
    let gitDir: URL // path to .git/

    func objectPath(for sha: String) -> URL {
        let dir = String(sha.prefix(2))
        let file = String(sha.dropFirst(2))
        return gitDir.appending(path: "objects/\(dir)/\(file)")
    }


    @discardableResult
    func write(_ object: any GitObject) throws -> String {
        let (sha, raw) = object.store()
        let path = objectPath(for: sha)
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: path.path) {
            try zlibCompress(raw)?.write(to: path)
        }

        return sha
    }

    // SHAからオブジェクトを読み込む
    func read(sha: String) throws -> Data {
        let path = objectPath(for: sha)
        let compressedData = try Data(contentsOf: path)
        guard let decompressedData = zlibDecompress(compressedData) else {
            throw NSError(domain: "GitError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decompress object data"])
        }
        return decompressedData
    }

    func parse(sha: String) throws -> (type: GitObjectType, content: Data) {
        let raw = try read(sha: sha)
        guard let nullIndex = raw.firstIndex(of: 0) else {
            throw NSError(domain: "GitError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid object format: no null byte found"])
        }
        let header = String(data: raw[..<nullIndex], encoding: .utf8)!

        let typeName = header.components(separatedBy: " ")[0]
        let type = GitObjectType(rawValue: typeName)!
        let content = raw[raw.index(after: nullIndex)...]
        return (type, Data(content))
    }

}