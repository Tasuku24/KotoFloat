enum SourceLineBreaks {
    private static let lineBreaks: Set<Character> = ["\n", "\r", "\r\n", "\u{2028}"]
    private static let sentenceEndings = ".?!…。｡！？:："
    private static let opening = "([{“‘«‹「『（【〈《〔〖〘〚"
    private static let closing = ")]}'\"”’»›」』）】〉》〕〗〙〛"
    private static let attachedPunctuation = ",.;:!?%…。｡、，．；：！？)]}”’»›」』）】〉》〕〗〙〛"
    private static let continuingPunctuation = ",;–—、，；"
    private static let softHyphen: Character = "\u{00AD}"

    static func reflow(_ source: String) -> String? {
        guard var lineBreak = source.firstIndex(where: \.isNewline) else { return nil }
        var line = source[..<lineBreak]
        var result = ""
        var changed = false

        while lineBreak < source.endIndex {
            let nextStart = source.index(after: lineBreak)
            let nextBreak = source[nextStart...].firstIndex(where: \.isNewline) ?? source.endIndex
            let next = source[nextStart..<nextBreak]
            let continuation = next.drop(while: \.isWhitespace)
            let indent = next[..<continuation.startIndex]

            if lineBreaks.contains(source[lineBreak]), indent.isEmpty || indent == " ",
               let end = line.lastIndex(where: { !$0.isWhitespace }),
               let separator = separator(after: line[...end], before: continuation) {
                let endOfContent = source[end] == softHyphen ? end : source.index(after: end)
                result.append(contentsOf: line[..<endOfContent])
                result.append(contentsOf: separator)
                line = continuation
                changed = true
            } else {
                result.append(contentsOf: line)
                result.append(source[lineBreak])
                line = next
            }
            lineBreak = nextBreak
        }
        guard changed else { return nil }
        result.append(contentsOf: line)
        return result
    }

    private static func separator(after line: Substring, before next: Substring) -> String? {
        guard let last = line.last, let first = next.first,
              let lastContent = line.last(where: { !closing.contains($0) && !$0.isWhitespace }),
              !sentenceEndings.contains(lastContent),
              !line.drop(while: \.isWhitespace).starts(with: /[#>|`]/),
              !next.starts(with: /(?:[#>|`•◦▪‣●○・①-⑳]|[-+*]\s|\d+\.\s|\d+[)）、]|\(\d+\)|（\d+）)/) else { return nil }

        if last == softHyphen || last == "-" || last == "‐" {
            guard line.dropLast().last?.isLetter == true, first.isLetter else { return nil }
            return ""
        }

        guard lastContent.isLetter || lastContent.isNumber || continuingPunctuation.contains(last) || opening.contains(last)
        else { return nil }
        if opening.contains(last) || attachedPunctuation.contains(first) { return "" }

        let firstContent = next.drop(while: { opening.contains($0) || $0 == "\"" || $0 == "'" }).first
        guard let firstContent, firstContent.isLetter || firstContent.isNumber else { return nil }

        if usesUnspacedScript(last) || usesUnspacedScript(first) {
            // Short labels such as 概要 and 研究背景 often stand on their own.
            // 「概要」や「研究背景」のような短い見出しは独立した行であることが多い。
            return line.wholeMatch(of: /\s*\p{Han}{1,4}/) == nil ? "" : nil
        }
        if continuingPunctuation.contains(last) || (firstContent.isLetter && !firstContent.isUppercase) { return " " }

        // A longer line can wrap before a proper name or abbreviation.
        // 長い行では固有名詞や略語の前で折り返されることがある。
        let words = line.split(maxSplits: 4, whereSeparator: \.isWhitespace)
        return words.count == 5 && line.contains(where: \.isLowercase) ? " " : nil
    }

    private static func usesUnspacedScript(_ character: Character) -> Bool {
        String(character).contains(/[\p{Han}\p{Hiragana}\p{Katakana}々ー、，「」『』（）【】]/)
    }
}
