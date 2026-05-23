/// PluginManifestTests — tests for PluginManifest Codable and validation.

import Testing
import Foundation
@testable import SwiftCodePlugins
import SwiftCodeCore

@Suite("PluginManifest")
struct PluginManifestTests {

    @Test("decodes minimal manifest")
    func decodesMinimal() throws {
        let json = #"{"name":"my-plugin","version":"1.0.0"}"#
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(json.utf8))
        #expect(manifest.name == "my-plugin")
        #expect(manifest.version == "1.0.0")
        #expect(manifest.description == nil)
        #expect(manifest.bin == nil)
    }

    @Test("decodes full manifest with bin field")
    func decodesFullManifest() throws {
        let json = """
        {
          "name": "my-plugin",
          "version": "2.1.0",
          "description": "A test plugin",
          "author": "Test Author",
          "bin": {
            "my-cmd": "bin/my-cmd"
          },
          "commands": ["/test"],
          "skills": ["test-skill"],
          "trust": "trusted",
          "isManaged": false
        }
        """
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(json.utf8))
        #expect(manifest.name == "my-plugin")
        #expect(manifest.version == "2.1.0")
        #expect(manifest.description == "A test plugin")
        #expect(manifest.author == "Test Author")
        #expect(manifest.bin == ["my-cmd": "bin/my-cmd"])
        #expect(manifest.commands == ["/test"])
        #expect(manifest.skills == ["test-skill"])
        #expect(manifest.trust == "trusted")
        #expect(manifest.isManaged == false)
    }

    @Test("2.1.91 backport: bin field is decoded correctly")
    func binFieldDecoded() throws {
        let json = #"{"name":"cli-plugin","version":"1.0.0","bin":{"foo":"bin/foo","bar":"bin/bar"}}"#
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(json.utf8))
        #expect(manifest.bin?.count == 2)
        #expect(manifest.bin?["foo"] == "bin/foo")
        #expect(manifest.bin?["bar"] == "bin/bar")
    }

    @Test("roundtrips through encode/decode")
    func roundtrip() throws {
        let original = PluginManifest(
            name: "roundtrip-plugin",
            version: "3.0.0",
            description: "Round trip test",
            bin: ["cmd": "bin/cmd"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PluginManifest.self, from: data)
        #expect(decoded.name == original.name)
        #expect(decoded.version == original.version)
        #expect(decoded.description == original.description)
        #expect(decoded.bin == original.bin)
    }

    @Test("validation passes for valid manifest")
    func validationPasses() throws {
        let manifest = PluginManifest(name: "valid-plugin", version: "1.0.0")
        try manifest.validate() // Should not throw
    }

    @Test("validation rejects empty name")
    func rejectsEmptyName() throws {
        let manifest = PluginManifest(name: "", version: "1.0.0")
        #expect(throws: PluginManifestError.emptyName) {
            try manifest.validate()
        }
    }

    @Test("validation rejects invalid name with spaces")
    func rejectsInvalidName() throws {
        let manifest = PluginManifest(name: "my plugin has spaces", version: "1.0.0")
        var didThrow = false
        do {
            try manifest.validate()
        } catch PluginManifestError.invalidName {
            didThrow = true
        }
        #expect(didThrow)
    }

    @Test("validation rejects invalid trust value")
    func rejectsInvalidTrust() throws {
        let manifest = PluginManifest(name: "test", version: "1.0.0", trust: "maybe")
        #expect(throws: PluginManifestError.invalidTrust("maybe")) {
            try manifest.validate()
        }
    }

    @Test("validation allows trusted and untrusted trust values")
    func allowsValidTrustValues() throws {
        for trust in ["trusted", "untrusted"] {
            let manifest = PluginManifest(name: "test", version: "1.0.0", trust: trust)
            try manifest.validate()
        }
    }

    @Test("extra fields are preserved on round-trip")
    func extraFieldsPreserved() throws {
        let json = #"{"name":"test","version":"1.0.0","customField":"customValue"}"#
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(json.utf8))
        #expect(manifest.extraFields["customField"] == .string("customValue"))

        // Re-encode and verify
        let reencoded = try JSONEncoder().encode(manifest)
        let obj = try JSONSerialization.jsonObject(with: reencoded) as? [String: Any]
        #expect(obj?["customField"] as? String == "customValue")
    }
}
