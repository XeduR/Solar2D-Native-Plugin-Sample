-- Project-wide luacheck config. luacheck resolves its config from the
-- working directory upward, so this covers luacheck runs from the project
-- root; sample/.luacheckrc covers runs from inside the sample.

max_line_length = 160

-- Use Lua 5.1 as base (Solar2D uses 5.1)
std = "lua51"

-- Bundled headers and build outputs are never linted
exclude_files = { "build/**", "build-*/**", "dist/**", "external/**", ".scratch/**", ".tools/**" }

-- Sample project (Solar2D app)
files["sample/"] = {
    globals = {
        "application",
        "audio",
        "display",
        "easing",
        "graphics",
        "media",
        "native",
        "network",
        "physics",
        "Runtime",
        "system",
        "timer",
        "transition",
    },
    ignore = {
        "212/self",
        "212/event",
        "212/_",
        "212/_*",
    },
}
