import Foundation

struct TreeEntry {
    let mode: String // "100644" for file, "040000" for directory
    /*
        If mode == "100644" → SHA of a blob
        If mode == "040000" → SHA of another tree
    */
    let name: String
    let sha: String
}


struct Tree: GitObject {
    let type: GitObjectType = .tree
    let entries: [TreeEntry]

    func serialize() -> Data {
        var data = Data()
        for entry in entries {
            data.append("\(entry.mode) \(entry.name)\0".data(using: .utf8)!)

            let bytes = shaToBytes(entry.sha)
            data.append(Data(bytes))
        }
        return data
    }


    private func shaToBytes(_ sha: String) -> [UInt8] {
        var bytes: [UInt8] = []
        var index = sha.startIndex

        while index < sha.endIndex {
            let nextIndex = sha.index(index, offsetBy: 2)
            let byteString = sha[index..<nextIndex]
            bytes.append(UInt8(byteString, radix: 16)!)
            index = nextIndex
        }

        return bytes
    }
}