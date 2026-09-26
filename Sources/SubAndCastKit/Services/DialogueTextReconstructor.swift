import Foundation

public struct DialogueTextReconstructor {
    // Regex for isolated list/choice numbers (e.g. "1.", "2)", "12.", "A.", "b)")
    private static let isolatedChoiceRegex = try? NSRegularExpression(
        pattern: #"^(\d{1,3}|[A-Za-z])[\.\)]\s*$"#
    )

    // Regex for isolated bullets (e.g. "-", "•", "*")
    private static let isolatedBulletRegex = try? NSRegularExpression(
        pattern: #"^[•\-\*]\s*$"#
    )

    // Regex for lines starting with a choice number (e.g. "1. *You pull...", "2) Take...")
    private static let choiceStartRegex = try? NSRegularExpression(
        pattern: #"^(\d{1,3}|[A-Za-z])[\.\)]\s*"#
    )

    // Regex for lines starting with a bullet, dash, or asterisk action (e.g. "*You pull...*", "• Option", "- Take...")
    private static let bulletStartRegex = try? NSRegularExpression(
        pattern: #"^[•\-\*]\s*"#
    )

    // Regex for lines starting with a bracketed tag (e.g. "[JESTER]", "[MYSTIC]", "[PERSUASION]")
    private static let tagStartRegex = try? NSRegularExpression(
        pattern: #"^\[[A-Za-z0-9\s_\-]+\]\s*"#
    )

    // Regex to extract leading choice number (e.g. "2." -> 2, "3)" -> 3)
    private static let choiceNumberRegex = try? NSRegularExpression(
        pattern: #"^\s*(\d{1,3})[\.\)]"#
    )

    // Regex for lines starting with a speaker label (e.g. "Magister Siwan -", "Narrator:", "Guard #2:")
    private static let speakerStartRegex = try? NSRegularExpression(
        pattern: #"^[A-Z][a-zA-Z0-9\s]{0,25}\s*[-–—:]\s*\S"#
    )

    // Regex for word-breaking hyphens at line end (e.g. "connec-", "trans-") with letters before hyphen and no space
    private static let wordHyphenRegex = try? NSRegularExpression(
        pattern: #"[a-zA-Z]-$"#
    )

    /// Reconstructs wrapped dialogue lines by:
    /// 1. Reattaching isolated choice numbers/bullets (e.g. "2." on its own line followed by text)
    /// 2. Healing missing choice numbers before subsequent choices (e.g. recovering "1." before "2.")
    /// 3. Merging wrapped sentence lines within the same dialogue speech
    /// 4. Joining word-break hyphens ("re-" + "treat" -> "retreat")
    /// 5. Preserving sentence dashes ("Source -" + "for good!" -> "Source - for good!")
    /// 6. Preserving dialogue choice options and speaker turns on distinct lines
    public static func reconstruct(lines: [String]) -> [String] {
        let cleanedLines = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard cleanedLines.count > 1 else { return cleanedLines }

        // Phase 1: Reattach isolated prefix items (e.g. "2." or "•" sitting alone on a line)
        var attachedLines: [String] = []
        var i = 0
        while i < cleanedLines.count {
            let current = cleanedLines[i]
            if isIsolatedPrefix(current), i + 1 < cleanedLines.count {
                let next = cleanedLines[i + 1]
                attachedLines.append("\(current) \(next)")
                i += 2
            } else {
                attachedLines.append(current)
                i += 1
            }
        }

        guard attachedLines.count > 1 else { return attachedLines }

        // Phase 2: Heal missing choice numbers before subsequent numbered choices (e.g. choice 1 preceding choice 2)
        var healedLines = attachedLines
        for idx in 1..<healedLines.count {
            if let nextNum = getChoiceNumber(from: healedLines[idx]), nextNum >= 2 {
                if getChoiceNumber(from: healedLines[idx - 1]) == nil {
                    let prev = healedLines[idx - 1]
                    // If the previous line is a choice item (e.g. starts with "*" or tag) or follows a finished speaker turn
                    if isChoiceOrListItem(prev) {
                        healedLines[idx - 1] = "\(nextNum - 1). " + prev
                    }
                }
            }
        }

        // Phase 3: Merge wrapped continuation lines while preserving choices and speaker turns
        var mergedLines: [String] = []
        var currentAccumulator = healedLines[0]

        for nextLine in healedLines.dropFirst() {
            if shouldStartNewLine(nextLine: nextLine, previousLine: currentAccumulator) {
                mergedLines.append(currentAccumulator)
                currentAccumulator = nextLine
            } else {
                // Merge nextLine into currentAccumulator
                currentAccumulator = mergeLinePair(previous: currentAccumulator, next: nextLine)
            }
        }
        mergedLines.append(currentAccumulator)

        return mergedLines
    }

    public static func reconstruct(fullText: String) -> String {
        let rawLines = fullText.components(separatedBy: .newlines)
        let reconstructed = reconstruct(lines: rawLines)
        return reconstructed.joined(separator: "\n")
    }

    // MARK: - Classification Helpers

    public static func getChoiceNumber(from text: String) -> Int? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = choiceNumberRegex?.firstMatch(in: text, options: [], range: range) else { return nil }
        guard let groupRange = Range(match.range(at: 1), in: text) else { return nil }
        return Int(text[groupRange])
    }

    public static func isIsolatedPrefix(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let regex = isolatedChoiceRegex, regex.firstMatch(in: text, options: [], range: range) != nil {
            return true
        }
        if let regex = isolatedBulletRegex, regex.firstMatch(in: text, options: [], range: range) != nil {
            return true
        }
        return false
    }

    public static func isChoiceOrListItem(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let regex = choiceStartRegex, regex.firstMatch(in: text, options: [], range: range) != nil {
            return true
        }
        if let regex = bulletStartRegex, regex.firstMatch(in: text, options: [], range: range) != nil {
            return true
        }
        if let regex = tagStartRegex, regex.firstMatch(in: text, options: [], range: range) != nil {
            return true
        }
        return false
    }

    public static func isSpeakerTurn(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let regex = speakerStartRegex, regex.firstMatch(in: text, options: [], range: range) != nil {
            return true
        }
        return false
    }

    public static func endsWithTerminalPunctuation(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return false }
        return [".", "!", "?", "\"", "'", "”", "’"].contains(last)
    }

    private static func shouldStartNewLine(nextLine: String, previousLine: String) -> Bool {
        // If the next line starts a choice or bullet item (e.g. "1. ...", "• ...", "*Action*", "[TAG]"), start a new line
        if isChoiceOrListItem(nextLine) {
            return true
        }

        // If the next line is a distinct speaker turn (e.g. "Magister Siwan -", "Narrator:"), start a new line
        if isSpeakerTurn(nextLine) {
            return true
        }

        // If previous line ends with terminal punctuation and next starts with an asterisk, bracket, or quote
        if endsWithTerminalPunctuation(previousLine) {
            if nextLine.hasPrefix("*") || nextLine.hasPrefix("[") || nextLine.hasPrefix("\"") {
                return true
            }
        }

        return false
    }

    private static func mergeLinePair(previous: String, next: String) -> String {
        // Check for word-hyphenation at line end (e.g. "dis-" without space before hyphen)
        let range = NSRange(previous.startIndex..<previous.endIndex, in: previous)
        if let regex = wordHyphenRegex, regex.firstMatch(in: previous, options: [], range: range) != nil {
            // If the previous ends with a hyphen and next line starts with lowercase letter:
            if let firstChar = next.first, firstChar.isLowercase {
                let stripped = String(previous.dropLast()) // remove trailing '-'
                return stripped + next
            }
        }

        // Standard merge: if previous ends with space or next starts with punctuation
        if previous.hasSuffix(" ") {
            return previous + next
        }

        return previous + " " + next
    }

    // MARK: - Structural Alignment & Translation Formatting

    public struct LineStructure: Sendable, Equatable {
        public var choicePrefix: String?
        public var tagPrefix: String?
        public var speakerPrefix: String?
        public var isActionWrapped: Bool
        public var content: String

        public init(
            choicePrefix: String? = nil,
            tagPrefix: String? = nil,
            speakerPrefix: String? = nil,
            isActionWrapped: Bool = false,
            content: String = ""
        ) {
            self.choicePrefix = choicePrefix
            self.tagPrefix = tagPrefix
            self.speakerPrefix = speakerPrefix
            self.isActionWrapped = isActionWrapped
            self.content = content
        }
    }

    public static func parseStructure(line: String) -> LineStructure {
        var remaining = line.trimmingCharacters(in: .whitespacesAndNewlines)
        var choicePrefix: String?
        var tagPrefix: String?
        var speakerPrefix: String?

        // 1. Choice prefix: e.g. "1. ", "2) ", "• ", "- "
        let choiceRange = NSRange(remaining.startIndex..<remaining.endIndex, in: remaining)
        if let match = choiceStartRegex?.firstMatch(in: remaining, options: [], range: choiceRange), match.range.location == 0 {
            if let swiftRange = Range(match.range, in: remaining) {
                choicePrefix = String(remaining[swiftRange])
                remaining = String(remaining[swiftRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        } else if let match = bulletStartRegex?.firstMatch(in: remaining, options: [], range: choiceRange), match.range.location == 0 {
            let matchedStr = (remaining as NSString).substring(with: match.range)
            // Ensure this is a bullet and not an action enclosed in asterisks (e.g. "*Action*")
            if !matchedStr.hasPrefix("*") || !remaining.hasSuffix("*") || remaining.count <= 2 {
                if let swiftRange = Range(match.range, in: remaining) {
                    choicePrefix = String(remaining[swiftRange])
                    remaining = String(remaining[swiftRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        // 2. Tag prefix: e.g. "[PERSUASION] ", "[ROGUE] "
        let tagRange = NSRange(remaining.startIndex..<remaining.endIndex, in: remaining)
        if let match = tagStartRegex?.firstMatch(in: remaining, options: [], range: tagRange), match.range.location == 0 {
            if let swiftRange = Range(match.range, in: remaining) {
                tagPrefix = String(remaining[swiftRange])
                remaining = String(remaining[swiftRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }

        // 3. Speaker prefix: e.g. "Shadowheart: ", "Narrator: ", "Siwan - "
        let speakerRange = NSRange(remaining.startIndex..<remaining.endIndex, in: remaining)
        let speakerRegex = try? NSRegularExpression(pattern: #"^[A-Z][a-zA-Z0-9\s#]{0,25}\s*[-–—:]\s*"#)
        if let match = speakerRegex?.firstMatch(in: remaining, options: [], range: speakerRange), match.range.location == 0 {
            if let swiftRange = Range(match.range, in: remaining) {
                speakerPrefix = String(remaining[swiftRange])
                remaining = String(remaining[swiftRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }

        // 4. Action wrapped: e.g. "*Take the sword.*"
        let isActionWrapped = remaining.hasPrefix("*") && remaining.hasSuffix("*") && remaining.count >= 2

        return LineStructure(
            choicePrefix: choicePrefix,
            tagPrefix: tagPrefix,
            speakerPrefix: speakerPrefix,
            isActionWrapped: isActionWrapped,
            content: remaining
        )
    }

    public static func alignTranslation(sourceText: String, translatedText: String) -> String {
        let cleanSource = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        var cleanTranslated = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSource.isEmpty, !cleanTranslated.isEmpty else { return cleanTranslated }

        let sourceLines = cleanSource.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !sourceLines.isEmpty else { return cleanTranslated }

        // If source is multi-line, check if translated was collapsed onto fewer lines with embedded choices
        var translatedLines = cleanTranslated.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if sourceLines.count > 1 && translatedLines.count < sourceLines.count {
            let embeddedChoicePattern = try? NSRegularExpression(pattern: #"(?<=\S)\s+(\d{1,3}[\.\)]\s+|\[[A-Za-z0-9\s_\-]+\]\s+)"#)
            if let regex = embeddedChoicePattern {
                let range = NSRange(cleanTranslated.startIndex..<cleanTranslated.endIndex, in: cleanTranslated)
                cleanTranslated = regex.stringByReplacingMatches(in: cleanTranslated, options: [], range: range, withTemplate: "\n$1")
                translatedLines = cleanTranslated.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        }

        // Align each line
        var alignedLines: [String] = []
        for i in 0..<translatedLines.count {
            let srcStruct: LineStructure? = i < sourceLines.count ? parseStructure(line: sourceLines[i]) : nil
            var transLine = translatedLines[i]

            guard let structure = srcStruct else {
                alignedLines.append(transLine)
                continue
            }

            // Strip existing choice prefix from translated line if source has choice prefix
            if let _ = structure.choicePrefix {
                let r = NSRange(transLine.startIndex..<transLine.endIndex, in: transLine)
                if let match = choiceStartRegex?.firstMatch(in: transLine, options: [], range: r), match.range.location == 0 {
                    if let swiftRange = Range(match.range, in: transLine) {
                        transLine = String(transLine[swiftRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    }
                } else if let match = bulletStartRegex?.firstMatch(in: transLine, options: [], range: r), match.range.location == 0 {
                    let matchedStr = (transLine as NSString).substring(with: match.range)
                    if !matchedStr.hasPrefix("*") || !transLine.hasSuffix("*") || transLine.count <= 2 {
                        if let swiftRange = Range(match.range, in: transLine) {
                            transLine = String(transLine[swiftRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
            }

            // Strip existing tag prefix from translated line if source has tag prefix
            if let _ = structure.tagPrefix {
                let r = NSRange(transLine.startIndex..<transLine.endIndex, in: transLine)
                let generalTagRegex = try? NSRegularExpression(pattern: #"^\[.*?\]\s*"#)
                if let match = generalTagRegex?.firstMatch(in: transLine, options: [], range: r), match.range.location == 0 {
                    if let swiftRange = Range(match.range, in: transLine) {
                        transLine = String(transLine[swiftRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }

            // Strip existing speaker prefix from translated line if source has speaker prefix
            if let _ = structure.speakerPrefix {
                let r = NSRange(transLine.startIndex..<transLine.endIndex, in: transLine)
                let generalSpeakerRegex = try? NSRegularExpression(pattern: #"^[^:–—\n]{1,40}\s*[-–—:]\s*"#)
                if let match = generalSpeakerRegex?.firstMatch(in: transLine, options: [], range: r), match.range.location == 0 {
                    if let swiftRange = Range(match.range, in: transLine) {
                        transLine = String(transLine[swiftRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }

            // If source was action-wrapped, ensure translation is action-wrapped
            if structure.isActionWrapped {
                let trimmedContent = transLine.trimmingCharacters(in: .whitespaces)
                if !trimmedContent.hasPrefix("*") || !trimmedContent.hasSuffix("*") {
                    let unwrapped = trimmedContent.trimmingCharacters(in: CharacterSet(charactersIn: "*"))
                    transLine = "*\(unwrapped)*"
                }
            }

            // Re-assemble in exact order: choicePrefix + tagPrefix + speakerPrefix + transLine
            var assembled = ""
            if let choice = structure.choicePrefix {
                assembled += choice
            }
            if let tag = structure.tagPrefix {
                assembled += tag
            }
            if let speaker = structure.speakerPrefix {
                assembled += speaker
            }
            assembled += transLine

            alignedLines.append(assembled)
        }

        return alignedLines.joined(separator: "\n")
    }
}
