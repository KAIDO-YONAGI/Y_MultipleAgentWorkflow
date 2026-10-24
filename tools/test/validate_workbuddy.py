import json
from io import BytesIO
from pathlib import Path
from pathlib import PurePosixPath
import re
import sys
from zipfile import ZipFile

import yaml


def fail(message: str) -> None:
    raise SystemExit(message)


package_path = Path(sys.argv[1]).resolve()
manifest_path = Path(sys.argv[2]).resolve()
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
skill_name = str(manifest["skillName"])

with ZipFile(package_path) as archive:
    names = [name.rstrip("/") for name in archive.namelist() if name.rstrip("/")]
    top_levels = {name.split("/", 1)[0] for name in names}
    if top_levels != {skill_name}:
        fail(f"Archive must contain only the top-level Skill directory: {top_levels}")

    prefix = f"{skill_name}/"
    unsafe_paths = [
        name
        for name in names
        if "\\" in name
        or any(part in ("", ".", "..") for part in PurePosixPath(name).parts)
    ]
    if unsafe_paths:
        fail(f"WorkBuddy archive contains unsafe paths: {unsafe_paths[:5]}")

    too_deep = [
        name
        for name in names
        if len(PurePosixPath(name[len(prefix) :]).parts) > 2
    ]
    if too_deep:
        fail(f"Skill files exceed the supported two-directory depth: {too_deep[:5]}")

    skill_path = prefix + "SKILL.md"
    license_path = prefix + "LICENSE"
    archive_manifest_path = prefix + "distribution-manifest.json"
    template_archive_path = prefix + "templates/workflow-template.zip"
    if any(
        path not in names
        for path in (
            skill_path,
            license_path,
            archive_manifest_path,
            template_archive_path,
        )
    ):
        fail(
            "WorkBuddy archive is missing SKILL.md, LICENSE, distribution manifest, "
            "or template archive."
        )

    archive_manifest = json.loads(archive.read(archive_manifest_path).decode("utf-8"))
    if archive_manifest != manifest:
        fail("Packaged distribution-manifest.json does not match the release manifest.")

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
    expected_positioning = (
        "可路由、可维护、可跨会话复用的工作知识",
        "多个 Agent 共用工作区时，用租约协调并发修改",
    )
    if any(text not in metadata["description_zh"] for text in expected_positioning):
        fail("WorkBuddy Chinese description does not match the approved positioning.")

    required = {
        prefix + "references/configuration-method.md",
        prefix + "references/doc-maintenance.md",
        prefix + "references/distribution.md",
        prefix + "scripts/Initialize-Workflow.ps1",
        prefix + "scripts/Test-WorkflowConfiguration.ps1",
        prefix + "scripts/Update-WorkflowInstance.ps1",
        prefix + "scripts/WorkflowTemplate.ps1",
    }
    missing = required.difference(names)
    if missing:
        fail(f"WorkBuddy archive is missing required files: {sorted(missing)}")
    if any(name.startswith(prefix + "assets/") or name.startswith(prefix + "agents/") for name in names):
        fail("WorkBuddy archive contains unsupported source layout directories.")

    with ZipFile(BytesIO(archive.read(template_archive_path))) as templates:
        template_names = set(templates.namelist())
        unsafe_template_paths = [
            name
            for name in template_names
            if "\\" in name
            or PurePosixPath(name).is_absolute()
            or any(part in ("", ".", "..") for part in PurePosixPath(name).parts)
        ]
        if unsafe_template_paths:
            fail(f"Embedded template archive contains unsafe paths: {unsafe_template_paths[:5]}")
        if not {
            "Workflow/Scripts/WorkingAgent.ps1",
            "WorkingAgent/.gitignore",
        }.issubset(template_names):
            fail("Embedded template archive is missing required workflow assets.")

    skill_text = archive.read(skill_path).decode("utf-8")
    if (
        "templates/workflow-template.zip" not in skill_text
        or "cooperative protocol" not in skill_text
        or "filesystem lock" not in skill_text
    ):
        fail("Packaged Skill is missing its template or lease-boundary disclosure.")
    for reference in (
        "@references/configuration-method.md",
        "@references/doc-maintenance.md",
    ):
        if reference not in skill_text:
            fail(f"WorkBuddy Skill does not load its reference: {reference}")

print("WorkBuddy package metadata and layout are valid")
