#include "pch.hpp"
#include "Document.hpp"

#include <utility>
#include <variant>
#include "Base/Logger.hpp"

namespace glsld {
    SymbolReferenceView Document::ReferenceSymbol(const SymbolReference& reference) const {
        if (std::holds_alternative<std::monostate>(reference)) {
            return std::monostate{};
        }

        if (std::holds_alternative<const SymbolInfo*>(reference)) {
            return std::get<const SymbolInfo*>(reference);
        }

        const auto& symbol_list = std::get<SymbolList>(reference);
        return arena->CopySpan<const SymbolInfo*>(symbol_list);
    }

    std::string_view Document::StoreTokenText(std::string_view text) const {
        return arena->CopyString(text);
    }

    void Document::StoreIncludeSource(IncludeSnapshot snapshot) {
        include_snapshots_.push_back(std::move(snapshot));
    }

    void Document::PrepareInjectedMacros(const SourceFile* source_file) {
        SourceLocation location(source_file, 0, 0);

        for (auto& [name, definition] : pending_macros_) {
            if (definition.original_token.location.source_file() == nullptr) {
                definition.original_token.location = location;
            }

            auto it = macro_table.find(name);
            if (it != macro_table.end() && it->second.original_token.location.source_file() == nullptr) {
                it->second.original_token.location = location;
            }
        }
    }

    void Document::InjectMacro(MacroDefinition definition) {
        definition.original_token.text = StoreTokenText(definition.original_token.text);

        for (auto& token : definition.replacement_list) {
            token.text = StoreTokenText(token.text);
        }

        for (auto& token : definition.params) {
            token.text = StoreTokenText(token.text);
        }

        const auto name = definition.original_token.text;
        macro_table.insert_or_assign(name, definition);
        pending_macros_.insert_or_assign(name, std::move(definition));
    }

    void Document::InjectMacro(std::string_view name) {
        InjectMacro(MacroDefinition{
            .is_function = false,
            .original_token = Token{
                .text = name,
                .type = TokenType::kIdentifier
            },
            .replacement_list = { Token{
                .text = "1",
                .type = TokenType::kNumberLiteral
            } }
        });
    }

    void Document::FinalizeInjectedMacros() {
        auto* root = symbols.root_scope();

        for (const auto& [name, definition] : pending_macros_) {
            const auto definition_location = definition.original_token.location;
            auto* node = arena->Construct<PreprocessorNode>(arena.get(), root);

            node->directive = "define";
            node->begin     = definition_location;
            node->end       = definition_location;
            node->symbol    = symbols.AddMacroSymbol(node, name, definition_location);

            node->tokens.assign_range(definition.replacement_list);
            ast->pprefs.push_back(node);
        }

        pending_macros_.clear();
    }
}
