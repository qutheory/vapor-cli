import Foundation
import Console

internal let defaultTemplatesDirectory = ".build/Templates/"
internal let defaultTemplatesURLString = "https://gist.github.com/1b9b58c0ca4dbe3538b2707df5959d80.git"

protocol Generator {
    var console: ConsoleProtocol { get }
    init(console: ConsoleProtocol)
    func generate(arguments: [String]) throws
}

extension Generator {

    func fileExists(atPath path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    func checkThatFileExists(atPath path: String) throws {
        guard fileExists(atPath: path) else {
            throw ToolboxError.general("\(path) not found.")
        }
    }

    func checkThatFileDoesNotExist(atPath path: String) throws {
        guard !fileExists(atPath: path) else {
            throw ToolboxError.general("\(path) already exists")
        }
    }

    func loadTemplate(atPath: String, fallbackURL: URL) throws -> File {
        if !fileExists(atPath: atPath) {
            try cloneTemplate(atURL: fallbackURL, toPath: atPath.directory)
        }
        return try File(path: atPath)
    }

    func copyTemplate(atPath: String, fallbackURL: URL, toPath: String, _ editsBlock: ((String) -> String)? = nil) throws {
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

extension String {

    var directory: String {
        var pathComponents = components(separatedBy: "/")
        pathComponents.removeLast()
        return pathComponents.joined(separator: "/")
    }

    var pluralized: String {
        return pluralize()
    }

    var length: Int {
        return  characters.count
    }

    func substring(from index: Int, length: Int) -> String
    {
        let start = self.index(self.startIndex, offsetBy: index)
        let end = self.index(self.startIndex, offsetBy: index + length)
        return self[start ..< end]
    }

    private var vowels: [String] {
        return ["a", "e", "i", "o", "u"]
    }

    private var consonants: [String] {
        return ["b", "c", "d", "f", "g", "h", "j", "k", "l", "m", "n", "p", "q", "r", "s", "t", "v", "w", "x", "z"]
    }

    func pluralize(count: Int = 2) -> String {
        if count == 1 {
            return self
        }
        else {
            let lastChar = self.substring(from: self.length - 1, length: 1)
            let secondToLastChar = self.substring(from: self.length - 2, length: 1)
            var prefix = "", suffix = ""

            if lastChar.lowercased() == "y" && vowels.filter({x in x == secondToLastChar}).count == 0 {
                prefix = self.substring(to: index(self.endIndex, offsetBy: -1))
                suffix = "ies"
            }
            else if lastChar.lowercased() == "s" || (lastChar.lowercased() == "o" && consonants.filter({x in x == secondToLastChar}).count > 0) {
                prefix = self
                suffix = "es"
            }
            else {
                prefix = self
                suffix = "s"
            }

            return prefix + (lastChar != lastChar.uppercased() ? suffix : suffix.uppercased())
        }
    }

}

struct File {
    let path: String
    var contents: String

    init(path: String) throws {
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        self.init(path: path, contents: contents)
    }

    init(path: String, contents: String) {
        self.path = path
        self.contents = contents
    }

    func save() throws {
        try saveCopy(atPath: path)
    }

    func saveCopy(atPath path: String) throws {
        let directory = path.directory
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directory) {
            try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
