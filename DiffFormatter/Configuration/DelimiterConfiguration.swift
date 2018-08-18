//
//  DelimiterConfiguration.swift
//  DiffFormatter
//
//  Created by Dan Loman on 8/17/18.
//  Copyright © 2018 DHL. All rights reserved.
//

import Foundation

struct DelimiterConfiguration: Codable, Equatable {
    let input: DelimiterPair
    let output: DelimiterPair

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        input = (try? container.decode(DelimiterPair.self, forKey: .input)) ?? .empty
        output = (try? container.decode(DelimiterPair.self, forKey: .output)) ?? .empty
    }

    init(input: DelimiterPair, output: DelimiterPair) {
        self.input = input
        self.output = output
    }
}

extension DelimiterConfiguration {
    static let `default`: DelimiterConfiguration = .init(input: .defaultInput, output: .defaultOutput)

    static let empty: DelimiterConfiguration = .init(input: .empty, output: .empty)
}