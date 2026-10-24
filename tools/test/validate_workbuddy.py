import json
from pathlib import Path
import re
import sys
from zipfile import ZipFile

import yaml


def fail(message: str) -> None:
    raise SystemExit(message)


package_path = Path(sys.argv[1]).resolve()
manifest_path = Path(sys.argv[2]).resolve()
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
skill_name = "multiple-agent-workflow-config"

with ZipFile(package_path) as archive:
    names = [name.rstrip("/") for name in archive.namelist() if name.rstrip("/")]
    top_levels = {name.split("/", 1)[0] for name in names}
    if top_levels != {skill_name}:
        fail(f"Archive must contain only the top-level Skill directory: {top_levels}")

    prefix = f"{skill_name}/"
    skill_path = prefix + "SKILL.md"
    license_path = prefix + "LICENSE"
    if skill_path not in names or license_path not in names:
        fail("WorkBuddy archive must include SKILL.md and LICENSE.")

    frontmatter_match = re.match(
        r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|\Z)",
        archive.read(skill_path).decode("utf-8"),
        re.DOTALL,
    )
    if not frontmatter_match:
        fail("WorkBuddy SKILL.md must start with YAML frontmatter.")
    metadata = yaml.safe_load(frontmatter_match.group(1))
    for field in ("name", "description", "description_zh", "description_en", "version", "author"):
        if not isinstance(metadata.get(field), str) or not metadata[field].strip():
            fail(f"WorkBuddy metadata field is missing: {field}")
    if metadata["name"] != skill_name:
        fail("WorkBuddy Skill name does not match its directory.")
    if metadata["version"] != str(manifest["skillVersion"]):
        fail("WorkBuddy Skill version does not match distribution-manifest.json.")

    required = {
        prefix + "references/configuration-method.md",
        prefix + "references/doc-maintenance.md",
        prefix + "references/distribution.md",
        prefix + "scripts/Initialize-Workflow.ps1",
        prefix + "scripts/Test-WorkflowConfiguration.ps1",
        prefix + "scripts/Update-WorkflowInstance.ps1",
        prefix + "templates/workflow-template/Workflow/Scripts/WorkingAgent.ps1",
    }
    missing = required.difference(names)
    if missing:
        fail(f"WorkBuddy archive is missing required files: {sorted(missing)}")
    if any(name.startswith(prefix + "assets/") or name.startswith(prefix + "agents/") for name in names):
        fail("WorkBuddy archive contains unsupported source layout directories.")

    skill_text = archive.read(skill_path).decode("utf-8")
    for reference in (
        "@references/configuration-method.md",
        "@references/doc-maintenance.md",
    ):
        if reference not in skill_text:
            fail(f"WorkBuddy Skill does not load its reference: {reference}")

print("WorkBuddy package metadata and layout are valid")
