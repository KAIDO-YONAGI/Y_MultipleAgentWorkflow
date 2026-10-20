from pathlib import Path
import re
import sys

import yaml


def fail(message: str) -> None:
    raise SystemExit(message)


skill_root = Path(sys.argv[1]).resolve()
skill_file = skill_root / "SKILL.md"
text = skill_file.read_text(encoding="utf-8")
match = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
if not match:
    fail("SKILL.md must start with YAML frontmatter")

frontmatter = yaml.safe_load(match.group(1))
if not isinstance(frontmatter, dict):
    fail("Skill frontmatter must be a mapping")
if frontmatter.get("name") != skill_root.name:
    fail("Skill name must match its directory")
description = frontmatter.get("description")
if not isinstance(description, str) or not description.strip():
    fail("Skill description is required")

openai_file = skill_root / "agents" / "openai.yaml"
openai = yaml.safe_load(openai_file.read_text(encoding="utf-8"))
if openai.get("policy", {}).get("allow_implicit_invocation") is not True:
    fail("OpenAI metadata must enable implicit invocation")
prompt = openai.get("interface", {}).get("default_prompt", "")
if "$multiple-agent-workflow-config" not in prompt:
    fail("OpenAI default prompt must reference the Skill name")

print("Skill metadata is valid")
