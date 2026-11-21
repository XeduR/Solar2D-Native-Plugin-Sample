-- luacheck: no global

max_line_length = 160

std = "lua51"

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
}

-- 212 = unused argument
ignore = {
    "212/self",
    "212/event",
    "212/_",
    "212/_*",
}
