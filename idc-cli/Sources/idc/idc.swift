import ArgumentParser

@main
struct Idc: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "idc",
        abstract: "iOS Device Control CLI",
        subcommands: [Server.self, Screenshot.self, DescribeUI.self, Tap.self]
    )
}

struct Server: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage idc-server",
        subcommands: [ServerStart.self, ServerHealth.self]
    )
}
