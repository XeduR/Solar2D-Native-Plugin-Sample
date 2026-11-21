# Reads and validates metadata.json and exports the plugin identity:
# PLUGIN_NAME_DOTTED, PLUGIN_NAME_UNDERSCORED, PUBLISHER_ID, PLUGIN_VERSION,
# SOLAR2D_BUILD, and PLATFORMS (JSON array of build platforms).
# Source it, do not execute it:  . "<repo root>/tools/read_metadata.sh"

_metadata_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_metadata_file="$_metadata_dir/metadata.json"

if [ ! -f "$_metadata_file" ]; then
    echo "ERROR: metadata.json not found at $_metadata_file" >&2
    return 1 2>/dev/null || exit 1
fi

# python3 emits ready-to-eval `export` lines, or exits non-zero with a message on stderr.
if ! _metadata_exports="$(python3 - "$_metadata_file" <<'PY'
import json, re, shlex, sys

# pluginName must yield a valid luaopen_ C symbol once dots become underscores,
# and has one dot only: packaging rebuilds a dotted name from its first underscore;
# no field may contain sed metacharacters (the CI packaging step rewrites sources
# with them); publisherId no hyphens (the release repo name splits on its first hyphen).
# The identifier starts with a letter: local_build.bat's delims=_ split drops a leading underscore.
RULES = {
    "pluginName": (r"plugin\.[A-Za-z][A-Za-z0-9_]*", "plugin.<identifier> with a single dot, starting with a letter, e.g. plugin.hello"),
    "publisherId": (r"[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)*", "reverse-domain with no hyphens, e.g. com.xedur"),
    "pluginVersion": (r"[0-9A-Za-z][0-9A-Za-z._-]*", "a release tag suffix, e.g. 1.0.0"),
    "solar2dBuild": (r"[0-9]{4}\.[0-9]{4}", "a Solar2D build number in YYYY.NNNN form, e.g. 2025.3726"),
}

# platforms gates which CI build jobs run; the web and lua payloads are
# packaged regardless, so they are not tokens here.
PLATFORM_TOKENS = ["windows", "macos", "linux", "ios", "tvos", "android"]

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        data = json.load(handle)
    fields = {key: str(data[key]) for key in RULES}
    platforms = data["platforms"]
except (KeyError, ValueError) as error:
    sys.exit(f"ERROR: metadata.json is invalid or missing a field: {error}")

errors = []
for key, (pattern, hint) in RULES.items():
    if not re.fullmatch(pattern, fields[key]):
        errors.append(f"ERROR: metadata.json {key} {fields[key]!r} is invalid; expected {hint}.")

if not isinstance(platforms, list) or not platforms:
    errors.append("ERROR: metadata.json platforms must be a non-empty array.")
else:
    unknown = [token for token in platforms if token not in PLATFORM_TOKENS]
    if unknown:
        errors.append(f"ERROR: metadata.json platforms contains unknown tokens {unknown}; allowed: {PLATFORM_TOKENS}.")
    if len(set(platforms)) != len(platforms):
        errors.append("ERROR: metadata.json platforms contains duplicate tokens.")

if errors:
    sys.exit("\n".join(errors))

values = {
    "PLUGIN_NAME_DOTTED": fields["pluginName"],
    "PLUGIN_NAME_UNDERSCORED": fields["pluginName"].replace(".", "_"),
    "PUBLISHER_ID": fields["publisherId"],
    "PLUGIN_VERSION": fields["pluginVersion"],
    "SOLAR2D_BUILD": fields["solar2dBuild"],
    "PLATFORMS": json.dumps(platforms, separators=(",", ":")),
}

for key, value in values.items():
    print(f"export {key}={shlex.quote(value)}")
PY
)"; then
    return 1 2>/dev/null || exit 1
fi

eval "$_metadata_exports"
unset _metadata_dir _metadata_file _metadata_exports
