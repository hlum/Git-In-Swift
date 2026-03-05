import Foundation

struct IndexEntry {
/*
ctime (change time)
[4] ctime seconds
[4] ctime nanoseconds

Example:

ctime = 1700000000 seconds
ctime_nsec = 123456789

This is the file metadata change time.

Changed when:

permissions change

ownership changes

rename

metadata update

It is not the content change time.
*/
    var ctimeSec: UInt32
    var ctimeNsec: UInt32

/*
[4] mtime seconds
[4] mtime nanoseconds

Example:

mtime = 1700000100

This is the last content modification time.

Git uses this for fast change detection.

Example workflow:

git status

Git checks:

if mtime same AND size same
    assume file unchanged
else
    recompute SHA

This makes Git very fast.
*/
    var mtimeSec: UInt32
    var mtimeNsec: UInt32

/*
[4] dev

Filesystem device number.

Example:

disk id

Used to detect file movement across devices.

Mostly useful on Unix.
*/
    var dev: UInt32

/*
The inode number.

On Unix every file has an inode.

Example:

ls -i file.txt

This identifies the actual file on disk.

Git uses (dev + ino) to detect:

file replacement

file recreation
*/
    var ino: UInt32
/*
Example:

100644

This is the file type + permissions.

Common modes:

Mode	Meaning
100644	normal file
100755	executable
120000	symlink

Binary representation:

file type + permission bits

Git stores it as 32-bit integer.
*/
    var mode: UInt32

    var uid: UInt32 // User ID of file owner (mostly ignored by Git)

    var gid: UInt32 // Group ID of file owner (mostly ignored by Git)

/*
[4] file size

Example:

25

Git stores the size to detect changes quickly.

Fast check:

if size same + mtime same
    skip hashing
*/
    var size: UInt32

    var sha: String //(40 char hex) SHA-1 hash of file content

    var flags: UInt16 // Additional flags (mostly unused)

    var path: String // File path relative to repository root

}

/*
Git Index File Layout (Version 2)
All integers are **big-endian**

FILE STRUCTURE
────────────────────────────────────────

INDEX FILE
┌──────────────────────────────┐
│ HEADER (12 bytes)            │
├──────────────────────────────┤
│ ENTRY 1                      │
├──────────────────────────────┤
│ ENTRY 2                      │
├──────────────────────────────┤
│ ...                          │
├──────────────────────────────┤
│ ENTRY N                      │
├──────────────────────────────┤
│ CHECKSUM (20 bytes SHA-1)    │
└──────────────────────────────┘

HEADER (12 bytes)
Offset
0   ┌───────────────┐
│ "DIRC"        │ 4 bytes magic
4   ├───────────────┤
│ version       │ 4 bytes (usually 2)
8   ├───────────────┤
│ entry count   │ 4 bytes
12  └───────────────┘

INDEX ENTRY STRUCTURE
Each entry begins at `start = offset`

Offset (relative to entry start)

0   ┌───────────────┐
│ ctime sec     │ 4
4   ├───────────────┤
│ ctime nsec    │ 4
8   ├───────────────┤
│ mtime sec     │ 4
12  ├───────────────┤
│ mtime nsec    │ 4
16  ├───────────────┤
│ dev           │ 4
20  ├───────────────┤
│ ino           │ 4
24  ├───────────────┤
│ mode          │ 4
28  ├───────────────┤
│ uid           │ 4
32  ├───────────────┤
│ gid           │ 4
36  ├───────────────┤
│ file size     │ 4
40  ├───────────────┤
│ SHA-1 (blob)  │ 20 bytes
60  ├───────────────┤
│ flags         │ 2 bytes
62  ├───────────────┤
│ path bytes    │ variable
??  ├───────────────┤
│ null byte     │ 1
??  ├───────────────┤
│ padding       │ align to 8-byte boundary
??  └───────────────┘

ENTRY SIZE RULE
(entry_size) must be divisible by 8

padding = (8 - (entry_size % 8)) % 8

SHA FIELD IMPORTANT NOTE

The SHA stored in the entry is **20 raw bytes**, not a hex string.

Example:

Hex representation:
3b18e512dba79e4c8300dd08aeb37f8e728b8dad

Stored in index as bytes:
3b 18 e5 12 db a7 9e 4c 83 00 dd 08 ae b3 7f 8e 72 8b 8d ad

*/

func readIndex(from url: URL) -> [IndexEntry] {
    guard let data = try? Data(contentsOf: url), data.count > 12 else { return [] }
    var offset = 0

    func readUInt32() -> UInt32 {
        let val = data[offset..<offset+4].withUnsafeBytes { 
            $0.load(as: UInt32.self) 
            }.bigEndian

        offset += 4
        return val
    }

    let magic = String(bytes: data[0 ..< 4], encoding: .utf8)
    guard magic == "DIRC" else { return [] }
    offset = 4

    let _ = readUInt32() // version
    let count = readUInt32()

    var entries: [IndexEntry] = []


    for _ in 0..<count {
        let start = offset
        let ctimeSec  = readUInt32()
        let ctimeNsec = readUInt32()
        let mtimeSec  = readUInt32()
        let mtimeNsec = readUInt32()
        let dev       = readUInt32()
        let ino       = readUInt32()
        let mode      = readUInt32()
        let uid       = readUInt32()
        let gid       = readUInt32()
        let size      = readUInt32()

        // 20-byte binary SHA -> hex string
        let shaBytes = data[offset..<offset+20]
        let sha = shaBytes.map { String(format: "%02x", $0) }.joined()
        offset += 20 // move past SHA

        let flags = data[offset..<offset+2].withUnsafeBytes {
            $0.load(as: UInt16.self) 
        }.bigEndian
        offset += 2

        // Read path until null byte
        var pathBytes: [UInt8] = []
        while offset < data.count && data[offset] != 0 {
            pathBytes.append(data[offset])
            offset += 1
        }
        offset += 1 // skip null byte

        // Correct padding: total entry so far must align to 8 bytes
        let remainder = (offset - start) % 8
        if remainder != 0 { offset += 8 - remainder } // pad to next 8-byte boundary

        let path = String(bytes: pathBytes, encoding: .utf8) ?? ""
        entries.append(IndexEntry(
               ctimeSec: ctimeSec, ctimeNsec: ctimeNsec,
               mtimeSec: mtimeSec, mtimeNsec: mtimeNsec,
               dev: dev, ino: ino, mode: mode, uid: uid, gid: gid,
               size: size, sha: sha, flags: flags, path: path
           ))
        }

        guard data.count >= 20 else { return [] }

        let checksumBytes = data.suffix(20)
        let checksum = checksumBytes.map { String(format: "%02x", $0) }.joined()

        let computedChecksum = sha1(data.dropLast(20))

        guard checksum == computedChecksum else {
            print("fatal: index file checksum mismatch")
            return []
        }

        return entries
}


func writeIndex(entries: [IndexEntry], to url: URL) throws {
    var data = Data()

    func appendUInt32(_ val: UInt32) {
        var big = val.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &big, Array.init))
    }
    func appendUInt16(_ val: UInt16) {
        var big = val.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &big, Array.init))
    }

    // write HEADER
    data.append(contentsOf: "DIRC".utf8)

    // write version (4 bytes)
    appendUInt32(2)

    // write entry count (4 bytes)
    appendUInt32(UInt32(entries.count))

    // write entries
    for entry in entries {
        let start = data.count

        appendUInt32(entry.ctimeSec)
        appendUInt32(entry.ctimeNsec)
        appendUInt32(entry.mtimeSec)
        appendUInt32(entry.mtimeNsec)
        appendUInt32(entry.dev)
        appendUInt32(entry.ino)
        appendUInt32(entry.mode)
        appendUInt32(entry.uid)
        appendUInt32(entry.gid)
        appendUInt32(entry.size)

        // write SHA as 20 raw bytes
        let shaBytes = stride(from: 0, to: entry.sha.count, by: 2).map {
            UInt8(entry.sha[entry.sha.index(entry.sha.startIndex, offsetBy: $0)..<entry.sha.index(entry.sha.startIndex, offsetBy: $0 + 2)], radix: 16)!
        }

        data.append(contentsOf: shaBytes)

        // write Flags
        appendUInt16(entry.flags)

        // write path + null byte
        data.append(contentsOf: entry.path.utf8)
        data.append(0) // null byte


        // write Padding
        let entryLen = data.count - start
        let remainder = entryLen % 8
        if remainder != 0 {
            data.append(contentsOf: [UInt8](repeating: 0, count: 8 - remainder))
        }
    }

    // write checksum (SHA-1 of all previous data)
    let checksum = sha1(data)
    let checksumBytes = stride(from: 0, to: checksum.count, by: 2).map {
        UInt8(checksum[checksum.index(checksum.startIndex, offsetBy:$0)..<checksum.index(checksum.startIndex, offsetBy: $0 + 2)], radix:16)!
    }
    data.append(contentsOf: checksumBytes)

    try data.write(to: url)
}