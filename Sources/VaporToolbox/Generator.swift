import Foundation
import Console

internal let defaultTemplatesDirectory = ".build/Templates/"
internal let defaultTemplatesURLString = "https://gist.github.com/1b9b58c0ca4dbe3538b2707df5959d80.git"

public protocol Generator {
    static var supportedTypes: [String] { get }
    var console: ConsoleProtocol { get }

    init(console: ConsoleProtocol)
    func generate(arguments: [String]) throws
}

public extension Generator {

    public func fileExists(atPath path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    public func checkThatFileExists(atPath path: String) throws {
        guard fileExists(atPath: path) else {
            throw ToolboxError.general("\(path) not found.")
        }
    }

    public func checkThatFileDoesNotExist(atPath path: String) throws {
        guard !fileExists(atPath: path) else {
            throw ToolboxError.general("\(path) already exists")
        }
    }

    public func loadTemplate(atPath: String, fallbackURL: URL) throws -> File {
        if !fileExists(atPath: atPath) {
            try cloneTemplate(atURL: fallbackURL, toPath: atPath.directory)
        }
        return try File(path: atPath)
    }

    public func copyTemplate(atPath: String, fallbackURL: URL, toPath: String, _ editsBlock: ((String) -> String)? = nil) throws {
        var templateFile = try loadTemplate(atPath: atPath, fallbackURL: fallbackURL)
        if let editedContents = editsBlock?(templateFile.contents) {
            templateFile.contents = editedContents
        }
        try checkThatFileDoesNotExist(atPath: toPath)
        console.info("Generating \(toPath)")
        try templateFile.saveCopy(atPath: toPath)
    }

    private func cloneTemplate(atURL templateURL: URL, toPath: String) throws {
        let cloneBar = console.loadingBar(title: "Cloning Template")
        cloneBar.start()
        do {
            _ = try console.backgroundExecute(program: "git", arguments: ["clone", "\(templateURL)", "\(toPath)"])
            _ = try console.backgroundExecute(program: "rm", arguments: ["-rf", "\(toPath)/.git"])
            cloneBar.finish()
        } catch ConsoleError.backgroundExecute(_, let error, _) {
            cloneBar.fail()
            throw ToolboxError.general(error.string.trim())
        }
    }

}

public extension String {

    public var pluralized: String {
        // dumb but effective for what I need
        // TODO: make this smarter
        return characters.last == "s" ? self : self + "s"
    }

    public var directory: String {
        var pathComponents = components(separatedBy: "/")
        pathComponents.removeLast()
        return pathComponents.joined(separator: "/")
    }

}

public struct File {
    public let path: String
    public var contents: String

    public init(path: String) throws {
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        self.init(path: path, contents: contents)
    }

    public init(path: String, contents: String) {
        self.path = path
        self.contents = contents
    }

    public func save() throws {
        try saveCopy(atPath: path)
    }

    public func saveCopy(atPath path: String) throws {
        let directory = path.directory
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directory) {
            try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
    }
}