import Foundation
import UniformTypeIdentifiers

/// Filesystem operations for named secondary resources stored inside document packages.
///
/// The replacement API is preservation-first: stale resources are removed only after every
/// desired resource validates and writes successfully. A failed replacement therefore leaves
/// existing resources in place while allowing the caller's primary document data to remain saved.
public enum PackageResourceDirectory {
    public static func isValidPathComponent(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && name != "."
            && name != ".."
            && !name.contains("/")
            && !name.contains(":")
            && !name.contains("\\")
    }

    public static func copyIfPresent(
        from source: URL,
        to destination: URL,
        resourceDescription: String,
        primaryDataDescription: String
    ) -> [PackageDocumentWriteWarning] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
            return []
        } catch {
            return [.init("\(primaryDataDescription), but the existing \(resourceDescription) could not be copied: \(error.localizedDescription)")]
        }
    }

    public static func replaceAll(
        in directory: URL,
        resources: [String: SBJResourceContent],
        nameIsValid: (String) -> Bool = PackageResourceDirectory.isValidPathComponent,
        storageFilename: (String, SBJResourceContent) -> String,
        logicalName: (String) -> String,
        resourceDescription: String,
        primaryDataDescription: String
    ) -> [PackageDocumentWriteWarning] {
        let fileManager = FileManager.default
        var warnings: [PackageDocumentWriteWarning] = []
        var allWritesSucceeded = true

        let existingNames: [String]
        if fileManager.fileExists(atPath: directory.path) {
            do {
                existingNames = try fileManager.contentsOfDirectory(atPath: directory.path)
            } catch {
                existingNames = []
                allWritesSucceeded = false
                warnings.append(.init("\(primaryDataDescription), but existing \(resourceDescription)s could not be inspected. Nothing was deleted: \(error.localizedDescription)"))
            }
        } else {
            existingNames = []
        }

        if !resources.isEmpty {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                return warnings + [.init("\(primaryDataDescription), but the \(resourceDescription) directory could not be created: \(error.localizedDescription)")]
            }
        }

        for (name, resource) in resources.sorted(by: { $0.key < $1.key }) {
            guard nameIsValid(name) else {
                allWritesSucceeded = false
                warnings.append(.init("\(primaryDataDescription), but \(resourceDescription) ‘\(name)’ has an invalid storage name and was not written."))
                continue
            }

            let filename = storageFilename(name, resource)
            let wrapper = resource.storageFileWrapper()
            let target = directory.appendingPathComponent(filename, isDirectory: wrapper.isDirectory)
            do {
                try wrapper.write(
                    to: target,
                    options: .atomic,
                    originalContentsURL: fileManager.fileExists(atPath: target.path) ? target : nil
                )
            } catch {
                allWritesSucceeded = false
                warnings.append(.init("\(primaryDataDescription), but \(resourceDescription) ‘\(name)’ could not be written. Existing resources were not deleted: \(error.localizedDescription)"))
            }
        }

        guard allWritesSucceeded else { return warnings }

        let desiredLogicalNames = Set(resources.keys)
        for filename in existingNames {
            let oldLogicalName = logicalName(filename)
            let desiredFilename = resources[oldLogicalName].map { storageFilename(oldLogicalName, $0) }
            let shouldRemove = !desiredLogicalNames.contains(oldLogicalName) || desiredFilename != filename
            guard shouldRemove else { continue }
            do {
                try fileManager.removeItem(at: directory.appendingPathComponent(filename))
            } catch {
                warnings.append(.init("\(primaryDataDescription), but obsolete \(resourceDescription) ‘\(filename)’ could not be removed: \(error.localizedDescription)"))
            }
        }

        do { try removeIfEmpty(directory) }
        catch {
            warnings.append(.init("\(primaryDataDescription), but an empty \(resourceDescription) directory could not be removed: \(error.localizedDescription)"))
        }
        return warnings
    }

    public static func load(
        from wrapper: FileWrapper?,
        logicalName: (String) -> String?,
        nameIsValid: (String) -> Bool = PackageResourceDirectory.isValidPathComponent
    ) -> [String: SBJResourceContent] {
        guard let wrappers = wrapper?.fileWrappers else { return [:] }
        var result: [String: SBJResourceContent] = [:]
        for (filename, child) in wrappers {
            guard let name = logicalName(filename), nameIsValid(name),
                  let resource = SBJResourceContent(storageFileWrapper: child, filename: filename)
            else { continue }
            result[name] = resource
        }
        return result
    }

    public static func load(
        from directory: URL,
        logicalName: (String) -> String?,
        nameIsValid: (String) -> Bool = PackageResourceDirectory.isValidPathComponent,
        allowsPackages: Bool
    ) -> [String: SBJResourceContent] {
        var isDirectory: ObjCBool = false
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue,
              let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isPackageKey, .contentTypeKey],
                options: [.skipsHiddenFiles]
              )
        else { return [:] }

        var result: [String: SBJResourceContent] = [:]
        for url in files {
            let filename = url.lastPathComponent
            guard let name = logicalName(filename), nameIsValid(name),
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isPackageKey, .contentTypeKey]),
                  values.isRegularFile == true || (allowsPackages && values.isPackage == true)
            else { continue }

            let wrapper: FileWrapper?
            if values.isPackage == true {
                wrapper = try? FileWrapper(url: url, options: [])
            } else if let data = try? Data(contentsOf: url) {
                wrapper = FileWrapper(regularFileWithContents: data)
            } else {
                wrapper = nil
            }
            guard let wrapper,
                  let resource = SBJResourceContent(
                    storageFileWrapper: wrapper,
                    filename: filename,
                    fallbackContentType: values.contentType
                  )
            else { continue }
            result[name] = resource
        }
        return result
    }

    public static func replacementWrapper(
        resources: [String: SBJResourceContent],
        nameIsValid: (String) -> Bool = PackageResourceDirectory.isValidPathComponent,
        storageFilename: (String, SBJResourceContent) -> String,
        resourceDescription: String,
        primaryDataDescription: String
    ) -> (wrapper: FileWrapper?, warnings: [PackageDocumentWriteWarning]) {
        guard !resources.isEmpty else { return (nil, []) }
        var children: [String: FileWrapper] = [:]
        var warnings: [PackageDocumentWriteWarning] = []
        for (name, resource) in resources.sorted(by: { $0.key < $1.key }) {
            guard nameIsValid(name) else {
                warnings.append(.init("\(primaryDataDescription), but \(resourceDescription) ‘\(name)’ has an invalid storage name and was not written."))
                continue
            }
            children[storageFilename(name, resource)] = resource.storageFileWrapper()
        }
        return (children.isEmpty ? nil : FileWrapper(directoryWithFileWrappers: children), warnings)
    }

    public static func existingWrapper(
        at url: URL,
        resourceDescription: String,
        primaryDataDescription: String
    ) -> (wrapper: FileWrapper?, warnings: [PackageDocumentWriteWarning]) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return (nil, [])
        }
        do { return (try FileWrapper(url: url, options: []), []) }
        catch {
            return (nil, [.init("\(primaryDataDescription), but the existing \(resourceDescription) could not be preserved: \(error.localizedDescription)")])
        }
    }

    public static func removeIfEmpty(_ directory: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else { return }
        if try fileManager.contentsOfDirectory(atPath: directory.path).isEmpty {
            try fileManager.removeItem(at: directory)
        }
    }
}
