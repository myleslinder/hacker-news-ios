//
//  HTMLUtilities.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-23.
//

import Foundation

// MARK: - HTML

func styleHtmlText(_ text: AttributedString?) -> AttributedString? {
    var output = AttributedString()
    if let text {
        for run in text.runs {
            var substr = text[run.range]
            let fontName = run.uiKit.font?.fontName
            if let fontName {
                if fontName.lowercased().contains("italic") {
                    substr[AttributeScopes.SwiftUIAttributes.FontAttribute.self] = .body.italic()
                } else if fontName.lowercased().contains("courier") {
                    substr[AttributeScopes.SwiftUIAttributes.FontAttribute.self] = .body.monospaced()
                } else {
                    substr[AttributeScopes.SwiftUIAttributes.FontAttribute.self] = .body
                }
            }
            output += substr
        }
    }
    output.foregroundColor = .primary
    return output
}

func htmlStringToNSAttributedString(_ html: String) -> NSAttributedString? {
    let newHtml = html
        .replacingOccurrences(of: "<p>", with: "<span>")
        .replacingOccurrences(of: "</p>", with: "</span>")
        .replacingOccurrences(of: "</span>((?=.)(?!<span><pre>))", with: "<br><br></span>", options: .regularExpression)
    if let ns = try? NSAttributedString(data: Data(newHtml.utf8), options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil) {
        return ns
    }
    return nil
}

@propertyWrapper
struct HTMLText: Equatable, Hashable, Decodable {
    
    private(set) var htmlText: AttributedString?

    var text: String? = .none
    
    var wrappedValue: String? {
        get { text }
        set {
            text = newValue
            if let text,
                let ns = htmlStringToNSAttributedString(text),
                let html = try? AttributedString(ns, including: AttributeScopes.UIKitAttributes.self)
            {
                htmlText = styleHtmlText(html)
            }
        }
    }
    
    var projectedValue: AttributedString? {
        get { htmlText }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.text = .none
        } else {
            self.text = try container.decode(String?.self)
            if let text, let ns = htmlStringToNSAttributedString(text), let html = try? AttributedString(ns, including: AttributeScopes.UIKitAttributes.self) {
                htmlText = styleHtmlText(html)
            }
        }
    }

    init(_ text: String?) {
        self.text = text
    }
    
}
