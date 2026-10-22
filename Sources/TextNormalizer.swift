//
//  TextNormalizer.swift
//  StringifyTextField
//
//  Created by Anton Novichenko on 22.10.26.
//  Copyright © 2026 Anton Novichenko. All rights reserved.
//

import Foundation

/// Formats an already sanitized value for one text-field type.
struct TextNormalizer {
    struct Amount {
        var allowsDecimal: Bool
        var decimalSeparator: String
        var maxIntegerDigits: Int
        var maxFractionDigits: Int
        var groupsDigits: Bool
        
        private let digits = TextSanitizer.DecimalDigits()
        
        func isContent(_ character: Character) -> Bool {
            if digits.isDigit(character) { return true }
            guard allowsDecimal, let separator = decimalSeparatorCharacter else { return false }
            return character == separator
        }
        
        func format(_ content: String) -> String? {
            let parts = split(content)
            guard parts.accepted else { return nil }
            
            let integerDigits = normalizeLeadingZeros(parts.integer)
            guard integerDigits.count <= maxIntegerDigits else { return nil }
            if let fraction = parts.fraction, fraction.count > maxFractionDigits { return nil }
            
            let integer = grouped(integerDigits)
            guard let fraction = parts.fraction else { return integer }
            return integer + decimalSeparator + fraction
        }
        
        private struct Parts {
            var integer: String
            var fraction: String?
            var accepted: Bool
        }
        
        private func split(_ content: String) -> Parts {
            var integer = ""
            var fraction: String?
            
            for character in content {
                if digits.isDigit(character) {
                    if fraction == nil {
                        integer.append(character)
                    } else {
                        fraction?.append(character)
                    }
                    continue
                }
                
                guard allowsDecimal, let separator = decimalSeparatorCharacter, character == separator, fraction == nil else {
                    return Parts(integer: integer, fraction: fraction, accepted: false)
                }
                fraction = ""
            }
            
            return Parts(integer: integer, fraction: fraction, accepted: true)
        }
        
        private func normalizeLeadingZeros(_ digits: String) -> String {
            let stripped = digits.drop(while: { $0 == "0" })
            if stripped.isEmpty {
                return digits.isEmpty ? "" : "0"
            }
            return String(stripped)
        }
        
        private func grouped(_ digits: String) -> String {
            guard groupsDigits, digits.count > 3 else { return digits }
            
            var grouped = ""
            for (offset, character) in digits.reversed().enumerated() {
                if offset > 0, offset.isMultiple(of: 3) {
                    grouped.append(" ")
                }
                grouped.append(character)
            }
            return String(grouped.reversed())
        }
        
        private var decimalSeparatorCharacter: Character? {
            guard decimalSeparator.count == 1 else { return nil }
            return decimalSeparator.first
        }
    }
    
    struct Grouped {
        var limit: Int
        var stride: Int
        var separator: Character = " "
        
        func format(_ content: String) -> String? {
            guard content.count <= limit else { return nil }
            guard stride > 0, content.count > stride else { return content }
            
            var grouped = ""
            for (offset, character) in content.enumerated() {
                if offset > 0, offset.isMultiple(of: stride) {
                    grouped.append(separator)
                }
                grouped.append(character)
            }
            return grouped
        }
    }
    
    struct ExpirationDate {
        private let digits = TextSanitizer.DecimalDigits()
        
        func format(_ content: String) -> String? {
            guard content.count <= 4, content.allSatisfy(digits.isDigit) else { return nil }
            
            switch content.count {
            case 0, 1:
                return content
            case 2:
                return content + "/"
            default:
                return "\(content.prefix(2))/\(content.dropFirst(2))"
            }
        }
    }
    
    struct Limited {
        var limit: Int
        
        func format(_ content: String) -> String? {
            guard content.count <= limit else { return nil }
            return content
        }
    }
}
