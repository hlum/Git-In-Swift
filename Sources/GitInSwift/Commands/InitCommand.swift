import Foundation

func runInit(args: [String]) {
    // Use provided path or current directory
    let path: URL
    if let target = args.first {
        path = URL(fileURLWithPath: target, isDirectory: true)
    } else {
        path = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    }

    let repo = Repository(at: path)
    let fm = FileManager.default

    // Fail if .git already exists
    if fm.fileExists(atPath: repo.gitDir.path) {
        print("fatal: already a git repository")
        exit(1)
    }

    do {
        // Create .git directory structure
        let dirs = [
            repo.gitDir,
            repo.gitDir.appendingPathComponent("objects/info"),
            repo.gitDir.appendingPathComponent("objects/pack"),
            repo.gitDir.appendingPathComponent("refs/heads"),
            repo.gitDir.appendingPathComponent("refs/tags")
        ]
        for dir in dirs {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // Write HEAD
        let head = "ref: refs/heads/main\n"
        try head.write(to: repo.gitDir.appendingPathComponent("HEAD"), atomically: true, encoding: .utf8)

        // Write config
        let config = """
        [core]
        \trepositoryformatversion = 0
        \tfilemode = true
        \tbare = false
        \tlogallrefupdates = true
        """
        try config.write(to: repo.gitDir.appendingPathComponent("config"), atomically: true, encoding: .utf8)

        // Write description
        let description = "Unnamed repository; edit this file to name it for gitweb.\n"
                   try description.write(to:
  repo.gitDir.appendingPathComponent("description"), atomically: true,
  encoding: .utf8)

        print("Initialized empty Git repository in \(repo.gitDir.path)")
        
    } catch {
        print("fatal: failed to initialize repository: \(error.localizedDescription)")
        exit(1)
    }
}