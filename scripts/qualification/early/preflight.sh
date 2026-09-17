#!/usr/bin/env bash
# Offline preflight for the early-probe (Q12/Q13) isolated environment manifest.
# Reads two local files and nothing else: no network, provider, engine or R2 call, and no
# provisioning. It checks that references are named; it cannot check that they exist,
# are authorized or work — that stays operator attestation, and the full deployment
# preflight belongs to Q01. Keep real manifests untracked (e.g. beside *.local.md).
# Output lines: "INVALID: <path>: <reason>", "HOLD: <input> missing", then one verdict;
# a secret-looking key prints as <redacted-key>, and any other key is JSON-escaped, so a key
# holding a newline or escape sequence cannot print a line of its own. Exit codes: 0 every
# reference named (not a PASS), or usage when -h/--help is the sole argument; 2 usage error
# (-h/--help beside any other argument included) or unreadable/non-JSON manifest, including
# one nested more than 32 levels deep; 3 schema file missing, or using an unsupported
# keyword or keyword form ($ref beside other keywords or outside #/$defs/, additionalProperties
# other than false, a type other than object/array/string, a pattern outside the subset
# below); 4 manifest invalid (shape, tuple count, duplicate key, secret-looking value or
# key); 10 host reservation missing; 11 credential reference missing; 12 test-mutation
# authorization missing; 13 another required reference missing, including a tuple's
# harness or harness_version. INVALID wins over HOLD; among holds the lowest code wins.
# Patterns run as Python re under an ECMA-262 subset: one final unescaped $ (read as \Z),
# \s only inside a [...] class (read as the ECMA-262 whitespace set), no other letter or
# digit escape and no . outside a class; anything else exits 3. Not translated: a class
# opening with ] and (?...) groups, which the shipped schema does not use; other keyword
# values are trusted to have the form the shipped schema gives them.
# The secret check is a heuristic, not a scanner. It flags known token prefixes, any run
# of 64 hex digits (the R2 secret access key shape; this also rejects a sha256 digest used
# as a reference) and any 32+ character run of [A-Za-z0-9+/=_-] mixing upper case, lower
# case and digits. It misses shorter or single-case secrets and ones split by other
# punctuation, and it fails closed on some legitimate references (e.g. host:rk-01).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA="$SCRIPT_DIR/../../../schemas/qualification/early-environment.json"
MANIFEST=""
if [[ $# -eq 1 && ( "$1" == -h || "$1" == --help ) ]]; then echo "usage: $0 --manifest FILE [--schema FILE]"; exit 0; fi
while (($#)); do
  case "$1" in
    --manifest) [[ $# -ge 2 ]] || { echo "preflight: --manifest requires a value" >&2; exit 2; }
      MANIFEST="$2"; shift 2 ;;
    --schema) [[ $# -ge 2 ]] || { echo "preflight: --schema requires a value" >&2; exit 2; }
      SCHEMA="$2"; shift 2 ;;
    -h|--help) echo "preflight: $1 is accepted only as the sole argument" >&2; exit 2 ;;
    *) echo "preflight: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$MANIFEST" ]] || { echo "preflight: --manifest is required" >&2; exit 2; }

python3 - "$SCHEMA" "$MANIFEST" <<'PY'
import json, re, sys
KNOWN = {'$schema', '$id', 'title', 'description', '$defs', '$ref', 'type', 'required', 'properties',
         'additionalProperties', 'const', 'enum', 'pattern', 'minItems', 'maxItems', 'items', 'contains', 'allOf'}
TYPES = {'object': dict, 'array': list, 'string': str}
HOLD_CODES = {'host_reservation_ref': 10, 'credential_refs': 11, 'test_mutation_authorization_ref': 12}
SECRET = re.compile(r'-----BEGIN|AGE-SECRET-KEY-|\b[sr]k-[A-Za-z0-9]|\bgh[pousr]_|github_pat_|\bxox[abpr]-|\bAKIA[0-9A-Z]{12}|\beyJ[A-Za-z0-9_-]{8}|[0-9A-Fa-f]{64}')
WS = r'\t\n\x0b\x0c\r \xa0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff'  # ECMA-262 \s
invalid, holds, dups = [], [], []

def unsupported(what):
    print(f"preflight: unsupported schema {what}", file=sys.stderr); sys.exit(3)

def regex(p):
    out, cls, i = '', False, 0
    while i < len(p):
        c, n = p[i], p[i + 1:i + 2]
        if c == '\\':
            if n.isalnum() and not (cls and n == 's'): unsupported(f"pattern escape {json.dumps(c + n)}")
            out += WS if n == 's' else c + n; i += 2; continue
        if c == '$' and i != len(p) - 1: unsupported("pattern form: $ before the end")
        if c == '.' and not cls: unsupported("pattern form: . outside a class")
        out += r'\Z' if c == '$' else c; cls = c == '[' or (cls and c != ']'); i += 1
    try:
        return re.compile(out)
    except re.error as e:
        unsupported(f"pattern form: {e}")

def lint(s):
    if bad := set(s) - KNOWN:
        unsupported(f"keyword(s) {sorted(bad)}")
    if '$ref' in s and set(s) - {'$ref', 'title', 'description'}:
        unsupported("form: keyword beside $ref")
    if '$ref' in s and s['$ref'] not in {f"#/$defs/{k}" for k in schema.get('$defs', {}) if not set(k) & set('/~')}:
        unsupported("form: $ref outside #/$defs/")
    if s.get('type', 'object') not in TYPES:
        unsupported("form: unsupported type")
    if s.get('additionalProperties', False) is not False:
        unsupported("form: additionalProperties other than false")
    if 'pattern' in s:
        regex(s['pattern'])
    for sub in [*s.get('properties', {}).values(), *s.get('$defs', {}).values(), *s.get('allOf', []), *(s[k] for k in ('items', 'contains') if k in s)]:
        lint(sub)

def unique(pairs):
    seen = {}
    for k, v in pairs:
        if k in seen: dups.append(k)
        seen[k] = v
    return seen

def depth(v):
    stack, deepest = [(v, 1)], 0
    while stack:
        x, d = stack.pop(); deepest = max(deepest, d)
        stack += [(y, d + 1) for y in (x.values() if isinstance(x, dict) else x if isinstance(x, list) else ())]
    return deepest

try:
    schema = json.load(open(sys.argv[1], encoding='utf-8'))
except (OSError, ValueError) as e:
    print(f"preflight: cannot read schema: {e}", file=sys.stderr); sys.exit(3)
try:
    lint(schema)
except (AttributeError, TypeError, RecursionError) as e:
    unsupported(f"form: {type(e).__name__}")
try:
    doc = json.load(open(sys.argv[2], encoding='utf-8'), object_pairs_hook=unique)
except (OSError, ValueError, RecursionError) as e:
    print(f"preflight: cannot read manifest: {e}", file=sys.stderr); sys.exit(2)
if depth(doc) > 32:
    print("preflight: cannot read manifest: nested more than 32 levels deep", file=sys.stderr); sys.exit(2)

def check(s, v, path, out):
    if '$ref' in s:
        return check(schema['$defs'][s['$ref'][8:]], v, path, out)
    if 'type' in s and not isinstance(v, TYPES[s['type']]):
        out.append(('invalid', path, f"expected {s['type']}"))
        return out
    if 'const' in s and v != s['const']:
        out.append(('invalid', path, f"must be {s['const']!r}"))
    if 'enum' in s and v not in s['enum']:
        out.append(('invalid', path, f"must be one of {s['enum']}"))
    if 'pattern' in s and isinstance(v, str) and not regex(s['pattern']).search(v):
        out.append(('invalid', path, 'does not match the reference pattern'))
    for sub in s.get('allOf', []):
        check(sub, v, path, out)
    if isinstance(v, dict):
        props = s.get('properties', {})
        for key in s.get('required', []):
            if v.get(key) in (None, ''):
                out.append(('hold', f"{path}.{key}".lstrip('.'), None))
        for key, val in v.items():
            if key in props:
                if val not in (None, ''):
                    check(props[key], val, f"{path}.{key}".lstrip('.'), out)
            elif s.get('additionalProperties') is False:
                out.append(('invalid', seg(path, key), 'field not allowed'))
    if isinstance(v, list):
        if len(v) < s.get('minItems', 0) or len(v) > s.get('maxItems', len(v)):
            out.append(('invalid', path, f"needs exactly {s.get('minItems')} entries, found {len(v)}"))
        for i, item in enumerate(v):
            if 'items' in s:
                check(s['items'], item, f"{path}[{i}]", out)
        # holds are reported separately, so an entry failing only on a missing key still counts
        if 'contains' in s and not any(all(r[0] == 'hold' for r in check(s['contains'], item, path, [])) for item in v):
            out.append(('invalid', path, f"no entry matches {json.dumps(s['contains']['properties'])}"))
    return out

def looks(x):
    return bool(SECRET.search(x) or any(
        all(re.search(c, r) for c in ('[a-z]', '[A-Z]', '[0-9]')) for r in re.findall(r'[A-Za-z0-9+/=_-]{32,}', x)))

def seg(path, k):
    return f"{path}.{'<redacted-key>' if looks(k) else json.dumps(k)[1:-1]}".lstrip('.')

def secrets(v, path):
    if isinstance(v, dict):
        for k, x in v.items():
            if looks(k): invalid.append((seg(path, k), 'key looks like an inline secret value'))
            secrets(x, seg(path, k))
    elif isinstance(v, list):
        for i, x in enumerate(v): secrets(x, f"{path}[{i}]")
    elif isinstance(v, str) and looks(v):
        invalid.append((path, 'looks like an inline secret value; name a reference instead'))

invalid += [(seg('', k), 'duplicate key') for k in dups]
for kind, path, why in check(schema, doc, '', []):
    (holds.append(path) if kind == 'hold' else invalid.append((path, why)))
secrets(doc, '')
for path, why in invalid:
    print(f"INVALID: {path}: {why}")
for path in holds:
    print(f"HOLD: {path} missing")
if invalid:
    print("VERDICT: manifest invalid; no probe may run"); sys.exit(4)
if holds:
    print("VERDICT: held; no probe may run until every missing input is named")
    sys.exit(min(HOLD_CODES.get(p.split('.')[0], 13) for p in holds))
print("VERDICT: every reference named; operator attestation and live checks remain UNKNOWN")
PY
