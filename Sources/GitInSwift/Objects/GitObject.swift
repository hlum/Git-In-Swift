import Foundation

enum GitObjectType: String {
    case blob, tree, commit, tag
}

protocol GitObject {
    var type: GitObjectType { get }
    func serialize() -> Data // Rawデータ（headerなし)
}


extension GitObject {
    func store() -> (sha: String, raw: Data) {
        let content = serialize()
        let header = "\(type.rawValue) \(content.count)\0"
        var raw = header.data(using: .utf8)!
        raw.append(content)
        let sha = sha1(raw)
        return (sha, raw)
    }
}