"""
Configure the [repo_build.msbuild] section of repo.toml based on the detected
Visual Studio version. Called by build.bat before repo build runs.

VS2026 (v18) is the default/preferred path. VS2022 is the fallback.

Both VS2026 and VS2022 are configured identically when using the v142 toolchain:
  - vs_version = "vs2019": premake5 uses PlatformToolset=v142, giving _MSC_VER<1930
    so Boost auto-links to vc142 libs (matching USD deps). premake5 also doesn't
    know "vs18" (VS2026), so vs2019 is the correct action for both cases.
  - vs_path = <VS install path>: repo_build can find the installation even though
    VS year doesn't match the "vs2019" version string it expects.
  - msvc_version = "v142": forces MSVC 14.29.x instead of the VS default compiler,
    giving _MSC_VER<1930 → Boost links vc142 libs matching the USD deps.
"""

import os
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO_TOML = os.path.join(REPO_ROOT, "repo.toml")


def build_msbuild_section(vs_label: str, vs_path: str) -> str:
    escaped_path = vs_path.replace("\\", "\\\\")
    return (
        "[repo_build.msbuild]\n"
        "# auto-configured by build.bat - do not edit manually\n"
        "link_host_toolchain = true\n"
        f'vs_version = "vs2019" # premake5 action for PlatformToolset=v142; USD Boost deps are vc142\n'
        f'vs_path = "{escaped_path}" # {vs_label} install with v142 toolchain\n'
        f'msvc_version = "v142" # MSVC 14.29 → _MSC_VER<1930 → Boost vc142 (matches USD deps)\n'
    )


def update_repo_toml(vs_label: str, vs_path: str):
    with open(REPO_TOML, "r", encoding="utf-8") as f:
        content = f.read()

    # Find the [repo_build.msbuild] section and extract CI token lines.
    # The section runs from [repo_build.msbuild] to the next top-level [section].
    section_match = re.search(
        r"(\[repo_build\.msbuild\].*?)(\n\[(?!\[)|\Z)", content, re.DOTALL
    )
    if not section_match:
        print(f"WARNING: [repo_build.msbuild] section not found in {REPO_TOML}")
        return

    old_section = section_match.group(1)
    # Preserve CI token override lines
    ci_lines = [
        line for line in old_section.splitlines()
        if '"token:in_ci==true"' in line
    ]

    new_section = build_msbuild_section(vs_label, vs_path)
    if ci_lines:
        new_section += "\n".join(ci_lines) + "\n"

    new_content = content.replace(old_section, new_section)
    with open(REPO_TOML, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(f"Configured repo.toml [repo_build.msbuild] for {vs_label}: {vs_path}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: configure_vs.py <vs_label> <vs_path>")
        print("  vs_label: e.g. 'VS2026' or 'VS2022'")
        print("  vs_path:  path to VS installation root")
        sys.exit(1)

    update_repo_toml(sys.argv[1], sys.argv[2])
