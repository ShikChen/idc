// The Swift Programming Language
// https://docs.swift.org/swift-book
// 
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser

@main
struct Idc: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "idc",
        abstract: "iOS Device Control CLI",
        subcommands: [Server.self, Screenshot.self, DescribeUI.self]
    )
}

struct Server: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage idc-server",
        subcommands: [ServerStart.self, ServerHealth.self]
    )
}
