"""Regenerate the macOS frames, icon, and controls from the project artwork."""
from pathlib import Path

from PIL import Image
from pet_surfaces import assets


ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Resources"
FRAME_WIDTH = 192
FRAME_HEIGHT = 208
ROW_LENGTHS = (6, 8, 8, 4, 5, 8, 6, 6, 6, 8, 8)


def build_frames():
    frames = RESOURCES / "Frames"
    frames.mkdir(parents=True, exist_ok=True)
    with Image.open(ROOT / "artwork/spritesheet.png") as image:
        sheet = image.convert("RGBA")
    expected_size = (max(ROW_LENGTHS) * FRAME_WIDTH, len(ROW_LENGTHS) * FRAME_HEIGHT)
    if sheet.size != expected_size:
        raise ValueError(f"Expected spritesheet size {expected_size}, got {sheet.size}")
    for row, length in enumerate(ROW_LENGTHS):
        for col in range(length):
            left, top = col * FRAME_WIDTH, row * FRAME_HEIGHT
            frame = sheet.crop((left, top, left + FRAME_WIDTH, top + FRAME_HEIGHT))
            frame.save(frames / f"{row}-{col}.png", optimize=True)


def build_icon():
    with Image.open(RESOURCES / "Frames/0-0.png") as image:
        pet = image.convert("RGBA")
    pet = pet.crop(pet.getbbox())
    pet.thumbnail((920, 920))
    scale = min(920 / pet.width, 920 / pet.height)
    size = (round(pet.width * scale), round(pet.height * scale))
    pet = pet.resize(size, Image.Resampling.LANCZOS)
    icon = Image.new("RGBA", (1024, 1024))
    icon.alpha_composite(pet, ((1024 - pet.width) // 2, (1024 - pet.height) // 2))
    icon.save(RESOURCES / "Loopy.icns", format="ICNS")


if __name__ == "__main__":
    build_frames()
    build_icon()
    assets(RESOURCES / "UI")
