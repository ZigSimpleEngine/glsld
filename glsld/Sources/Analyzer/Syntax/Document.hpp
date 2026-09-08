#pragma once

#include <cstdint>
#include <atomic>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include <ankerl/unordered_dense.h>

#include <Analyzer/Ast/Ast.hpp>
#include <Analyzer/Syntax/Symbol.hpp>
#include <Analyzer/Syntax/Token.hpp>
#include <Base/FileSystem/IncludeLoader.hpp>
#include <Base/FileSystem/Source.hpp>
#include <Base/Arena.hpp>

namespace glsld {
    using BindingMap = ankerl::unordered_dense::map<SourceLocation, SymbolReferenceView, LocationHash>;

    struct MacroDefinition {
        bool               is_function{};
        Token              original_token;
        std::vector<Token> replacement_list;
        std::vector<Token> params;
    };

    struct TemplateParameter {
        std::string_view type;
        std::string_view name;
    };

    struct TemplateInfo {
        std::string_view               name;
        std::vector<TemplateParameter> parameters;
    };

    using MacroTraceMap     = ankerl::unordered_dense::map<SourceLocation, Token, LocationHash>;
    using MacroExpansionMap = ankerl::unordered_dense::map<SourceLocation, std::vector<Token>, LocationHash>;
    using MacroTable        = StringHeteroHashMap<MacroDefinition>;

    struct MacroArgumentTrace {
        Token                token;
        std::optional<Token> definition;
    };

    using MacroArgsTraceMap = ankerl::unordered_dense::map<SourceLocation, MacroArgumentTrace, LocationHash>;

    struct InactiveRegion {
        std::uint32_t begin_line{};
        std::uint32_t end_line{};
    };

    using InactiveRegionMap = ankerl::unordered_dense::map<const SourceFile*, std::vector<InactiveRegion>, SourceFileHash>;

    struct Document {
    public:
        using Builtin = std::shared_ptr<const Document>;

        struct MetadataAttachment {
            std::string filename;
            std::string cached_key;
        };

        struct NamespaceInfo {
            NamespaceInfo*                       parent{ nullptr };
            const SymbolInfo*                    symbol{ nullptr };
            StringHeteroHashMap<SymbolReference> members; // 不用 span 因为可能不连续
        };

        using NamespaceRange = ankerl::unordered_dense::map<const Scope*, NamespaceInfo*>;

        ArenaPool::Lease                arena;
        std::vector<std::string>        dependencies; // [URI]
        std::vector<Builtin>            builtins;
        std::vector<MetadataAttachment> metadata_attachments;
        std::vector<TemplateInfo>       template_info;
        std::vector<NamespaceInfo>      namespaces;
        NamespaceRange                  namespace_ranges;
        DocumentSymbols                 symbols;
        std::string                     source;
        std::vector<Token>              raw_tokens;
        std::vector<Token>              expanded_tokens;
        InactiveRegionMap               inactive_regions;
        TranslationUnitNode*            ast{ nullptr };
        BindingMap                      bindings;
        MacroTraceMap                   macro_traces;
        MacroArgsTraceMap               macro_args_traces;
        MacroExpansionMap               macro_expansions;
        MacroTable                      macro_table;
        int                             version{};

        Document()                = default;
        Document(const Document&) = delete;
        Document(Document&&)      = delete;
        ~Document()               = default;

        Document& operator=(const Document&) = delete;
        Document& operator=(Document&&)      = delete;

        SymbolReferenceView ReferenceSymbol(const SymbolReference& reference) const;

        std::string_view StoreTokenText(std::string_view text) const;
        void StoreIncludeSource(IncludeSnapshot snapshot);

        void PrepareInjectedMacros(const SourceFile* source_file);
        void InjectMacro(MacroDefinition definition);
        void InjectMacro(std::string_view name);
        void FinalizeInjectedMacros();

    private:
        StringHeteroHashMap<MacroDefinition> pending_macros_;
        std::vector<IncludeSnapshot>         include_snapshots_;
    };

    using Snapshot = std::shared_ptr<const Document>;

    struct InlayHint {
        const SourceLocation* location{ nullptr };
        std::string           label;
    };

    using VersionPointer = std::shared_ptr<const std::atomic<int>>;
}
