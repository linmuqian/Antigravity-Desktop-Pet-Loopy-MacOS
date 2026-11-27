"""Assemble the portable Windows Rainmeter bundle from shared Resources and windows/."""
import argparse
import shutil
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Resources"
WINDOWS = ROOT / "windows"
SHARED_LUA = (
    "json.lua",
    "Conversation.lua",
    "ConversationTitles.lua",
    "ActivityFeed.lua",
    "Motion.lua",
    "Placement.lua",
)
RUNTIME_FILES = (
    "Rainmeter.exe",
    "Rainmeter.dll",
    "Rainmeter.exe.config",
    "Rainmeter.VisualElementsManifest.xml",
    "RestartRainmeter.exe",
    "SkinInstaller.exe",
)
LANGUAGES = ("1033.dll", "2052.dll")
PLUGINS = ("FileView.dll", "RunCommand.dll")


def write_utf16(src: Path, dst: Path) -> None:
    """Write text as UTF-16LE with BOM so Rainmeter 4.5 selects Unicode Win32 conversion."""
    dst.parent.mkdir(parents=True, exist_ok=True)
    text = src.read_text(encoding="utf-8")
    dst.write_text(text, encoding="utf-16")


def build_bundle(
    rainmeter_dir: Path,
    output_dir: Path,
    third_party_dir: Path | None = None,
    make_zip: bool = False,
) -> Path:
    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    for name in RUNTIME_FILES:
        shutil.copyfile(rainmeter_dir / name, output_dir / name)
    if (rainmeter_dir / "VisualElements").is_dir():
        shutil.copytree(rainmeter_dir / "VisualElements", output_dir / "VisualElements", dirs_exist_ok=True)
    (output_dir / "Languages").mkdir(exist_ok=True)
    for name in LANGUAGES:
        shutil.copyfile(rainmeter_dir / "Languages" / name, output_dir / "Languages" / name)
    (output_dir / "Plugins").mkdir(exist_ok=True)
    for name in PLUGINS:
        shutil.copyfile(rainmeter_dir / "Plugins" / name, output_dir / "Plugins" / name)

    if third_party_dir is not None and third_party_dir.is_dir():
        shutil.copytree(third_party_dir, output_dir / "ThirdParty", dirs_exist_ok=True)

    write_utf16(WINDOWS / "Rainmeter.ini", output_dir / "Rainmeter.ini")

    skin_out = output_dir / "Skins" / "Loopy"
    res_out = skin_out / "@Resources"
    write_utf16(WINDOWS / "Skins" / "Loopy" / "Loopy.ini", skin_out / "Loopy.ini")
    write_utf16(
        WINDOWS / "Skins" / "Loopy" / "Activity" / "Activity.ini",
        skin_out / "Activity" / "Activity.ini",
    )
    write_utf16(WINDOWS / "Skins" / "Loopy" / "@Resources" / "Loopy.lua", res_out / "Loopy.lua")

    for name in SHARED_LUA:
        write_utf16(RESOURCES / name, res_out / name)

    for script_name in ("Pointer.ps1", "LaunchAntigravity.ps1", "Loopy.ico"):
        shutil.copyfile(WINDOWS / "Skins" / "Loopy" / "@Resources" / script_name, res_out / script_name)

    shutil.copytree(RESOURCES / "Frames", res_out / "Frames", dirs_exist_ok=True)
    shutil.copytree(RESOURCES / "UI", res_out / "UI", dirs_exist_ok=True)

    if make_zip:
        zip_path = output_dir.parent / "Loopy-Windows-x64.zip"
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for file in sorted(output_dir.rglob("*")):
                if file.is_file():
                    archive.write(file, file.relative_to(output_dir.parent).as_posix())
        return zip_path
    return output_dir


def main() -> None:
    parser = argparse.ArgumentParser(description="Build portable Windows Loopy Rainmeter bundle.")
    parser.add_argument("--rainmeter-dir", type=Path, required=True, help="Path to portable Rainmeter 4.5.28 directory")
    parser.add_argument("--third-party-dir", type=Path, default=None, help="Optional ThirdParty GPL source/license directory")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=ROOT / "build" / "Loopy-Windows",
        help="Destination folder for the assembled Loopy-Windows bundle",
    )
    parser.add_argument("--zip", action="store_true", help="Also write Loopy-Windows-x64.zip next to output-dir")
    args = parser.parse_args()
    result = build_bundle(args.rainmeter_dir, args.output_dir, args.third_party_dir, args.zip)
    print(f"Built {result}")


if __name__ == "__main__":
    main()
