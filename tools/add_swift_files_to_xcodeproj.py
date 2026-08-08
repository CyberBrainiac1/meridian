"""Add Swift source files to an .xcodeproj that were created outside Xcode.

A file on disk is invisible to the build until it appears in FOUR places in
project.pbxproj: PBXFileReference, PBXBuildFile, the enclosing PBXGroup's
children, and the target's PBXSourcesBuildPhase. Miss any one and the symbol
simply "cannot be found in scope" at compile time with no hint that the file
exists — which has now happened three separate times in this project
(Secrets.xcconfig, UrgentAlertOverlay.swift, and the medication work).

    python tools/add_swift_files_to_xcodeproj.py \
        meridian_care/MeridianCare.xcodeproj \
        meridian_care/MeridianCare/Residents/ResidentDetailView.swift ...

Paths are repo-relative. Files already present are skipped, so this is safe
to re-run. Groups are matched by the directory name the file sits in; if no
matching group exists the script refuses rather than guessing, because a
silently misplaced file is exactly the failure mode this exists to prevent.
"""

from __future__ import annotations

import re
import sys
import uuid
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def new_id(existing: set[str]) -> str:
    while True:
        candidate = uuid.uuid4().hex[:24].upper()
        if candidate not in existing:
            existing.add(candidate)
            return candidate


def add_files(project_path: Path, swift_files: list[Path]) -> int:
    pbxproj = project_path / "project.pbxproj"
    text = pbxproj.read_text()
    existing_ids = set(re.findall(r"\b([0-9A-F]{24})\b", text))
    added = 0

    for swift in swift_files:
        name = swift.name
        if re.search(rf"\b{re.escape(name)}\b", text):
            print(f"  skip  {name} (already in project)")
            continue

        group_name = swift.parent.name
        # Match `XXXX /* GroupName */ = {` ... `path = GroupName;` so we
        # attach to the real group rather than the first name collision.
        group_match = re.search(
            r"([0-9A-F]{24}) /\* " + re.escape(group_name) + r" \*/ = \{\s*"
            r"isa = PBXGroup;\s*children = \(\s*",
            text,
        )
        if not group_match:
            print(f"  FAIL  {name}: no PBXGroup named '{group_name}' — add it in Xcode first")
            return -1

        file_ref = new_id(existing_ids)
        build_ref = new_id(existing_ids)

        text = text.replace(
            "/* Begin PBXFileReference section */",
            "/* Begin PBXFileReference section */\n"
            f'\t\t{file_ref} /* {name} */ = {{isa = PBXFileReference; '
            f'lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = "<group>"; }};',
            1,
        )
        text = text.replace(
            "/* Begin PBXBuildFile section */",
            "/* Begin PBXBuildFile section */\n"
            f"\t\t{build_ref} /* {name} in Sources */ = {{isa = PBXBuildFile; "
            f"fileRef = {file_ref} /* {name} */; }};",
            1,
        )

        # Re-find the group: the two inserts above shifted every offset.
        group_match = re.search(
            r"([0-9A-F]{24}) /\* " + re.escape(group_name) + r" \*/ = \{\s*"
            r"isa = PBXGroup;\s*children = \(\s*",
            text,
        )
        insert_at = group_match.end()
        text = text[:insert_at] + f"\t\t\t\t{file_ref} /* {name} */,\n" + text[insert_at:]

        sources_match = re.search(
            r"isa = PBXSourcesBuildPhase;\s*buildActionMask = \d+;\s*files = \(\s*", text
        )
        if not sources_match:
            print(f"  FAIL  {name}: no PBXSourcesBuildPhase found")
            return -1
        insert_at = sources_match.end()
        text = text[:insert_at] + f"\t\t\t\t{build_ref} /* {name} in Sources */,\n" + text[insert_at:]

        print(f"  add   {name} -> group '{group_name}'")
        added += 1

    pbxproj.write_text(text)
    return added


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)

    project_path = (REPO_ROOT / sys.argv[1]).resolve()
    if not (project_path / "project.pbxproj").exists():
        raise SystemExit(f"Not an Xcode project: {project_path}")

    swift_files = []
    for raw in sys.argv[2:]:
        path = (REPO_ROOT / raw).resolve()
        if not path.exists():
            raise SystemExit(f"No such file: {path}")
        swift_files.append(path)

    print(f"{project_path.name}:")
    added = add_files(project_path, swift_files)
    if added < 0:
        raise SystemExit(1)
    print(f"\n{added} file(s) added. Verify with: plutil -lint {project_path}/project.pbxproj")


if __name__ == "__main__":
    main()
