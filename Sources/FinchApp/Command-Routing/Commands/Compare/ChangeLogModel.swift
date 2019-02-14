//
//  ChangeLogModel.swift
//  FinchApp.swift
//
//  Created by Dan Loman on 7/5/18.
//  Copyright © 2018 DHL. All rights reserved.
//

import class Basic.Process
import FinchCore
import Foundation

protocol ChangeLogModelType {
    func versions(app: App, env: Environment) throws -> (old: Version, new: Version)
    func changeLog(options: CompareCommand.Options, app: App, env: Environment) throws -> String
}

final class ChangeLogModel: ChangeLogModelType {
    typealias Options = CompareCommand.Options

    private struct OutputInfo {
        fileprivate var version: String?
        fileprivate var releaseManager: Contributor?
        fileprivate var sections: [Section] = []
        fileprivate var footer: String?
        fileprivate var header: String?
        fileprivate var contributorHandlePrefix: String = ""
    }

    private let resolver: VersionResolving
    private let service: ChangeLogInfoServiceType
    private let stdIn: FileHandle

    init(
        resolver: VersionResolving = VersionsResolver(),
        service: ChangeLogInfoServiceType = ChangeLogInfoService(),
        stdIn: FileHandle = .standardInput) {
        self.resolver = resolver
        self.service = service
        self.stdIn = stdIn
    }

    func changeLog(options: Options, app: App, env: Environment) throws -> String {
        let outputInfo: OutputInfo = try self.outputInfo(for: options, app: app, env: env)

        var output = ""

        if let value = outputInfo.header {
            output.append(value)
        }

        if let value = outputInfo.version {
            output.append(version(value))
        }

        if let value = outputInfo.releaseManager {
            output.append(formatted(contributorHandlePrefix: outputInfo.contributorHandlePrefix, releaseManager: value))
        }

        outputInfo.sections.forEach {
            output.append($0.output)
        }

        if let value = outputInfo.footer {
            output.append(value)
        }

        return output
    }

    func versions(app: App, env: Environment) throws -> (old: Version, new: Version) {
        return try resolver.versions(
            from: try service.versionsString(app: app, env: env)
        )
    }

    private func outputInfo(for options: Options, app: App, env: Environment) throws -> OutputInfo {
        let configuration = app.configuration
        let rawChangeLog: String = try options.useStdIn ?
            stdInChangeLog() :
            service.changeLog(options: options, app: app, env: env)
        let version: String? = try versionHeader(options: options, app: app, env: env)
        let releaseManager: Contributor? = self.releaseManager(options: options, configuration: configuration)

        let transformers = TransformerFactory(configuration: configuration).initialTransformers

        let linesComponents = filteredLines(input: rawChangeLog, using: transformers)
            .compactMap { rawLine in
                LineComponents(
                    rawLine: rawLine,
                    configuration: configuration,
                    normalizeTags: options.normalizeTags
                )
            }

        var sections: [Section] = configuration
            .formatConfig
            .sectionInfos
            .map { Section(configuration: configuration, info: $0, linesComponents: []) }

        let tagToIndex: [String: Int] = sections
            .enumerated()
            .reduce([:]) { partial, next in
                var map = partial
                next.element.info.tags.forEach { tag in
                    map.updateValue(next.offset, forKey: tag)
                }
                return map
            }

        for components in linesComponents {
            let tag = components.tags.first(where: tagToIndex.keys.contains) ?? "*"
            guard let index = tagToIndex[tag] else {
                continue
            }
            let section = sections[index]

            sections[index] = section.inserting(lineComponents: components)
        }

        return .init(
            version: version,
            releaseManager: releaseManager,
            sections: sections.filter { !$0.info.excluded && !$0.linesComponents.isEmpty },
            footer: configuration.formatConfig.footer,
            header: configuration.formatConfig.header,
            contributorHandlePrefix: configuration.contributorHandlePrefix
        )
    }

    // Normalizes input/removes
    private func filteredLines(input: String, using transformers: [Transformer]) -> [String] {
        // Input must be sorted for regex to remove consecutive matching lines (cherry-picks)
        let sortedInput = input
            .components(separatedBy: "\n")
            .sorted(by: "@@@(.*)@@@")
            .joined(separator: "\n")

        return transformers
            .reduce(sortedInput) { $1.transform(text: $0) }
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
    }

    private func version(_ version: String) -> String {
        return """

        # \(version)

        """
    }

    private func formatted(contributorHandlePrefix: String, releaseManager: Contributor) -> String {
        return """

        ### Release Manager

         - \(contributorHandlePrefix)\(releaseManager.handle)

        """
    }

    private func versionHeader(options: Options, app: App, env: Environment) throws -> String? {
        guard !options.noShowVersion else {
            return nil
        }

        let versionHeader: String = options.versions.new.description

        guard let buildNumber = try service.buildNumber(options: options, app: app, env: env) else {
            return versionHeader
        }

        return versionHeader + " (\(buildNumber))"
    }

    private func releaseManager(options: Options, configuration: Configuration) -> Contributor? {
        guard let email = options.releaseManager else {
            return nil
        }

        return configuration.contributors.first { $0.email == email }
    }

    private func stdInChangeLog() throws -> String {
        return try stdIn.readFileContents()
    }
}
