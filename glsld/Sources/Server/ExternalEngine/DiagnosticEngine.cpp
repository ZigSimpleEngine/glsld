#include "pch.hpp"
#include "DiagnosticEngine.hpp"

#include <cctype>
#include <cstddef>
#include <cstdlib>
#include <algorithm>
#include <array>
#include <charconv>
#include <format>
#include <fstream>
#include <mutex>
#include <ranges>
#include <system_error>
#include <utility>

#include <Utils/Utils.hpp>

namespace glsld {
    namespace {
        std::string FindGlslc() {
            const char* vksdk = std::getenv("VULKAN_SDK");
            if (vksdk != nullptr) {
#ifdef _WIN64
                const auto path = std::filesystem::path(vksdk) / "Bin" / "glslc.exe";
#else
                const auto path = std::filesystem::path(vksdk) / "bin" / "glslc";
#endif
                if (std::filesystem::exists(path)) {
                    return path.string();
                }
            }

#ifdef _WIN64
            return "glslc.exe";
#else
            return "glslc";
#endif
        }

        std::string FindGlslangValidator() {
            const char* vksdk = std::getenv("VULKAN_SDK");
            if (vksdk != nullptr) {
#ifdef _WIN64
                const auto path = std::filesystem::path(vksdk) / "Bin" / "glslangValidator.exe";
#else
                const auto path = std::filesystem::path(vksdk) / "bin" / "glslangValidator";
#endif
                if (std::filesystem::exists(path)) {
                    return path.string();
                }
            }

#ifdef _WIN64
            return "glslangValidator.exe";
#else
            return "glslangValidator";
#endif
        }
    }

    DiagnosticEngine::DiagnosticEngine()
        : glslc_path_{ FindGlslc() }
        , glslang_validator_path_{ FindGlslangValidator() }
    {
        thread_ = std::jthread([this]() -> void { Run(); });
    }

    DiagnosticEngine::~DiagnosticEngine() {
        Stop();
    }

    void DiagnosticEngine::SetCallback(Callback callback) {
        callback_ = std::move(callback);
    }

    void DiagnosticEngine::Submit(DiagnosticTask task) {
        {
            std::lock_guard lock(mutex_);
            queue_.push(std::move(task));
        }
        condition_.notify_one();
    }

    void DiagnosticEngine::Stop() {
        stop_source_.request_stop();
        condition_.notify_all();

        if (thread_.joinable()) {
            thread_.join();
        }
    }

    void DiagnosticEngine::set_glslc_path(const std::filesystem::path& filename) {
        std::lock_guard lock(mutex_);
        glslc_path_ = filename.empty() ? FindGlslc() : filename.generic_string();
    }

    void DiagnosticEngine::set_glslang_validator_path(const std::filesystem::path& filename) {
        std::lock_guard lock(mutex_);
        glslang_validator_path_ = filename.empty() ? FindGlslangValidator() : filename.generic_string();
    }

    void DiagnosticEngine::Run() {
        const auto stop_token = stop_source_.get_token();
        while (!stop_token.stop_requested()) {
            DiagnosticTask task;
            {
                std::unique_lock lock(mutex_);
                condition_.wait(lock, stop_token, [this]() -> bool {
                    return !queue_.empty();
                });

                if (stop_token.stop_requested()) {
                    return;
                }

                task = std::move(queue_.front());
                queue_.pop();
            }

            if (task.version_replica != task.version_pointer->load(std::memory_order::relaxed)) {
                continue;
            }

            auto diagnostics = Compile(task);
            if (task.version_replica == task.version_pointer->load(std::memory_order::relaxed) && callback_) {
                callback_(task.uri, task.version_replica, std::move(diagnostics));
            }
        }
    }

    namespace {
        std::vector<std::string_view> SplitLines(std::string_view text) {
            return text
                | std::views::split('\n')
                | std::views::transform([](auto&& subrange) -> std::string_view {
                      return std::string_view(subrange);
                  })
                | std::ranges::to<std::vector<std::string_view>>();
        }

        std::string_view Trim(std::string_view text) {
            const auto begin = text.find_first_not_of(" \t");
            if (begin == std::string_view::npos) {
                return {};
            }

            const auto end = text.find_last_not_of(" \t\r");
            return text.substr(begin, end - begin + 1);
        }

        bool TryParseInteger(std::string_view text, int& result) {
            const auto [ptr, ec] = std::from_chars(text.data(), text.data() + text.size(), result);
            return ec == std::errc() && ptr == text.data() + text.size();
        }

        std::string_view ExtractSymbol(std::string_view message) {
            const auto begin = message.find('\'');
            if (begin == std::string_view::npos) {
                return {};
            }

            const auto end = message.find('\'', begin + 1);
            if (end == std::string_view::npos) {
                return {};
            }

            return message.substr(begin + 1, end - begin - 1);
        }

        struct ColumnRange {
            int column{};
            int end{};
        };

        ColumnRange LocateSymbol(std::string_view source, std::string_view symbol) {
            if (symbol.empty() || source.empty()) {
                return { 0, static_cast<int>(source.size()) };
            }

            const auto pos = source.find(symbol);
            if (pos == std::string_view::npos) {
                return { 0, static_cast<int>(source.size()) };
            }

            return { static_cast<int>(pos), static_cast<int>(pos + symbol.size()) };
        }

        std::string_view GetFilename(std::string_view path) {
            const auto last_slash = path.find_last_of("\\/");
            if (last_slash == std::string_view::npos) {
                return path;
            }
            return path.substr(last_slash + 1);
        }

        bool EqualsIgnoreCase(std::string_view lhs, std::string_view rhs) {
            if (lhs.size() != rhs.size()) {
                return false;
            }

            for (auto i = 0uz; i < lhs.size(); ++i) {
                if (std::tolower(static_cast<unsigned char>(lhs[i])) !=
                    std::tolower(static_cast<unsigned char>(rhs[i])))
                {
                    return false;
                }
            }

            return true;
        }

        bool ContainsIgnoreCase(std::string_view haystack, std::string_view needle) {
            if (needle.empty())
                return true;
            if (haystack.size() < needle.size())
                return false;

            for (auto i = 0uz; i <= haystack.size() - needle.size(); ++i) {
                bool match = true;
                for (auto j = 0uz; j < needle.size(); ++j) {
                    if (std::tolower(static_cast<unsigned char>(haystack[i + j])) !=
                        std::tolower(static_cast<unsigned char>(needle[j])))
                    {
                        match = false;
                        break;
                    }
                }

                if (match) {
                    return true;
                }
            }

            return false;
        }

        struct GlslVersion {
            int  number{};
            bool is_es{};
        };

        std::optional<GlslVersion> ParseGlslVersion(std::string_view source) {
            auto IsSpace = [](char c) -> bool {
                return c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == '\f' || c == '\v';
            };

            auto i = 0uz;
            while (i < source.size()) {
                if (source[i] == '/' && i + 1 < source.size() && source[i + 1] == '/') {
                    const auto eol = source.find('\n', i + 2);
                    if (eol == std::string_view::npos) {
                        break;
                    }
                    i = eol + 1;
                    continue;
                }

                if (source[i] == '/' && i + 1 < source.size() && source[i + 1] == '*') {
                    const auto end = source.find("*/", i + 2);
                    if (end == std::string_view::npos) {
                        break;
                    }
                    i = end + 2;
                    continue;
                }

                if (source[i] != '#') {
                    ++i;
                    continue;
                }

                auto j = i + 1;
                while (j < source.size() && (source[j] == ' ' || source[j] == '\t')) {
                    ++j;
                }

                constexpr std::string_view kVersion = "version";
                if (j + kVersion.size() > source.size() || source.substr(j, kVersion.size()) != kVersion) {
                    ++i;
                    continue;
                }
                j += kVersion.size();

                if (j >= source.size() || !IsSpace(source[j])) {
                    i = j;
                    continue;
                }
                while (j < source.size() && IsSpace(source[j])) {
                    ++j;
                }

                const auto num_begin = j;
                while (j < source.size() && source[j] >= '0' && source[j] <= '9') {
                    ++j;
                }
                if (num_begin == j) {
                    i = j;
                    continue;
                }

                int number = 0;
                if (!TryParseInteger(source.substr(num_begin, j - num_begin), number)) {
                    i = j;
                    continue;
                }

                while (j < source.size() && (source[j] == ' ' || source[j] == '\t' || source[j] == '\r')) {
                    ++j;
                }

                bool is_es = false;
                if (j + 2 <= source.size() &&
                    (source[j] == 'e' || source[j] == 'E') &&
                    (source[j + 1] == 's' || source[j + 1] == 'S'))
                {
                    is_es = true;
                }

                return GlslVersion{ .number = number, .is_es = is_es };
            }

            return std::nullopt;
        }

        std::optional<std::string> ResolveEffectiveTargetEnv(
            const std::optional<std::string>& configured,
            std::string_view source)
        {
            if (configured.has_value() && !configured->empty()) {
                return configured;
            }

            const auto version = ParseGlslVersion(source);
            if (!version.has_value()) {
                return std::nullopt;
            }

            if (version->number == 100 || (version->is_es && version->number <= 300)) {
                return std::string("opengl");
            }

            return std::nullopt;
        }

        bool IsOpenglTargetEnv(const std::optional<std::string>& env) {
            return env.has_value() &&
                (*env == "opengl" || *env == "opengl4.5" || *env == "opengl_compat");
        }

        size_t FindDirectiveHash(std::string_view line, bool& in_block_comment) {
            auto i = 0uz;
            while (i < line.size()) {
                if (in_block_comment) {
                    const auto end = line.find("*/", i);
                    if (end == std::string_view::npos) {
                        return std::string_view::npos;
                    }
                    i = end + 2;
                    in_block_comment = false;
                    continue;
                }

                const char c = line[i];
                if (c == ' ' || c == '\t' || c == '\r' || c == '\f' || c == '\v') {
                    ++i;
                    continue;
                }
                if (c == '/' && i + 1 < line.size() && line[i + 1] == '/') {
                    return std::string_view::npos;
                }
                if (c == '/' && i + 1 < line.size() && line[i + 1] == '*') {
                    in_block_comment = true;
                    i += 2;
                    continue;
                }

                return (c == '#') ? i : std::string_view::npos;
            }

            return std::string_view::npos;
        }

        struct ParsedInclude {
            std::string_view name;
            bool             angled{};
        };

        std::optional<ParsedInclude> TryParseIncludeDirective(std::string_view line, size_t hash_pos) {
            auto j = hash_pos + 1;
            while (j < line.size() && (line[j] == ' ' || line[j] == '\t')) {
                ++j;
            }

            constexpr std::string_view kInclude = "include";
            if (line.size() - j < kInclude.size() || line.substr(j, kInclude.size()) != kInclude) {
                return std::nullopt;
            }
            j += kInclude.size();

            if (j >= line.size() || (line[j] != ' ' && line[j] != '\t')) {
                return std::nullopt;
            }
            while (j < line.size() && (line[j] == ' ' || line[j] == '\t')) {
                ++j;
            }

            if (j >= line.size() || (line[j] != '"' && line[j] != '<')) {
                return std::nullopt;
            }

            const char open  = line[j++];
            const char close = (open == '"') ? '"' : '>';
            const auto end   = line.find(close, j);
            if (end == std::string_view::npos) {
                return std::nullopt;
            }

            auto name = line.substr(j, end - j);
            while (!name.empty() && (name.front() == ' ' || name.front() == '\t')) {
                name.remove_prefix(1);
            }
            while (!name.empty() && (name.back() == ' ' || name.back() == '\t' || name.back() == '\r')) {
                name.remove_suffix(1);
            }

            if (name.empty()) {
                return std::nullopt;
            }

            return ParsedInclude{ .name = name, .angled = (open == '<') };
        }

        bool IsVersionDirective(std::string_view line, size_t hash_pos) {
            auto j = hash_pos + 1;
            while (j < line.size() && (line[j] == ' ' || line[j] == '\t')) {
                ++j;
            }

            constexpr std::string_view kVersion = "version";
            if (line.size() - j < kVersion.size() || line.substr(j, kVersion.size()) != kVersion) {
                return false;
            }
            j += kVersion.size();

            return j >= line.size() || line[j] == ' ' || line[j] == '\t' ||
                line[j] == '\r' || line[j] == '\n' || line[j] == '\f' || line[j] == '\v';
        }

        std::optional<int> TryParseBareLineDirective(std::string_view line, size_t hash_pos) {
            auto j = hash_pos + 1;
            while (j < line.size() && (line[j] == ' ' || line[j] == '\t')) {
                ++j;
            }

            constexpr std::string_view kLine = "line";
            if (line.size() - j < kLine.size() || line.substr(j, kLine.size()) != kLine) {
                return std::nullopt;
            }
            j += kLine.size();

            if (j >= line.size() || (line[j] != ' ' && line[j] != '\t')) {
                return std::nullopt;
            }
            while (j < line.size() && (line[j] == ' ' || line[j] == '\t')) {
                ++j;
            }

            const auto num_begin = j;
            while (j < line.size() && line[j] >= '0' && line[j] <= '9') {
                ++j;
            }
            if (num_begin == j) {
                return std::nullopt;
            }

            int number = 0;
            if (!TryParseInteger(line.substr(num_begin, j - num_begin), number)) {
                return std::nullopt;
            }

            while (j < line.size() && (line[j] == ' ' || line[j] == '\t' || line[j] == '\r')) {
                ++j;
            }
            if (j < line.size() && line[j] != '/' ) {
                return std::nullopt;
            }

            return number;
        }

        class WebGLIncludeExpander {
        public:
            WebGLIncludeExpander(std::string_view main_filename, IncludeDirectoryHandle include_dirs)
                : main_parent_(std::filesystem::path(std::string(main_filename)).parent_path())
                , main_basename_(std::filesystem::path(std::string(main_filename)).filename().generic_string())
                , include_dirs_(std::move(include_dirs))
            {
                std::error_code ec;
                main_canonical_ = std::filesystem::weakly_canonical(
                    std::filesystem::path(std::string(main_filename)), ec);
                if (ec) {
                    main_canonical_.clear();
                }
            }

            std::string Expand(std::string_view source) {
                output_.clear();
                version_injected_ = false;
                stack_.clear();
                ExpandText(source, main_basename_, main_parent_, 0);
                if (!version_injected_) {
                    output_ = "#extension GL_GOOGLE_cpp_style_line_directive : enable\n#line 1 \"" +
                        main_basename_ + "\"\n" + output_;
                }
                return std::move(output_);
            }

        private:
            static constexpr int kMaxDepth = 32;

            std::filesystem::path              main_parent_;
            std::string                        main_basename_;
            std::filesystem::path              main_canonical_;
            IncludeDirectoryHandle             include_dirs_;
            std::vector<std::filesystem::path> stack_;
            std::string                        output_;
            bool                               version_injected_{};

            static std::filesystem::path Canonical(const std::filesystem::path& path) {
                std::error_code ec;
                auto result = std::filesystem::weakly_canonical(path, ec);
                if (ec) {
                    ec.clear();
                    result = std::filesystem::absolute(path, ec);
                }
                return result;
            }

            std::optional<std::filesystem::path> Resolve(
                std::string_view name,
                bool angled,
                const std::filesystem::path& includer_parent) const
            {
                const std::filesystem::path relative{ std::string(name) };
                std::error_code ec;

                if (!angled) {
                    const auto candidate = includer_parent / relative;
                    if (std::filesystem::exists(candidate, ec) && !ec) {
                        return candidate;
                    }
                    ec.clear();
                }

                if (include_dirs_ != nullptr) {
                    for (const auto& dir : *include_dirs_) {
                        const auto candidate = dir / relative;
                        if (std::filesystem::exists(candidate, ec) && !ec) {
                            return candidate;
                        }
                        ec.clear();
                    }
                }

                return std::nullopt;
            }

            void EmitLine(std::string_view line) {
                output_.append(line.data(), line.size());
                output_ += '\n';
            }

            void ExpandText(
                std::string_view text,
                std::string_view logical_name,
                const std::filesystem::path& includer_parent,
                int depth)
            {
                bool in_block = false;
                int  logical  = 0;

                for (auto raw : SplitLines(text)) {
                    auto line = raw;
                    if (!line.empty() && line.back() == '\r') {
                        line.remove_suffix(1);
                    }

                    const auto hash = FindDirectiveHash(line, in_block);
                    if (hash == std::string_view::npos) {
                        EmitLine(line);
                        ++logical;
                        continue;
                    }

                    if (IsVersionDirective(line, hash)) {
                        EmitLine(line);
                        ++logical;
                        if (!version_injected_) {
                            version_injected_ = true;
                            EmitLine("#extension GL_GOOGLE_cpp_style_line_directive : enable");
                            output_ += std::format("#line {} \"{}\"\n", logical + 1, logical_name);
                        }
                        continue;
                    }

                    if (const auto bare = TryParseBareLineDirective(line, hash)) {
                        EmitLine(line);
                        logical = *bare - 1;
                        continue;
                    }

                    const auto include = TryParseIncludeDirective(line, hash);
                    if (!include.has_value()) {
                        EmitLine(line);
                        ++logical;
                        continue;
                    }

                    ++logical;

                    if (depth >= kMaxDepth) {
                        output_ += std::format("#error glsld: #include depth exceeded \"{}\"\n", include->name);
                        continue;
                    }

                    const auto resolved = Resolve(include->name, include->angled, includer_parent);
                    if (!resolved.has_value()) {
                        output_ += std::format("#error glsld: cannot resolve #include {} \"{}\"\n",
                                              include->angled ? "<>" : "\"\"", include->name);
                        continue;
                    }

                    const auto canonical = Canonical(*resolved);
                    if ((!main_canonical_.empty() && canonical == main_canonical_) ||
                        std::ranges::contains(stack_, canonical))
                    {
                        output_ += std::format("#error glsld: cyclic #include \"{}\" skipped\n", include->name);
                        continue;
                    }

                    const auto loaded = Utils::LoadSource(*resolved);
                    if (!loaded.has_value()) {
                        output_ += std::format("#error glsld: cannot read #include \"{}\" ({})\n",
                                              include->name, loaded.error());
                        continue;
                    }

                    const auto child_name = resolved->filename().generic_string();
                    output_ += std::format("#line 1 \"{}\"\n", child_name);
                    stack_.push_back(canonical);
                    ExpandText(*loaded, child_name, resolved->parent_path(), depth + 1);
                    stack_.pop_back();
                    output_ += std::format("#line {} \"{}\"\n", logical + 1, logical_name);
                }
            }
        };

        std::vector<Diagnostic> ParseGlslangOutput(
            std::string_view output,
            std::string_view main_basename,
            std::string_view original_source)
        {
            std::vector<Diagnostic> results;
            const auto source_lines = SplitLines(original_source);

            for (auto raw : SplitLines(output)) {
                const auto line = Trim(raw);
                if (line.empty()) {
                    continue;
                }

                DiagnosticSeverity severity{};
                std::string_view   rest{};
                if (line.starts_with("ERROR: ")) {
                    severity = DiagnosticSeverity::kError;
                    rest     = line.substr(7);
                } else if (line.starts_with("WARNING: ")) {
                    severity = DiagnosticSeverity::kWarning;
                    rest     = line.substr(9);
                } else {
                    continue;
                }

                if (rest.size() >= 2 && rest[1] == ':' &&
                    ((rest[0] >= 'A' && rest[0] <= 'Z') || (rest[0] >= 'a' && rest[0] <= 'z')))
                {
                    rest = rest.substr(2);
                }

                const auto first_colon = rest.find(':');
                if (first_colon == std::string_view::npos) {
                    continue;
                }

                const auto file_part = Trim(rest.substr(0, first_colon));
                const auto after     = rest.substr(first_colon + 1);
                const auto second_colon = after.find(':');
                if (second_colon == std::string_view::npos) {
                    continue;
                }

                const auto line_part = Trim(after.substr(0, second_colon));
                const auto message   = Trim(after.substr(second_colon + 1));
                if (message.empty()) {
                    continue;
                }

                int line_num = 0;
                if (!TryParseInteger(line_part, line_num)) {
                    continue;
                }

                bool is_main = false;
                if (!file_part.empty()) {
                    bool numeric = true;
                    for (const char ch : file_part) {
                        if (ch < '0' || ch > '9') {
                            numeric = false;
                            break;
                        }
                    }
                    is_main = numeric || EqualsIgnoreCase(GetFilename(file_part), main_basename);
                }
                if (!is_main) {
                    continue;
                }

                int zero_based_line = line_num - 1;
                if (zero_based_line < 0) {
                    zero_based_line = 0;
                }

                const auto symbol      = ExtractSymbol(message);
                const auto source_line = static_cast<std::size_t>(zero_based_line) < source_lines.size()
                                       ? source_lines[zero_based_line]
                                       : std::string_view{};

                const auto range = LocateSymbol(source_line, symbol);

                results.push_back(Diagnostic{
                    .line          = zero_based_line,
                    .character     = range.column,
                    .end_line      = zero_based_line,
                    .end_character = range.end,
                    .severity      = severity,
                    .message       = std::string(message)
                });
            }

            return results;
        }

        std::vector<Diagnostic> ParseErrorOutput(
            std::string_view error,
            std::string_view filename,
            std::string_view source)
        {
            std::vector<Diagnostic> results;
            const auto source_lines  = SplitLines(source);
            const auto filename_base = GetFilename(filename);

            struct SeverityPattern {
                std::string_view   pattern;
                DiagnosticSeverity severity;
            };

            static constexpr std::array<SeverityPattern, 3> kPatterns{ {
                { ": error:",       DiagnosticSeverity::kError },
                { ": warning:",     DiagnosticSeverity::kWarning },
                { ": fatal error:", DiagnosticSeverity::kError }
            } };

            for (auto raw : SplitLines(error)) {
                const auto line = Trim(raw);
                if (line.empty()) {
                    continue;
                }

                // 寻找严重性标识符
                auto severity_pos   = std::string_view::npos;
                auto severity       = DiagnosticSeverity::kError;
                auto pattern_length = 0uz;

                for (const auto& pattern : kPatterns) {
                    auto pos = line.find(pattern.pattern);
                    if (pos != std::string_view::npos) {
                        if (severity_pos == std::string_view::npos || pos < severity_pos) {
                            severity_pos   = pos;
                            severity       = pattern.severity;
                            pattern_length = pattern.pattern.size();
                        }
                    }
                }

                // 如果不包含任何已知严重性前缀，说明是类似 "1 error generated." 的非诊断行，直接跳过
                if (severity_pos == std::string_view::npos) {
                    continue;
                }

                // 拆分前缀部分 [Path]:[Line] 与 消息部分 [Message]
                const auto prefix  = Trim(line.substr(0, severity_pos));
                const auto message = Trim(line.substr(severity_pos + pattern_length));

                int  zero_based_line     = 0;
                bool is_valid_diagnostic = false;

                // 从前缀末尾解析行号
                const auto last_colon = prefix.find_last_of(':');
                if (last_colon != std::string_view::npos) {
                    const auto path_part = Trim(prefix.substr(0, last_colon));
                    const auto line_part = Trim(prefix.substr(last_colon + 1));

                    int line_num = 0;
                    if (TryParseInteger(line_part, line_num)) {
                        if (EqualsIgnoreCase(GetFilename(path_part), filename_base)) {
                            zero_based_line = line_num - 1;
                            if (zero_based_line < 0) {
                                zero_based_line = 0;
                            }

                            is_valid_diagnostic = true;
                        }
                    }
                }

                if (!is_valid_diagnostic) {
                    if (ContainsIgnoreCase(line, filename_base)) {
                        zero_based_line     = 0;
                        is_valid_diagnostic = true;
                    }
                }

                if (!is_valid_diagnostic) {
                    continue;
                }

                const auto symbol      = ExtractSymbol(message);
                const auto source_line = static_cast<std::size_t>(zero_based_line) < source_lines.size()
                                       ? source_lines[zero_based_line]
                                       : std::string_view{};

                const auto range = LocateSymbol(source_line, symbol);

                results.push_back(Diagnostic{
                    .line          = zero_based_line,
                    .character     = range.column,
                    .end_line      = zero_based_line,
                    .end_character = range.end,
                    .severity      = severity,
                    .message       = std::string(message)
                });
            }

            return results;
        }
    }

    std::vector<Diagnostic> DiagnosticEngine::Compile(const DiagnosticTask& task) {
        const auto effective_env = ResolveEffectiveTargetEnv(task.target_env, task.source);
        if (IsOpenglTargetEnv(effective_env)) {
            return CompileWithGlslang(task);
        }

        std::string glslc_path;
        {
            std::shared_lock lock(mutex_);
            glslc_path = glslc_path_;
        }

        const auto extension_name = std::filesystem::path(task.filename).extension().string();
        const auto compile_path   = (std::filesystem::temp_directory_path() / std::filesystem::path(task.filename).filename()).generic_string();

        std::ofstream(compile_path, std::ios::binary) << task.source;
        const auto target_path = std::format("{}.spv", compile_path);

        auto command = std::format("\"{}\" -o {} ", glslc_path, target_path);
        if (task.shader_stage.has_value() && !task.shader_stage->empty()) {
            command += std::format("-fshader-stage={} -D_GLSLD ", *task.shader_stage);
        }

        command += std::format("-I \"{}\" ", std::filesystem::path(task.filename).parent_path().generic_string());
        for (const auto& dir : *task.include_dirs) {
            command += std::format("-I \"{}\" ", dir.generic_string());
        }

        command += std::format("\"{}\" ", compile_path);

        if (effective_env.has_value() && !effective_env->empty()) {
            command += std::format("--target-env={} ", *effective_env);
        }

        if (task.target_spv.has_value() && !task.target_spv->empty()) {
            command += std::format("--target-spv={} ", *task.target_spv);
        }

        const auto output = Utils::ExecuteCommand(command);
        std::filesystem::remove(compile_path);
        std::filesystem::remove(target_path);

        return ParseErrorOutput(output, task.filename, task.source);
    }

    std::vector<Diagnostic> DiagnosticEngine::CompileWithGlslang(const DiagnosticTask& task) {
        std::string validator_path;
        {
            std::shared_lock lock(mutex_);
            validator_path = glslang_validator_path_;
        }

        WebGLIncludeExpander expander(task.filename, task.include_dirs);
        const std::string expanded = expander.Expand(task.source);

        const auto compile_path =
            (std::filesystem::temp_directory_path() / std::filesystem::path(task.filename).filename()).generic_string();
        std::ofstream(compile_path, std::ios::binary) << expanded;

        auto command = std::format("\"{}\" ", validator_path);
        if (task.shader_stage.has_value() && !task.shader_stage->empty()) {
            command += std::format("-S {} -D_GLSLD ", *task.shader_stage);
        }
        command += std::format("\"{}\"", compile_path);

        const auto output = Utils::ExecuteCommand(command);
        std::filesystem::remove(compile_path);

        const auto main_basename = std::filesystem::path(task.filename).filename().generic_string();
        return ParseGlslangOutput(output, main_basename, task.source);
    }
}
