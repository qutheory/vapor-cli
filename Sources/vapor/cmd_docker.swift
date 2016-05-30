
struct Docker: Command {
    static let id = "docker"

    static var subCommands: [Command.Type] = [
                                                 Docker.Init.self,
                                                 Docker.Build.self,
                                                 Docker.Run.self,
                                                 Docker.Enter.self
    ]

    static func execute(with args: [String], in directory: String) {
        executeSubCommand(with: args, in: directory)
    }
}

extension Docker {
    static var help: [String] {
        return [
                   "Setup and run vapor app via docker",
                   "sub commands: " + subCommands.map { "\($0.id)" }.joined(separator: "|"),
        ]
    }
}

extension Docker {
    static let swiftVersion: String? = {
        return try? String(contentsOfFile: ".swift-version").trim()
    }()

    static let imageName: String? = {
        if let version = swiftVersion {
            return "qutheory/swift:\(version)"
        } else {
            return nil
        }
    }()
}

extension Docker {
    struct Init: Command {
        static let id = "init"

        static func execute(with args: [String], in directory: String) {
            let quiet = args.contains("--verbose") ? "" : "-s"

            if fileExists("Dockerfile") {
                fail("A Dockerfile already exists in the current directory.\nPlease move it and try again or run `vapor docker build`.")
            }

            do {
                print("Downloading Dockerfile...")
                try run("curl -L \(quiet) docker.qutheory.io -o Dockerfile")
            } catch {
                fail("Could not download Dockerfile.")
            }

            print("Dockerfile created.")
            print("You may now adjust the file or")
            print("run `vapor docker build`.")
        }

        static var help: [String] {
            return [
                       "Creates a Dockerfile",
            ]
        }
    }
}

extension Docker {
    struct Build: Command {
        static let id = "build"

        static func execute(with args: [String], in directory: String) {
            guard let
                swiftVersion = Docker.swiftVersion,
                imageName = Docker.imageName
                else {
                    fail("Could not determine Swift version (check your .swift-version file)")
            }

            do {
                print("Building docker image with Swift version: \(swiftVersion)")
                print("This may take a few minutes if no layers are cached...")
                let cmd = "docker build --rm -t \(imageName) --build-arg SWIFT_VERSION=\(swiftVersion) ."
                try run(cmd)
            } catch Error.system(let result) {
                if result == 32512 {
                    print()
                    print("Make sure you have the Docker Toolbox installed")
                    print("https://www.docker.com/products/docker-toolbox")
                    print("Tested with Docker Toolbox 1.11.1")
                }
                if result == 256 {
                    print()
                    print("Make sure you have the Docker daemon running")
                    print("or try running the following snippet:")
                    print("`eval \"$(docker-machine env default)\"`")
                }
                fail("Could not initialize Docker")
            } catch {
                fail("Could not initialize Docker")
            }
        }

        static var help: [String] {
            return [
                       "Build the docker image, using the swift",
                       "version specified in .swift-version."
            ]
        }
    }
}

extension Docker {
    struct Run: Command {
        static let id = "run"

        static func execute(with args: [String], in directory: String) {
            guard let
                imageName = Docker.imageName
                else {
                    fail("Could not determine Swift version (check your .swift-version file)")
            }

            let cmd = "docker run --rm -it -v $(PWD):/vapor -p 8080:8080 \(imageName)"
            do {
                print("Launching app with image \(imageName)")
                try run(cmd)
            } catch Error.system(let result) {
                if result == 33280 {
                    // Sven: Attempt to identify if the user has ctrl-c'd out of the container
                    // so we don't show an error in that case.
                    // Call to system returns the exit status of the shell as returned by waitpid(2).
                    // This doesn't align with 33280 which is why I'm hard-coding the value but
                    // testing showed that other means of terminating the command returns different
                    // values.
                } else {
                    fail("docker run command failed, command was\n\(cmd)")
                }
            } catch {
                fail("docker run command failed, command was\n\(cmd)")
            }
        }

        static var help: [String] {
            return [
                       "Run the app in a docker container with the",
                       "image created by running 'docker build'"
            ]
        }
    }
}


extension Docker {
    struct Enter: Command {
        static let id = "enter"

        static func execute(with args: [String], in directory: String) {
            guard let
                imageName = Docker.imageName
                else {
                    fail("Could not determine Swift version (check your .swift-version file)")
            }

            do {
                print("Starting bash in image \(imageName)")
                let cmd = "docker run --rm -it -v $(PWD):/vapor --entrypoint bash \(imageName)"
                try run(cmd)
            } catch Error.system(let result) {
                if result != 33280 {
                    fail("Could not enter Docker container")
                }
            } catch {
                fail("Could not enter Docker container")
            }
        }
        
        static var help: [String] {
            return [
                       "Enter the docker container (useful for",
                       "debugging purposes)"
            ]
        }
    }
}