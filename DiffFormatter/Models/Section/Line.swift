//
//  Line.swift
//  DiffFormatter
//
//  Created by Dan Loman on 8/15/18.
//  Copyright © 2018 DHL. All rights reserved.
//

import Foundation

struct Line {
    let tags: [String]
    let value: String

    init(configuration: Configuration, value: String) {
        self.value = value
        let outputDelimiters = configuration.delimiterConfig.output
        self.tags = matches(pattern: "\(outputDelimiters.left.escaped)([^\(outputDelimiters.left.escaped)\(outputDelimiters.right.escaped)]*)\(outputDelimiters.right.escaped)", body: value).compactMap {
            guard $0.numberOfRanges > 0 else {
                return nil
            }
            return String(range: $0.range(at: 1), in: value)
        }
    }
}

extension Line {
    func belongsTo(sectionInfo: SectionInfo) -> Bool {
        guard !sectionInfo.tags.contains("*") else {
            return true
        }

        return tags.first(where: sectionInfo.tags.contains) != nil
    }

    func placeInOwningSection(tagToSectionInfo: [String: SectionInfo], titleToSection: inout [String: Section]) {
        for tag in tags {
            if let sectionInfo = tagToSectionInfo[tag] {
                titleToSection[sectionInfo.title, default: .default(for: sectionInfo)].lines.append(value)
                return
            }
        }
        if let info = tagToSectionInfo["*"] {
            titleToSection[info.title, default: .default(for: info)].lines.append(value)
        }
    }
}
