
struct Help: Command {
    static let id = "help"
    static func execute(with args: [String], in shell: PosixSubsystem) {
        print(VaporCLI.usage)

        var help = "\nAvailable Commands:\n\n"
        help += VaporCLI.subCommands
            .map { cmd in cmd.description }//"  \(cmd.id):\n\(cmd.description)\n"}
            .joined(separator: "\n")
        help += "\n"
        print(help)

        print("Community:")
        print("    Join our Slack if you have questions,")
        print("    need help, or want to contribute.")
        print("    http://slack.qutheory.io")
        print()
    }
}

