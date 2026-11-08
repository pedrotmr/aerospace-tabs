import Foundation

enum AerospaceConfigSyntax {
    static func parseGapNumber(_ literal: String) -> Double? {
        let pattern = #/^[+-]?[0-9](?:[0-9]|_[0-9])*(?:\.[0-9](?:[0-9]|_[0-9])*)?(?:[eE][+-]?[0-9](?:[0-9]|_[0-9])*)?$/#
        guard literal.wholeMatch(of: pattern) != nil else { return nil }
        return Double(literal.replacingOccurrences(of: "_", with: ""))
    }

    static func isGapNumberCharacter(_ character: Character) -> Bool {
        isASCIIDigit(character)
            || character == "."
            || character == "_"
            || character == "+"
            || character == "-"
            || character == "e"
            || character == "E"
    }

    static func isGapNumberStart(_ character: Character) -> Bool {
        isASCIIDigit(character) || character == "." || character == "+" || character == "-"
    }

    private static func isASCIIDigit(_ character: Character) -> Bool {
        character >= "0" && character <= "9"
    }

    static func isAssignment(_ line: String, key: String) -> Bool {
        let content = strippingInlineComment(from: line)
            .trimmingCharacters(in: .whitespaces)
        for candidate in [key, "gaps.\(key)"] where content.hasPrefix(candidate) {
            let rest = content.dropFirst(candidate.count)
                .drop(while: { $0 == " " || $0 == "\t" })
            if rest.first == "=" {
                return true
            }
        }
        return false
    }

    static func strippingInlineComment(from line: String) -> String {
        var quote: Character?
        var escaped = false

        for index in line.indices {
            let character = line[index]
            if let currentQuote = quote {
                if currentQuote == "\"" && character == "\\" && !escaped {
                    escaped = true
                    continue
                }
                if character == currentQuote && !escaped {
                    quote = nil
                }
                escaped = false
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
            } else if character == "#" {
                return String(line[..<index])
            }
        }
        return line
    }

    static func containsUnquoted(_ sought: Character, in text: String) -> Bool {
        charactersOutsideQuotes(in: text).contains(sought)
    }

    static func charactersOutsideQuotes(in text: String) -> [Character] {
        var quote: Character?
        var escaped = false
        var result: [Character] = []

        for character in strippingInlineComment(from: text) {
            if let currentQuote = quote {
                if currentQuote == "\"" && character == "\\" && !escaped {
                    escaped = true
                    continue
                }
                if character == currentQuote && !escaped {
                    quote = nil
                }
                escaped = false
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
            } else {
                result.append(character)
            }
        }
        return result
    }
}
