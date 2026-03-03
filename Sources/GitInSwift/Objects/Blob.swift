import Foundation

struct Blob: GitObject {
    let type: GitObjectType = .blob
    let content: Data

    func serialize() -> Data { content }
}