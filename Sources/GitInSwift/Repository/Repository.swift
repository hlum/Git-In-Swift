import Foundation

struct Repository {
    let workTree: URL // project root folder
    let gitDir: URL // workTree/.git/

    init(at path: URL) {
        self.workTree = path
        self.gitDir = path.appendingPathComponent(".git")
    }

    // find repo from the current working directory
    static func current() throws -> Repository {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return Repository(at: cwd)
    }
}