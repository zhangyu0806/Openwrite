#!/usr/bin/env bash
set -euo pipefail

# Local OpenWrite LLM configuration loader.
# Reads keys/models/base URLs from the user's private secure-notes file at runtime.
# This file intentionally contains no secrets.
#
# Supported secret-file formats:
#   1) Structured multi-model (current): lines like
#        DEFAULT_MODEL: gpt-5.5
#        DEFAULT_BASE_URL: http://.../v1
#        DEFAULT_API_KEY: sk-...
#        WRITER_MODEL: claude-sonnet-5   (writer-role override -> LLM_MODEL_WRITER)
#        OUTLINE_MODEL: gpt-5.5          (outline-role override -> LLM_MODEL_OUTLINE)
#      Prefix DEFAULT_ maps to global LLM_*; any other PREFIX_ maps to LLM_*_PREFIX.
#   2) Legacy single-model: bare Endpoint/Model/API Key lines (heuristic parse).

secret_file="${OPENWRITE_SECRET_FILE:-$HOME/secure-notes/openwrite-llm-key-2026-07-07.txt}"

if [[ ! -r "$secret_file" ]]; then
  echo "OpenWrite secret file is missing or unreadable: $secret_file" >&2
  return 1 2>/dev/null || exit 1
fi

trim() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  v="${v%\"}"; v="${v#\"}"
  v="${v%\'}"; v="${v#\'}"
  printf '%s' "$v"
}

structured=0
legacy_base_url=""
legacy_model=""
legacy_api_key=""

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line="$(trim "$raw_line")"
  [[ -z "$line" || "${line:0:1}" == "#" ]] && continue

  key=""
  if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*[:=](.*)$ ]]; then
    key="${BASH_REMATCH[1]}"
    value="$(trim "${BASH_REMATCH[2]}")"
  else
    value="$line"
  fi

  upper_key="$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')"

  case "$upper_key" in
    DEFAULT_PROVIDER)  structured=1; export LLM_PROVIDER="${LLM_PROVIDER:-$value}" ;;
    DEFAULT_BASE_URL)  structured=1; export LLM_BASE_URL="${LLM_BASE_URL:-$value}" ;;
    DEFAULT_MODEL)     structured=1; export LLM_MODEL="${LLM_MODEL:-$value}" ;;
    DEFAULT_API_KEY)   structured=1; export LLM_API_KEY="${LLM_API_KEY:-$value}" ;;
    *_PROVIDER)        structured=1; role="${upper_key%_PROVIDER}"; export "LLM_PROVIDER_${role}=${value}" ;;
    *_BASE_URL)        structured=1; role="${upper_key%_BASE_URL}"; export "LLM_BASE_URL_${role}=${value}" ;;
    *_MODEL)           structured=1; role="${upper_key%_MODEL}";    export "LLM_MODEL_${role}=${value}" ;;
    *_API_KEY)         structured=1; role="${upper_key%_API_KEY}";  export "LLM_API_KEY_${role}=${value}" ;;
    *)
      lower="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
      if [[ "$value" == http://* || "$value" == https://* ]]; then
        legacy_base_url="$value"
      elif [[ "$value" == sk-* || "$value" == sk_* ]]; then
        legacy_api_key="$value"
      elif [[ "$lower" == *gpt* || "$lower" == *claude* || "$lower" == *glm* || "$lower" == *sonnet* || "$lower" == *opus* || "$lower" == *haiku* ]]; then
        legacy_model="$value"
      fi
      ;;
  esac
done < "$secret_file"

if [[ "$structured" -eq 0 ]]; then
  if [[ -z "$legacy_api_key" || -z "$legacy_model" || -z "$legacy_base_url" ]]; then
    echo "Failed to parse OpenWrite LLM settings from $secret_file" >&2
    return 1 2>/dev/null || exit 1
  fi
  export LLM_BASE_URL="${LLM_BASE_URL:-$legacy_base_url}"
  export LLM_MODEL="${LLM_MODEL:-$legacy_model}"
  export LLM_API_KEY="${LLM_API_KEY:-$legacy_api_key}"
fi

if [[ -z "${LLM_API_KEY:-}" || -z "${LLM_MODEL:-}" || -z "${LLM_BASE_URL:-}" ]]; then
  echo "Failed to resolve default OpenWrite LLM settings from $secret_file" >&2
  return 1 2>/dev/null || exit 1
fi

export LLM_PROVIDER="${LLM_PROVIDER:-openai}"
export LLM_TEMPERATURE="${LLM_TEMPERATURE:-0.75}"
export LLM_MAX_TOKENS="${LLM_MAX_TOKENS:-24000}"
export LLM_TIMEOUT_SECONDS="${LLM_TIMEOUT_SECONDS:-600}"
export LLM_MAX_RETRIES="${LLM_MAX_RETRIES:-1}"
