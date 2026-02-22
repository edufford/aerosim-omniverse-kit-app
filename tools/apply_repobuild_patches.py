"""
Apply compatibility patches to repo_build for VS2022/VS2026 with v142 toolchain.

repo_build's VS detection logic has two issues when using newer VS installations with
the VS2019 v142 toolchain:

1. find_local_msbuild_msvc_version() uses hardcoded defaults vs_version="2019" and
   msbuild_version="16" which filter out VS2022 (MSBuild 17.x) and VS2026 (MSBuild 18.x),
   causing _msvs_msvc_check() to fail when msvc_version="v142" is set in repo.toml.

2. _windows_msvc_link() auto-updates settings.vs_version to the detected VS year
   (e.g. "vs2022" or "vs18" for VS2026), but we need it to stay "vs2019" so premake5
   generates PlatformToolset=v142 projects, matching the vc142 Boost libs in the USD deps.

These patches make vs_version and msbuild_version default to None (accept any VS version)
and stop the vs_version auto-update when vs_path is explicitly configured in repo.toml.

The patch strings are designed to be version-agnostic: each patch checks whether the old
pattern is present (applies it), the new pattern is already present (skips it), or neither
(warns).
"""

import os
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO_BUILD_ROOT = os.path.join(REPO_ROOT, "_repo", "deps", "repo_build")
REPO_BUILD_DIR = os.path.join(REPO_BUILD_ROOT, "omni", "repo", "build")

PATCHES = {
    "windows_utils.py": [
        (
            'vs_version: str = "2019",',
            'vs_version: str | None = None,',
        ),
        (
            'msbuild_version: str = "16",',
            'msbuild_version: str | None = None,',
        ),
    ],
    "dependencies.py": [
        (
            '        found_msvcs = find_local_msbuild_msvc_version(target_root=settings.vs_path)\n'
            '        if found_msvcs:\n'
            '            vis_studio = next(iter(next(iter(found_msvcs.values())).values()))\n'
            '            # Set vs_version to the discovered year of the path selected Visual Studio\n'
            '            # so we can call premake with the correct action.\n'
            '            found_msvc = f"vs{vis_studio.get(\'year\')}"\n'
            '            if settings.vs_version != found_msvc:\n'
            '                settings.vs_version = found_msvc\n'
            '            return\n',
            '        find_local_msbuild_msvc_version(target_root=settings.vs_path)\n'
            '        # Always return when vs_path was explicitly provided; dependencies["msvc"] is\n'
            '        # already set above. Do NOT auto-update settings.vs_version from the discovered\n'
            '        # VS year (e.g. "vs18" for VS2026) as premake5 only understands vs2019/vs2022.\n'
            '        # The user\'s configured vs_version in repo.toml is used for the premake action.\n'
            '        return\n',
        ),
    ],
}


def get_repo_build_version():
    """Read the version of the installed repo_build package, or return 'unknown'."""
    version_file = os.path.join(REPO_BUILD_ROOT, "VERSION")
    try:
        with open(version_file, "r", encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return "unknown"


def patch_file(path, patches):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    modified = False
    for old, new in patches:
        if old in content:
            content = content.replace(old, new)
            modified = True
        elif new not in content:
            print(f"  WARNING: expected pattern not found (and patch not already applied) in {os.path.basename(path)}")
            print(f"    Pattern: {old[:80]!r}...")

    if modified:
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"  Patched: {os.path.basename(path)}")
    else:
        print(f"  Already patched: {os.path.basename(path)}")


def main():
    if not os.path.isdir(REPO_BUILD_DIR):
        print(f"ERROR: repo_build not found at {REPO_BUILD_ROOT}")
        print("       Run 'tools\\packman\\packman.cmd pull deps\\repo-deps.packman.xml' first.")
        sys.exit(1)

    version = get_repo_build_version()
    print(f"Applying repo_build {version} compatibility patches for VS2022/VS2026 + v142 toolchain...")
    for filename, patches in PATCHES.items():
        path = os.path.join(REPO_BUILD_DIR, filename)
        patch_file(path, patches)
    print("Done.")


if __name__ == "__main__":
    main()
