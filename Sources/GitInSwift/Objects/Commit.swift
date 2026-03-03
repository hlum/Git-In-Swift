import Foundation

struct CommitObject: GitObject {
    let type: GitObjectType = .commit
    let treeSHA: String
    let parentSHAs: [String] // 初期コミットは空の配列
    let author: String // "Name <email> timestamp +0000"
    let committer: String
    let message: String

    func serialize() -> Data {
        var lines = ["tree \(treeSHA)"]
        for parent in parentSHAs {
            lines.append("parent \(parent)")
        }
        lines.append("author \(author)")
        lines.append("committer \(committer)")
        lines.append("")
        lines.append(message)
        return lines.joined(separator: "\n").data(using: .utf8)!
    }
}