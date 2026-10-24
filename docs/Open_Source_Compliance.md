# Open Source Distribution Compliance

This checklist covers free distribution of the repository and its generated
release packages. It is separate from the technical installation and upgrade
instructions in `Distribution_Guide.md`.

## Current repository audit

- The project license is the MIT License in the root `LICENSE` file.
- The copyright holder shown in the license is `YONAGI`; confirm that this is
  the correct legal rights holder before publishing a release.
- Client ZIPs contain the Skill, client manifest, and `LICENSE`. The offline ZIP
  additionally contains the install/update tools, documentation, notices, and
  development dependency declaration. No third-party runtime library, image,
  font, or other external asset is bundled.
- `PyYAML` is used only by the development/test validator. It is declared in
  `requirements-dev.txt`, documented in `THIRD_PARTY_NOTICES.md`, and is not
  bundled in release archives.
- Client ZIPs and the offline ZIP contain the root `LICENSE`. The distribution
  tests compare each packaged copy with the repository copy by SHA-256 and check
  that the offline archive contains the compliance materials.
- The WorkBuddy ZIP is a separate platform adapter built from the canonical Skill.
  It includes the same `LICENSE`; its Windows PowerShell execution requirement
  and Bash-to-PowerShell invocation boundary are disclosed in the packaged
  `SKILL.md`. The WorkBuddy ZIP keeps the template tree in a nested archive because
  the platform upload parser rejected paths deeper than Skill root/two path
  segments/file. The packaged initializer/updater validate entry paths, extract
  only to a unique temporary directory, and clean it after use.
- The MIT license permits free redistribution of this software subject to its
  terms, provided the distributor has the rights to the included material. That is
  separate from marketplace approval. WorkBuddy's monetization page presents
  Free/Paid options in its publication flow, but its FAQ says only paid Skills and
  experts are currently supported. Because the same page is inconsistent, verify
  the actual account workflow before claiming free marketplace publication is
  available. This uncertainty does not prevent free distribution of the repository
  and ZIP outside the marketplace under the MIT terms.
- The intended distribution is free and open source. Do not convert the Skill into
  a paid listing to work around marketplace eligibility; if the live workflow does
  not accept a free listing, distribute the source and ZIP outside the marketplace.
- Marketplace claims and package checks are deliberately separate: a structurally
  valid ZIP is not evidence of platform approval or listing eligibility.
- `VERSION`, `distribution-manifest.json`, and `SHA256SUMS` identify and
  protect the generated release artifacts.
- The distribution boundary states that network access happens only during an
  explicitly invoked update or release command. No background update or
  telemetry feature is part of the current distribution design.

## Release gate

Before publishing a source snapshot or release archive:

1. Confirm the copyright holder name and review all newly added files.
2. Check that every bundled dependency, template, image, font, and copied text
   has a documented source and a license compatible with redistribution.
3. Add any required attribution or notice to `THIRD_PARTY_NOTICES.md`.
4. Check the repository and archive contents for credentials, private paths,
   temporary files, generated test output, and unrelated user data.
5. Run the Skill metadata validator and the distribution regression suite.
6. Build the release and verify that every archive contains `LICENSE`, then
   validate the WorkBuddy ZIP structure and run its packaged initialization smoke test.
7. Confirm current WorkBuddy submission, content, and pricing options in the live
   account workflow; do not infer free-listing eligibility from the ZIP validator,
   one publishing-screen selector, or the MIT license.
8. Publish the matching `SHA256SUMS` file with the archives.
9. Keep release notes clear about supported clients, prerequisites, known
   limitations, and the fact that MIT software is provided without warranty.

## Change control

When adding a dependency or asset, do not copy it into `src/` or a release
package until its provenance and redistribution terms are recorded. If an
asset has its own license or attribution requirement, preserve that notice
alongside the asset and mention it in `THIRD_PARTY_NOTICES.md`.

This checklist is operational guidance, not legal advice. Platform-specific
terms, privacy obligations, and local legal requirements still apply to the
person or organization publishing a release.

## Platform references

- [WorkBuddy Skill documentation](https://open.workbuddy.cn/en/docs/skill)
- [WorkBuddy Skill monetization documentation](https://open.workbuddy.cn/en/docs/monetization)

The monetization wording was checked on 2026-10-24. Recheck it before submitting a
listing because platform rules and account eligibility can change.
