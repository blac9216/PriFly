#!/usr/bin/env bash
# Self-test for preflight.sh. Every manifest is synthetic, built from one complete example
# of obviously fake placeholders; secret-shaped strings are assembled at runtime so no
# literal credential shape is committed. Each case asserts its exit code AND its exact
# line, so a case cannot pass because another rule fired. The mutant pass then removes
# one rule at a time from copies of preflight.sh/the schema and requires its case to fail.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_SRC="$SCRIPT_DIR/../../../schemas/qualification/early-environment.json"
work="$(mktemp -d "${TMPDIR:-/tmp}/prifly-early-preflight-tests.XXXXXX")"
trap 'rm -rf -- "$work"' EXIT

# name|exit|line|python statement mutating the complete example manifest m; it may also set
# raw (manifest text), args (extra preflight arguments) and leak (text output must not contain)
CASES=$(cat <<'EOF'
complete example|0|VERDICT: every reference named|pass
host reservation absent|10|HOLD: host_reservation_ref missing|del m['host_reservation_ref']
host ref absent|13|HOLD: isolated_host.host_ref missing|del m['isolated_host']['host_ref']
engine path absent|13|HOLD: isolated_host.engine_socket_path missing|del m['isolated_host']['engine_socket_path']
workspace path absent|13|HOLD: isolated_host.workspace_root_path missing|del m['isolated_host']['workspace_root_path']
r2 bucket absent|13|HOLD: r2.bucket_ref missing|del m['r2']['bucket_ref']
r2 prefix absent|13|HOLD: r2.prefix missing|del m['r2']['prefix']
bootstrap identity absent|13|HOLD: bootstrap_identity_ref missing|del m['bootstrap_identity_ref']
tuples absent|13|HOLD: subscription_tuples missing|del m['subscription_tuples']
tuple account absent|13|HOLD: subscription_tuples[1].account_ref missing|del m['subscription_tuples'][1]['account_ref']
r2 credential absent|11|HOLD: credential_refs.r2 missing|del m['credential_refs']['r2']
codex credential absent|11|HOLD: credential_refs.codex-cli missing|del m['credential_refs']['codex-cli']
claude credential absent|11|HOLD: credential_refs.claude-code missing|del m['credential_refs']['claude-code']
credential ref empty|11|HOLD: credential_refs.r2.ref missing|m['credential_refs']['r2']['ref'] = ''
authorization absent|12|HOLD: test_mutation_authorization_ref missing|del m['test_mutation_authorization_ref']
envelope absent|13|HOLD: envelope missing|del m['envelope']
one tuple|4|INVALID: subscription_tuples: needs exactly 2 entries, found 1|m['subscription_tuples'].pop()
three tuples|4|INVALID: subscription_tuples: needs exactly 2 entries, found 3|m['subscription_tuples'].append(dict(m['subscription_tuples'][0]))
same harness twice|4|INVALID: subscription_tuples: no entry matches {"harness": {"const": "claude-code"}|m['subscription_tuples'][1] = dict(m['subscription_tuples'][0])
unpinned harness version|4|INVALID: subscription_tuples: no entry matches {"harness": {"const": "codex-cli"}|m['subscription_tuples'][0]['harness_version'] = '0.155.0'
metered api auth|4|INVALID: subscription_tuples[0].auth_mode: must be 'subscription'|m['subscription_tuples'][0]['auth_mode'] = 'api-key'
shared r2 prefix|4|INVALID: r2.prefix: does not match the reference pattern|m['r2']['prefix'] = 'shared/'
inline token field|4|INVALID: credential_refs.r2.token: field not allowed|m['credential_refs']['r2']['token'] = 'placeholder'
known secret shape|4|INVALID: credential_refs.r2.ref: looks like an inline secret value|m['credential_refs']['r2']['ref'] = 'AGE-SECRET-' + 'KEY-1' + 'QPZRY9X8GF2TVDW0S3JN54KHCE6MUA7L' * 2
high-entropy value|4|INVALID: subscription_tuples[1].account_ref: looks like an inline secret value|m['subscription_tuples'][1]['account_ref'] = ''.join(chr(65 + i * 7 % 26) + chr(97 + i * 11 % 26) + str(i % 10) for i in range(12))
per-probe allowance|4|INVALID: envelope.r2_requests: field not allowed|m['envelope']['r2_requests'] = 100000
per-probe scope|4|INVALID: envelope.scope: must be 'shared-cumulative'|m['envelope']['scope'] = 'per-probe'
extra field beats hold|4|INVALID: notes: field not allowed|m['notes'] = 'x'; del m['host_reservation_ref']
lowest hold code wins|11|HOLD: test_mutation_authorization_ref missing|del m['test_mutation_authorization_ref']; del m['credential_refs']['r2']
non-https authorization|4|INVALID: test_mutation_authorization_ref: does not match|m['test_mutation_authorization_ref'] = 'http://example.invalid/a'
relative path|4|INVALID: isolated_host.engine_socket_path: does not match|m['isolated_host']['engine_socket_path'] = 'run/engine.sock'
malformed ref|4|INVALID: bootstrap_identity_ref: does not match|m['bootstrap_identity_ref'] = 'bootstrap id'
wrong interactive mode|4|INVALID: subscription_tuples[0].interactive_mode: must be 'interactive'|m['subscription_tuples'][0]['interactive_mode'] = 'exec'
wrong schema id|4|INVALID: schema: must be|m['schema'] = 'prifly/qualification/early-environment/v2'
wrong field type|4|INVALID: isolated_host: expected object|m['isolated_host'] = 'host:example'
prefix trailing newline|4|INVALID: r2.prefix: does not match|m['r2']['prefix'] += '\n'
authorization trailing newline|4|INVALID: test_mutation_authorization_ref: does not match|m['test_mutation_authorization_ref'] += '\n'
reference trailing newline|4|INVALID: host_reservation_ref: does not match|m['host_reservation_ref'] += '\n'
harness version null|13|HOLD: subscription_tuples[0].harness_version missing|m['subscription_tuples'][0]['harness_version'] = None
harness absent|13|HOLD: subscription_tuples[1].harness missing|del m['subscription_tuples'][1]['harness']
secret-shaped key|4|INVALID: credential_refs.r2.<redacted-key>: key looks like|leak = 's' + 'k-proj-FAKEkey9'; m[leak] = 1; m['credential_refs']['r2'][leak] = 1
pem shape|4|INVALID: credential_refs.r2.ref: looks like|m['credential_refs']['r2']['ref'] = '-' * 5 + 'BEGIN KEY'
sk shape|4|INVALID: credential_refs.r2.ref: looks like|m['credential_refs']['r2']['ref'] = 's' + 'k-fake'
rk shape|4|INVALID: credential_refs.r2.ref: looks like|m['credential_refs']['r2']['ref'] = 'r' + 'k-fake'
github token shape|4|INVALID: credential_refs.r2.ref: looks like|m['credential_refs']['r2']['ref'] = 'gh' + 'p_fake'
github pat shape|4|INVALID: credential_refs.r2.ref: looks like|m['credential_refs']['r2']['ref'] = 'github' + '_pat_fake'
slack token shape|4|INVALID: credential_refs.r2.ref: looks like|m['credential_refs']['r2']['ref'] = 'xo' + 'xb-fake'
aws key shape|4|INVALID: credential_refs.r2.ref: looks like|m['credential_refs']['r2']['ref'] = 'AK' + 'IAFAKE0000000000'
jwt shape|4|INVALID: credential_refs.r2.ref: looks like|m['credential_refs']['r2']['ref'] = 'ey' + 'Jfakefake'
non-JSON manifest|2|preflight: cannot read manifest|raw = '{not json'
help beside manifest|2|is accepted only as the sole argument|args = ['--help']; del m['host_reservation_ref']
schema file missing|3|preflight: cannot read schema|args = ['--schema', W + '/absent.json']
unsupported schema keyword|3|unsupported schema keyword|open(W + '/s.json', 'w').write('{"format": "x"}'); args = ['--schema', W + '/s.json']
EOF
)

# run_cases PREFLIGHT SCHEMA [ONLY,NAMES]: prints PASS/FAIL per case; returns the failure count.
run_cases() {
  local preflight="$1" schema="$2" only="${3:-}" failed=0 name want line stmt got
  while IFS='|' read -r name want line stmt; do
    [[ -z "$only" || ",$only," == *",$name,"* ]] || continue
    rm -f -- "$work/m.json" "$work/m.args" "$work/m.leak"
    python3 - "$work/m.json" "$stmt" <<'PY' || { echo "SETUP-ERROR: $name" >&2; exit 2; }
import json, os, sys
W, raw, args, leak = os.path.dirname(sys.argv[1]), None, [], ''
m = {"schema": "prifly/qualification/early-environment/v1",
     "host_reservation_ref": "reservation:example-placeholder",
     "isolated_host": {"host_ref": "host:example.invalid", "engine_socket_path": "/run/prifly-example/engine.sock",
                       "workspace_root_path": "/srv/prifly-example/workspaces"},
     "r2": {"bucket_ref": "r2-bucket:example-placeholder", "prefix": "prifly-q11-example/"},
     "bootstrap_identity_ref": "bootstrap:example-factory-identity",
     "subscription_tuples": [dict(harness=h, harness_version=v, interactive_mode="interactive",
                                  model_id=f"model:example-{h}", effort="effort:example",
                                  account_ref=f"account:example-{h}", auth_mode="subscription")
                             for h, v in (("codex-cli", "0.154.0"), ("claude-code", "2.1.268"))],
     "credential_refs": {k: {"mechanism": "example-transport", "ref": f"secret-ref:example-{k}"}
                         for k in ("r2", "codex-cli", "claude-code")},
     "test_mutation_authorization_ref": "https://example.invalid/authorization/placeholder",
     "envelope": {"ref": "docs/reference/deployment-parameters.md P12a", "scope": "shared-cumulative"}}
exec(sys.argv[2])
open(sys.argv[1], 'w').write(raw if raw is not None else json.dumps(m))
open(W + '/m.args', 'w').write(''.join(a + '\n' for a in args)); open(W + '/m.leak', 'w').write(leak)
PY
    got=0; mapfile -t extra <"$work/m.args"
    bash "$preflight" --manifest "$work/m.json" --schema "$schema" "${extra[@]}" >"$work/out" 2>&1 || got=$?
    if [[ "$got" == "$want" ]] && grep -qF -- "$line" "$work/out" && ! { [[ -s "$work/m.leak" ]] && grep -qFf "$work/m.leak" "$work/out"; }; then
      echo "PASS: $name (exit $got; $(sha256sum "$work/m.json" | cut -c1-12))"
    else
      echo "FAIL: $name (expected exit $want and '$line', no leak; observed exit $got)"; sed 's/^/  | /' "$work/out"
      failed=$((failed + 1))
    fi
  done <<<"$CASES"
  return "$failed"
}

fails=0
run_cases "$SCRIPT_DIR/preflight.sh" "$SCHEMA_SRC" || fails=$?
bash "$SCRIPT_DIR/preflight.sh" --schema "$SCHEMA_SRC" >/dev/null 2>&1 && { echo "FAIL: missing --manifest accepted"; fails=$((fails + 1)); } || echo "PASS: missing --manifest is a usage error"
if bash "$SCRIPT_DIR/preflight.sh" --help >/dev/null 2>&1; then echo "PASS: sole --help prints usage (exit 0)"; else echo "FAIL: sole --help"; fails=$((fails + 1)); fi
[[ "$fails" == 0 ]] || { echo "self-test: $fails case(s) failed" >&2; exit 1; }

# Mutants: file|exact text removed or replaced|replacement|comma-separated cases that must all go red.
MUTANTS=$(cat <<'EOF'
schema|"maxItems": 2,||three tuples
schema|"minItems": 2,||one tuple
schema|{"contains": {"type": "object", "required": ["harness", "harness_version"], "properties": {"harness": {"const": "claude-code"}, "harness_version": {"const": "2.1.268"}}}}|{}|same harness twice
schema|, "harness_version": {"const": "0.154.0"}||unpinned harness version
schema|"auth_mode": {"const": "subscription"}|"auth_mode": {"type": "string"}|metered api auth
schema|"pattern": "^prifly-[a-z0-9]+(-[a-z0-9]+)+/$", ||shared r2 prefix
schema|"additionalProperties": false,\n      "required": ["mechanism", "ref"]|"required": ["mechanism", "ref"]|inline token field
schema|"additionalProperties": false,\n      "required": ["ref", "scope"]|"required": ["ref", "scope"]|per-probe allowance
schema|{"const": "shared-cumulative"}|{"type": "string"}|per-probe scope
preflight|AGE-SECRET-KEY-|AGE-SECRET-KEY-DISABLED|known secret shape
preflight|{32,}|{9999,}|high-entropy value
preflight|out.append(('hold', f"{path}.{key}".lstrip('.'), None))|pass|host reservation absent
preflight|v.get(key) in (None, '')|key not in v|credential ref empty
preflight|'credential_refs': 11|'credential_refs': 13|r2 credential absent
preflight|'test_mutation_authorization_ref': 12|'test_mutation_authorization_ref': 13|authorization absent
preflight|if invalid:|if invalid and not holds:|extra field beats hold
schema|"additionalProperties": false,\n  "required": ["schema",|"required": ["schema",|extra field beats hold
preflight|sys.exit(min(|sys.exit(max(|lowest hold code wins
schema|"pattern": "^https://[^\\s]+$", ||non-https authorization,authorization trailing newline
schema|, "pattern": "^/[A-Za-z0-9._/-]{1,255}$"||relative path
schema|, "pattern": "^[A-Za-z0-9][A-Za-z0-9._:/#@-]{0,199}$"||malformed ref,reference trailing newline
schema|"interactive_mode": {"const": "interactive"}|"interactive_mode": {"type": "string"}|wrong interactive mode
schema|"schema": {"const": "prifly/qualification/early-environment/v1"}|"schema": {"type": "string"}|wrong schema id
preflight|if 'type' in s and not isinstance(v, TYPES[s['type']]):|if False:|wrong field type
preflight|re.sub(r'\$$', r'\\Z', s['pattern'])|s['pattern']|prefix trailing newline,authorization trailing newline,reference trailing newline
preflight|all(r[0] == 'hold' for r in check(s['contains'], item, path, []))|not check(s['contains'], item, path, [])|harness version null,harness absent
preflight|'<redacted-key>' if looks(k) else k|k|secret-shaped key
preflight|if looks(k):|if False:|secret-shaped key
preflight|secrets(doc, '')|pass|known secret shape
preflight|-----BEGIN|-----BEGIN-DISABLED|pem shape
preflight|[sr]k-|[r]k-|sk shape
preflight|[sr]k-|[s]k-|rk shape
preflight|gh[pousr]_|gh[pousr]_DISABLED|github token shape
preflight|github_pat_|github_pat_DISABLED|github pat shape
preflight|xox[abpr]-|xox[abpr]-DISABLED|slack token shape
preflight|AKIA[0-9A-Z]{12}|AKIA-DISABLED|aws key shape
preflight|eyJ[A-Za-z0-9_-]{8}|eyJ-DISABLED|jwt shape
preflight|cannot read manifest: {e}", file=sys.stderr); sys.exit(2)|cannot read manifest: {e}", file=sys.stderr); sys.exit(0)|non-JSON manifest
preflight|is accepted only as the sole argument" >&2; exit 2|is accepted only as the sole argument" >&2; exit 0|help beside manifest
preflight|cannot read schema: {e}", file=sys.stderr); sys.exit(3)|cannot read schema: {e}", file=sys.stderr); sys.exit(0)|schema file missing
preflight|{sorted(bad)}", file=sys.stderr); sys.exit(3)|{sorted(bad)}", file=sys.stderr)|unsupported schema keyword
EOF
)
survived=0
while IFS='|' read -r file old new target; do
  mkdir -p "$work/mutant"; cp "$SCRIPT_DIR/preflight.sh" "$work/mutant/preflight.sh"; cp "$SCHEMA_SRC" "$work/mutant/schema.json"
  [[ "$file" == schema ]] && path="$work/mutant/schema.json" || path="$work/mutant/preflight.sh"
  python3 - "$path" "$old" "$new" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2].replace('\\n', '\n'), sys.argv[3]
text = open(path, encoding='utf-8').read()
assert text.count(old) == 1, f"mutant setup assumption broken: {old!r} not unique in {path}"
open(path, 'w', encoding='utf-8').write(text.replace(old, new))
PY
  red=0; run_cases "$work/mutant/preflight.sh" "$work/mutant/schema.json" "$target" >"$work/mutant.out" || red=$?
  if [[ "$red" != "$(tr ',' '\n' <<<"$target" | wc -l)" ]]; then
    echo "SURVIVED: removing '$old' from $file left '$target' green"; survived=$((survived + 1))
  else
    echo "KILLED: removing '$old' from $file turns '$target' red -> $(grep -m1 '^FAIL' "$work/mutant.out")"
  fi
done <<<"$MUTANTS"
[[ "$survived" == 0 ]] || { echo "self-test: $survived mutant(s) survived" >&2; exit 1; }
echo "self-test: all cases passed and every mutant was killed"
