#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ ! -x .venv/bin/python ]]; then
  echo "OpenWrite is not installed in .venv. Run: python3 -m venv .venv && .venv/bin/python -m pip install -e ." >&2
  exit 1
fi

source ./openwrite-env.sh

prompt="${*:-}"
if [[ -z "$prompt" ]]; then
  prompt="$(cat)"
fi

if [[ -z "${prompt//[[:space:]]/}" ]]; then
  echo "Usage: ./ask-openwrite.sh \"你的小说规划问题\"" >&2
  echo "   or: printf '你的问题' | ./ask-openwrite.sh" >&2
  exit 1
fi

echo "OpenWrite 正在思考，请稍等..." >&2

.venv/bin/python - "$prompt" <<'PY'
import sys

from tools.llm.client import LLMClient, LLMConfig, Message

user_prompt = sys.argv[1]

system_prompt = """
你是 OpenWrite 的小说规划助手。请用中文帮助用户做长篇小说策划。
重点输出可直接用于写作的内容：世界观机制、冲突、角色动机、场景、剧情钩子、卷纲或章节建议。
如果用户给出的是一个脑洞，请主动补全创新设定，并指出最有戏剧张力的方向。
回答要结构清晰，避免空泛口号。
""".strip()

client = LLMClient(LLMConfig.from_env())
response = client.chat(
    [
        Message(role="system", content=system_prompt),
        Message(role="user", content=user_prompt),
    ],
    temperature=0.75,
    max_tokens=4000,
    stream=False,
)
print(response.content.strip())
PY
