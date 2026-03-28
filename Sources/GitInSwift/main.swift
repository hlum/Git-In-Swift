// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

let args = CommandLine.arguments.dropFirst()

guard let command = args.first else {
    print("Usage: git-swift <command> [options]")
    exit(1)
}

switch command {
case "init":
    runInit(args: Array(args.dropFirst()))
case "add":
    runAdd(args: Array(args.dropFirst()))
default:
    print("git-swift: \(command): is not a git-swift command.")
    exit(1)
}
