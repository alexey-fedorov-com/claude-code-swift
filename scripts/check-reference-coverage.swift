#!/usr/bin/env swift
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let referenceList = root.appendingPathComponent("Tests/Golden/reference-files.txt")
let sourceMap = root.appendingPathComponent("docs/rewrite/source-map.tsv")

let referenceText = try String(contentsOf: referenceList, encoding: .utf8)
let mappedText = try String(contentsOf: sourceMap, encoding: .utf8)

let references = Set(referenceText.split(separator: "\n").map(String.init))
let rows = mappedText.split(separator: "\n").dropFirst()
let mapped = Set(rows.compactMap { row -> String? in
    let columns = row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
    return columns.first
})

let missing = references.subtracting(mapped).sorted()
if !missing.isEmpty {
    FileHandle.standardError.write(Data("Missing source-map rows:\n".utf8))
    for path in missing.prefix(200) {
        FileHandle.standardError.write(Data("\(path)\n".utf8))
    }
    if missing.count > 200 {
        FileHandle.standardError.write(Data("... \(missing.count - 200) more\n".utf8))
    }
    exit(1)
}

print("reference coverage complete: \(references.count) files")
