#!/usr/bin/env bash
# Offline preflight for the early-probe (Q12/Q13) isolated environment manifest.
# Reads two local files and nothing else: no network, provider, engine or R2 call, and no
# provisioning. It checks that references are named; it cannot check that they exist,
# are authorized or work — that stays operator attestation, and the full deployment
# preflight belongs to Q01. Keep real manifests untracked (e.g. beside *.local.md).
# Output lines: "INVALID: <path>: <reason>", "HOLD: <input> missing", then one verdict.
# Exit codes: 0 every reference named (not a PASS); 2 usage error or unreadable/non-JSON
# manifest; 3 schema file missing or using an unsupported keyword; 4 manifest invalid
# (shape, tuple count, inline secret-looking value); 10 host reservation missing;
# 11 credential reference missing; 12 test-mutation authorization missing; 13 another
# required reference missing. INVALID wins over HOLD; among holds the lowest code wins.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA="$SCRIPT_DIR/../../../schemas/qualification/early-environment.json"
MANIFEST=""
while (($#)); do
  case "$1" in
    --manifest) [[ $# -ge 2 ]] || { echo "preflight: --manifest requires a value" >&2; exit 2; }
      MANIFEST="$2"; shift 2 ;;
    --schema) [[ $# -ge 2 ]] || { echo "preflight: --schema requires a value" >&2; exit 2; }
      SCHEMA="$2"; shift 2 ;;
    -h|--help) echo "usage: $0 --manifest FILE [--schema FILE]"; exit 0 ;;
    *) echo "preflight: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$MANIFEST" ]] || { echo "preflight: --manifest is required" >&2; exit 2; }

python3 - "$SCHEMA" "$MANIFEST" <<'PY'
import json, re, sys
try:
    schema = json.load(open(sys.argv[1], encoding='utf-8'))
except (OSError, ValueError) as e:
    print(f"preflight: cannot read schema: {e}", file=sys.stderr); sys.exit(3)
try:
    doc = json.load(open(sys.argv[2], encoding='utf-8'))
except (OSError, ValueError) as e:
    print(f"preflight: cannot read manifest: {e}", file=sys.stderr); sys.exit(2)

KNOWN = {'$schema', '$id', 'title', 'description', '$defs', '$ref', 'type', 'required', 'properties',
         'additionalProperties', 'const', 'enum', 'pattern', 'minItems', 'maxItems', 'items', 'contains', 'allOf'}
TYPES = {'object': dict, 'array': list, 'string': str}
HOLD_CODES = {'host_reservation_ref': 10, 'credential_refs': 11, 'test_mutation_authorization_ref': 12}
SECRET = re.compile(r'-----BEGIN|AGE-SECRET-KEY-|\b(?:sk|rk)-[A-Za-z0-9]|\bgh[pousr]_|github_pat_|\bxox[abpr]-|\bAKIA[0-9A-Z]{12}|\beyJ[A-Za-z0-9_-]{8}')
invalid, holds = [], []

def check(s, v, path, out):
    if bad := set(s) - KNOWN:
        print(f"preflight: unsupported schema keyword(s) {sorted(bad)}", file=sys.stderr); sys.exit(3)
    if '$ref' in s:
        return check(schema['$defs'][s['$ref'].rsplit('/', 1)[1]], v, path, out)
    if 'type' in s and not isinstance(v, TYPES[s['type']]):
        out.append(('invalid', path, f"expected {s['type']}"))
        return out
    if 'const' in s and v != s['const']:
        out.append(('invalid', path, f"must be {s['const']!r}"))
    if 'enum' in s and v not in s['enum']:
        out.append(('invalid', path, f"must be one of {s['enum']}"))
    if 'pattern' in s and isinstance(v, str) and not re.search(s['pattern'], v):
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
                out.append(('invalid', f"{path}.{key}".lstrip('.'), 'field not allowed'))
    if isinstance(v, list):
        if len(v) < s.get('minItems', 0) or len(v) > s.get('maxItems', len(v)):
            out.append(('invalid', path, f"needs exactly {s.get('minItems')} entries, found {len(v)}"))
        for i, item in enumerate(v):
            if 'items' in s:
                check(s['items'], item, f"{path}[{i}]", out)
        if 'contains' in s and not any(not check(s['contains'], item, path, []) for item in v):
            out.append(('invalid', path, f"no entry matches {json.dumps(s['contains']['properties'])}"))
    return out

def secrets(v, path):
    if isinstance(v, dict):
        for k, x in v.items(): secrets(x, f"{path}.{k}".lstrip('.'))
    elif isinstance(v, list):
        for i, x in enumerate(v): secrets(x, f"{path}[{i}]")
    elif isinstance(v, str) and (SECRET.search(v) or any(
            all(re.search(c, r) for c in ('[a-z]', '[A-Z]', '[0-9]')) for r in re.findall(r'[A-Za-z0-9+=]{32,}', v))):
        invalid.append((path, 'looks like an inline secret value; name a reference instead'))

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
