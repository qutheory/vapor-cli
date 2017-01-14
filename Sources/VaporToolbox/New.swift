import Console

public final class New: Command {
    public let id = "new"

    public let defaultTemplate = "https://github.com/vapor/basic-template"

    public let signature: [Argument]

    public let help: [String] = [
        "Creates a new Vapor application from a template."
    ]

    public let console: ConsoleProtocol

    public init(console: ConsoleProtocol) {
        self.console = console

        signature = [
            Value(name: "name", help: [
                "The application's executable name."
            ]),
            Option(name: "template", help: [
                "The template repository to clone.",
                "Default: \(defaultTemplate)."
            ])
        ]
    }

    public func run(arguments: [String]) throws {
        let template = try loadTemplate(arguments: arguments)
        let name = try value("name", from: arguments).string ?? ""

        let cloneBar = console.loadingBar(title: "Cloning Template")
        cloneBar.start()

        do {
            _ = try console.backgroundExecute(program: "git", arguments: ["clone", "\(template)", "\(name)"])
            _ = try console.backgroundExecute(program: "rm", arguments: ["-rf", "\(name)/.git"])
            cloneBar.finish()
        } catch ConsoleError.backgroundExecute(_, let error, _) {
            cloneBar.fail()
            throw ToolboxError.general(error.string.trim())
        }

        do {
            let file = "\(name)/Package.swift"
            var manifest = try console.backgroundExecute(program: "/bin/sh", arguments: ["-c", "cat \(file)"])
            manifest = manifest.components(separatedBy: "VaporApp").joined(separator: name)
            manifest = manifest.components(separatedBy: "\"").joined(separator: "\\\"")
            _ = try console.backgroundExecute(program: "/bin/sh", arguments: ["-c", "echo \"\(manifest)\" > \(file)"])
        } catch {
            console.error("Could not update Package.swift file.")
        }

        console.print()

        for line in console.center(asciiArt) {
            for character in line.characters {
                let style: ConsoleStyle

                if let color = colors[character] {
                    style = .custom(color)
                } else {
                    style = .plain
                }

                console.output("\(character)", style: style, newLine: false)
            }
            console.print()
        }

        console.print()

        for line in [
            "Project \"\(name)\" has been created.",
            "Type `cd \(name)` to enter the project directory.",
            "Enjoy!"
        ] {
            console.output(console.center(line))
        }

        console.print()
    }

    private func loadTemplate(arguments: [String]) throws -> String {
        guard let template = arguments.options["template"]?.string else { return defaultTemplate }
        return try expand(template: template)
    }

    /**
         http(s)://whatever.com/foo/bar => http(s)://whatever.com/foo/bar
         foo/some-template => https://github.com/foo/some-template
         some-template => https://github.com/vapor/some-template
         some => https://github.com/vapor/some
         if fails, attempts `-template` suffix
         some => https://github.com/vapor/some-template
    */
    private func expand(template: String) throws -> String {
        // if valid URL, use it
        guard !isValid(url: template) else { return template }
        // `/` indicates `owner/repo`
        guard !template.contains("/") else { return "https://github.com/" + template }
        // no '/' indicates vapor default
        let direct = "https://github.com/vapor/" + template
        guard !isValid(url: direct) else { return direct }
        // invalid url attempts `-template` suffix
        return direct + "-template"
    }

    private func isValid(url: String) -> Bool {
        do {
            // http://stackoverflow.com/a/6136861/2611971
            let result = try console.backgroundExecute(
                program: "curl",
                arguments: [
                    "-o",
                    "/dev/null",
                    "--silent",
                    "--head",
                    "--write-out",
                    "'%{http_code}\\n'",
                    url
                ]
            )
            return result.contains("200")
        } catch {
            // yucky...
            return false
        }
    }

    public let asciiArt: [String] = [
         "               **",
         "             **~~**",
         "           **~~~~~~**",
         "         **~~~~~~~~~~**",
         "       **~~~~~~~~~~~~~~**",
         "     **~~~~~~~~~~~~~~~~~~**",
         "   **~~~~~~~~~~~~~~~~~~~~~~**",
         "  **~~~~~~~~~~~~~~~~~~~~~~~~**",
         " **~~~~~~~~~~~~~~~~~~~~~~~~~~**",
         "**~~~~~~~~~~~~~~~~~~~~~~~~~~~~**",
         "**~~~~~~~~~~~~~~~~~~~~~~~~~~~~**",
         "**~~~~~~~~~~~~~~~~~~~~~++++~~~**",
         " **~~~~~~~~~~~~~~~~~~~++++~~~**",
         "  ***~~~~~~~~~~~~~~~++++~~~***",
         "    ****~~~~~~~~~~++++~~****",
         "       *****~~~~~~~~~*****",
         "          *************",
         " ",
         " _       __    ___   ___   ___",
         "\\ \\  /  / /\\  | |_) / / \\ | |_)",
         " \\_\\/  /_/--\\ |_|   \\_\\_/ |_| \\",
         "   a web framework for Swift",
    ]

    public let colors: [Character: ConsoleColor] = [
        "*": .magenta,
        "~": .blue,
        "+": .cyan, // Droplet
        "_": .magenta,
        "/": .magenta,
        "\\": .magenta,
        "|": .magenta,
        "-": .magenta,
        ")": .magenta // Title
    ]
}
