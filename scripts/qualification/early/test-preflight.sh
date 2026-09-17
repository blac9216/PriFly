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

# name|exit|line|python statement mutating the complete example manifest m
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
EOF
)

# run_cases PREFLIGHT SCHEMA [ONLY]: prints PASS/FAIL per case; returns the failure count.
run_cases() {
  local preflight="$1" schema="$2" only="${3:-}" failed=0 name want line stmt got
  while IFS='|' read -r name want line stmt; do
    [[ -z "$only" || "$name" == "$only" ]] || continue
    rm -f -- "$work/m.json"
    python3 - "$work/m.json" "$stmt" <<'PY' || { echo "SETUP-ERROR: $name" >&2; exit 2; }
import json, sys
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
json.dump(m, open(sys.argv[1], 'w'))
PY
    got=0
    bash "$preflight" --manifest "$work/m.json" --schema "$schema" >"$work/out" 2>&1 || got=$?
    if [[ "$got" == "$want" ]] && grep -qF -- "$line" "$work/out"; then
      echo "PASS: $name (exit $got; $(sha256sum "$work/m.json" | cut -c1-12))"
    else
      echo "FAIL: $name (expected exit $want and '$line'; observed exit $got)"; sed 's/^/  | /' "$work/out"
      failed=$((failed + 1))
    fi
  done <<<"$CASES"
  return "$failed"
}

fails=0
run_cases "$SCRIPT_DIR/preflight.sh" "$SCHEMA_SRC" || fails=$?
bash "$SCRIPT_DIR/preflight.sh" --schema "$SCHEMA_SRC" >/dev/null 2>&1 && { echo "FAIL: missing --manifest accepted"; fails=$((fails + 1)); } || echo "PASS: missing --manifest is a usage error"
[[ "$fails" == 0 ]] || { echo "self-test: $fails case(s) failed" >&2; exit 1; }

# Mutants: file|exact text removed or replaced|replacement|case that must go red.
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
  if run_cases "$work/mutant/preflight.sh" "$work/mutant/schema.json" "$target" >"$work/mutant.out"; then
    echo "SURVIVED: removing '$old' from $file left '$target' green"; survived=$((survived + 1))
  else
    echo "KILLED: removing '$old' from $file turns '$target' red -> $(grep -m1 '^FAIL' "$work/mutant.out")"
  fi
done <<<"$MUTANTS"
[[ "$survived" == 0 ]] || { echo "self-test: $survived mutant(s) survived" >&2; exit 1; }
echo "self-test: all cases passed and every mutant was killed"
