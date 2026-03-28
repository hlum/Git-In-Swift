import Foundation

func runAdd(args: [String]) {
    do {
        // Get the repository
        let repo = try Repository.current()
        let indexPath = repo.gitDir.appendingPathComponent("index")

        // Read existing index(or create empty if doesn't exist)
        var entries: [IndexEntry] = []
        if FileManager.default.fileExists(atPath: indexPath.path) {
            entries = readIndex(from: indexPath)
        }

        // Process each file argument
        for filePath in args {
            let absoluteFileURL = repo.workTree.appendingPathComponent(filePath)

            // Check if file exists
            guard FileManager.default.fileExists(atPath: absoluteFileURL.path) else {
                print("fatal: pathspec '\(filePath)' did not match any files")
                exit(1)
            }

            // Read file content
            let content = try Data(contentsOf: absoluteFileURL)

            // Create blob object
            let blob = Blob(content: content)
            let store = ObjectStore(gitDir: repo.gitDir)
            let sha = try store.write(blob)

            // Get file metadata
            let attributes = try FileManager.default.attributesOfItem(
                atPath: absoluteFileURL.path)
            let modDate = attributes[.modificationDate] as! Date
            let fileSize = attributes[.size] as! UInt64

            // Create index entry
            let entry = IndexEntry(
                ctimeSec: UInt32(modDate.timeIntervalSince1970),
                ctimeNsec: 0,
                mtimeSec: UInt32(modDate.timeIntervalSince1970),
                mtimeNsec: 0,
                dev: 0,
                ino: attributes[.systemFileNumber] as? UInt32 ?? 0,
                mode: 100644,
                uid: attributes[.ownerAccountID] as? UInt32 ?? 0,
                gid: attributes[.groupOwnerAccountID] as? UInt32 ?? 0,
                size: UInt32(fileSize),
                sha: sha,
                flags: UInt16(filePath.count & 0xFFF),
                path: filePath)

            // add or update the entry in the index
            if let index = entries.firstIndex(where: { $0.path == filePath }) {
                entries[index] = entry
            } else {
                entries.append(entry)
            }

            // Sort entries by path(Git Requires index to be sorted)
            entries.sort { $0.path < $1.path }

            // Write updated index back to disk
            try writeIndex(entries: entries, to: indexPath)

            print("Added '\(filePath)' to staging area")
        }
    } catch {
        print("Error: \(error.localizedDescription)")
        exit(1)
    }
}
