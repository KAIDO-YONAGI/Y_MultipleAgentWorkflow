# Third-Party Notices

This file records third-party components used by the repository or its release
tooling. It is not a replacement for the license text of any dependency.

## PyYAML

- Scope: development and test tooling only.
- Used by: `tools/test/validate_skill.py`.
- Source: the PyYAML package from the Python Package Index.
- Distribution status: PyYAML is not bundled in any client, WorkBuddy, or offline
  release ZIP.
- License: MIT License.
- Version constraint: `requirements-dev.txt`.

The current release packages do not bundle third-party runtime libraries,
images, fonts, or other external assets. When a dependency or asset is added,
record its name, version, source, license, and required notice here before
including it in a release package.
