#!/usr/bin/env python3
"""Generate and validate ZenTimer timer background preset catalog assets."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
CATALOG_ROOT = REPO_ROOT / "assets" / "timer-backgrounds"
SOURCE_DIR = CATALOG_ROOT / "source"
METADATA_PATH = SOURCE_DIR / "metadata.json"
CATALOG_PATH = CATALOG_ROOT / "catalog.v1.json"
THUMB_DIR = CATALOG_ROOT / "variants" / "thumbs"
PHONE_DIR = CATALOG_ROOT / "variants" / "phone"
LEGACY_IDS = [
    "gateway-forest",
    "gateway-woman",
    "journey-mushrooms",
    "journey-outlook",
    "journey-woman",
    "meditator-gold",
    "meditator-moon",
    "psychedelic-mind",
    "psychedelic-priests",
    "shamanism-shaman",
    "shamanism-spirit-quest",
    "shamanism-warrior",
    "subconscious-darkness",
    "subconscious-falling",
    "subconscious-water",
    "subconscious-waterman",
]


@dataclass(frozen=True)
class VariantSpec:
    role: str
    width: int
    height: int
    directory: Path
    quality: int


VARIANTS = [
    VariantSpec("thumbnail", 360, 640, THUMB_DIR, 80),
    VariantSpec("phone", 1290, 2796, PHONE_DIR, 86),
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate committed catalog and variants without rewriting files.",
    )
    args = parser.parse_args()

    try:
        require_tools(check_only=args.check)
        errors = validate_source_metadata()
        if args.check:
            errors.extend(validate_committed_catalog())
        else:
            generate_catalog()
            errors.extend(validate_committed_catalog())
    except CatalogError as error:
        errors = [str(error)]

    if errors:
        print("Timer background catalog validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    if args.check:
        print("Timer background catalog validation passed.")
    else:
        print(f"Generated {relative(CATALOG_PATH)}.")
    return 0


def require_tools(check_only: bool) -> None:
    if image_identify_command() is None:
        raise CatalogError("Missing required tool: magick or identify")
    if not check_only and image_convert_command() is None:
        raise CatalogError("Missing required tool: magick or convert")
    if not check_only and shutil.which("cwebp") is None:
        raise CatalogError("Missing required tool: cwebp")


def validate_source_metadata() -> list[str]:
    errors: list[str] = []
    metadata = load_metadata()
    presets = metadata.get("presets")
    if not isinstance(presets, list):
        return ["source/metadata.json must contain a presets array"]

    seen: set[str] = set()
    for index, preset in enumerate(presets):
        prefix = f"source preset {index + 1}"
        if not isinstance(preset, dict):
            errors.append(f"{prefix}: must be an object")
            continue

        preset_id = preset.get("id")
        if not isinstance(preset_id, str) or not preset_id:
            errors.append(f"{prefix}: missing id")
            continue
        if preset_id in seen:
            errors.append(f"{prefix}: duplicate id {preset_id}")
        seen.add(preset_id)

        for key in ("sourceFile", "displayName", "category"):
            if not isinstance(preset.get(key), str) or not preset[key]:
                errors.append(f"{preset_id}: missing {key}")
        if not isinstance(preset.get("sortOrder"), int):
            errors.append(f"{preset_id}: sortOrder must be an integer")
        if not isinstance(preset.get("isListed"), bool):
            errors.append(f"{preset_id}: isListed must be a boolean")
        offset = preset.get("defaultOffsetY")
        if not isinstance(offset, (int, float)) or not -1.0 <= float(offset) <= 1.0:
            errors.append(f"{preset_id}: defaultOffsetY must be between -1.0 and 1.0")

        source_file = preset.get("sourceFile")
        if isinstance(source_file, str):
            source_path = (SOURCE_DIR / source_file).resolve()
            if not is_inside(source_path, SOURCE_DIR.resolve()):
                errors.append(f"{preset_id}: sourceFile escapes source directory")
            elif not source_path.exists():
                errors.append(f"{preset_id}: source file missing: {source_file}")

    missing_legacy = sorted(set(LEGACY_IDS) - seen)
    if missing_legacy:
        errors.append(f"metadata missing legacy IDs: {', '.join(missing_legacy)}")
    return errors


def generate_catalog() -> None:
    metadata = load_metadata()
    CATALOG_ROOT.mkdir(parents=True, exist_ok=True)
    for variant in VARIANTS:
        variant.directory.mkdir(parents=True, exist_ok=True)

    existing_generated_at = existing_catalog_generated_at()
    generated_at = existing_generated_at or datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

    presets: list[dict[str, Any]] = []
    for preset in sorted(metadata["presets"], key=lambda item: (item["sortOrder"], item["id"])):
        source_path = SOURCE_DIR / preset["sourceFile"]
        generated_variants = []
        for variant in VARIANTS:
            output_path = variant.directory / f"{preset['id']}.webp"
            render_variant(source_path, output_path, variant)
            generated_variants.append(variant_metadata(output_path, variant))

        phone_variant = next(item for item in generated_variants if item["role"] == "phone")
        phone_path = CATALOG_ROOT / phone_variant["path"]
        presets.append(
            {
                "id": preset["id"],
                "displayName": preset["displayName"],
                "category": preset["category"],
                "sortOrder": preset["sortOrder"],
                "isListed": preset["isListed"],
                "accentHex": average_hex(phone_path),
                "bottomLuminance": round(bottom_luminance(phone_path), 4),
                "defaultOffsetY": float(preset["defaultOffsetY"]),
                "variants": generated_variants,
            }
        )

    catalog = {
        "schemaVersion": 1,
        "generatedAt": generated_at,
        "presets": presets,
    }
    CATALOG_PATH.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def render_variant(source_path: Path, output_path: Path, variant: VariantSpec) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        intermediate = Path(temp_dir) / "variant.png"
        convert_command = image_convert_command()
        if convert_command is None:
            raise CatalogError("Missing required tool: magick or convert")
        run(
            convert_command
            + [
                str(source_path),
                "-auto-orient",
                "-resize",
                f"{variant.width}x{variant.height}^",
                "-gravity",
                "center",
                "-extent",
                f"{variant.width}x{variant.height}",
                str(intermediate),
            ]
        )
        run(["cwebp", "-quiet", "-q", str(variant.quality), str(intermediate), "-o", str(output_path)])


def variant_metadata(output_path: Path, variant: VariantSpec) -> dict[str, Any]:
    width, height = image_dimensions(output_path)
    return {
        "role": variant.role,
        "path": relative(output_path, CATALOG_ROOT),
        "mimeType": "image/webp",
        "width": width,
        "height": height,
        "byteSize": output_path.stat().st_size,
        "sha256": sha256(output_path),
    }


def validate_committed_catalog() -> list[str]:
    errors: list[str] = []
    if not CATALOG_PATH.exists():
        return [f"missing {relative(CATALOG_PATH)}"]

    try:
        catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return [f"catalog JSON invalid: {error}"]

    if catalog.get("schemaVersion") != 1:
        errors.append("catalog schemaVersion must be 1")
    if not isinstance(catalog.get("generatedAt"), str) or not catalog["generatedAt"]:
        errors.append("catalog generatedAt must be a string")

    presets = catalog.get("presets")
    if not isinstance(presets, list):
        errors.append("catalog presets must be an array")
        return errors

    seen: set[str] = set()
    for index, preset in enumerate(presets):
        if not isinstance(preset, dict):
            errors.append(f"catalog preset {index + 1}: must be object")
            continue
        preset_id = preset.get("id")
        if not isinstance(preset_id, str) or not preset_id:
            errors.append(f"catalog preset {index + 1}: missing id")
            continue
        if preset_id in seen:
            errors.append(f"{preset_id}: duplicate catalog id")
        seen.add(preset_id)

        for key in ("displayName", "category", "accentHex"):
            if not isinstance(preset.get(key), str) or not preset[key]:
                errors.append(f"{preset_id}: missing {key}")
        if not isinstance(preset.get("sortOrder"), int):
            errors.append(f"{preset_id}: sortOrder must be integer")
        if not isinstance(preset.get("isListed"), bool):
            errors.append(f"{preset_id}: isListed must be boolean")
        if not isinstance(preset.get("bottomLuminance"), (int, float)):
            errors.append(f"{preset_id}: bottomLuminance must be numeric")
        offset = preset.get("defaultOffsetY")
        if not isinstance(offset, (int, float)) or not -1.0 <= float(offset) <= 1.0:
            errors.append(f"{preset_id}: defaultOffsetY must be between -1.0 and 1.0")

        variants = preset.get("variants")
        if not isinstance(variants, list):
            errors.append(f"{preset_id}: variants must be array")
            continue
        roles = {variant.get("role") for variant in variants if isinstance(variant, dict)}
        for required_role in ("thumbnail", "phone"):
            if required_role not in roles:
                errors.append(f"{preset_id}: missing {required_role} variant")
        for variant in variants:
            if isinstance(variant, dict):
                errors.extend(validate_variant(preset_id, variant))
            else:
                errors.append(f"{preset_id}: variant must be object")

    missing_legacy = sorted(set(LEGACY_IDS) - seen)
    if missing_legacy:
        errors.append(f"catalog missing legacy IDs: {', '.join(missing_legacy)}")
    return errors


def validate_variant(preset_id: str, variant: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    role = variant.get("role")
    if role not in {"thumbnail", "phone"}:
        errors.append(f"{preset_id}: invalid variant role {role}")
    if variant.get("mimeType") != "image/webp":
        errors.append(f"{preset_id} {role}: mimeType must be image/webp")

    path = variant.get("path")
    if not isinstance(path, str) or not path:
        errors.append(f"{preset_id} {role}: missing path")
        return errors
    file_path = (CATALOG_ROOT / path).resolve()
    if not is_inside(file_path, CATALOG_ROOT.resolve()):
        errors.append(f"{preset_id} {role}: path escapes catalog root")
        return errors
    if not file_path.exists():
        errors.append(f"{preset_id} {role}: file missing: {path}")
        return errors

    width, height = image_dimensions(file_path)
    if variant.get("width") != width or variant.get("height") != height:
        errors.append(f"{preset_id} {role}: dimensions are stale")
    if variant.get("byteSize") != file_path.stat().st_size:
        errors.append(f"{preset_id} {role}: byteSize is stale")
    if variant.get("sha256") != sha256(file_path):
        errors.append(f"{preset_id} {role}: sha256 is stale")
    return errors


def load_metadata() -> dict[str, Any]:
    if not METADATA_PATH.exists():
        raise CatalogError(f"Missing {relative(METADATA_PATH)}")
    try:
        return json.loads(METADATA_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise CatalogError(f"metadata JSON invalid: {error}") from error


def existing_catalog_generated_at() -> str | None:
    if not CATALOG_PATH.exists():
        return None
    try:
        catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    generated_at = catalog.get("generatedAt")
    return generated_at if isinstance(generated_at, str) and generated_at else None


def image_dimensions(path: Path) -> tuple[int, int]:
    identify_command = image_identify_command()
    if identify_command is None:
        raise CatalogError("Missing required tool: magick or identify")
    output = run(identify_command + ["-format", "%w %h", str(path)]).stdout.strip()
    width, height = output.split()
    return int(width), int(height)


def average_hex(path: Path) -> str:
    red, green, blue = sample_rgb(path)
    return f"#{red:02X}{green:02X}{blue:02X}"


def bottom_luminance(path: Path) -> float:
    width, height = image_dimensions(path)
    crop_height = max(1, math.ceil(height * 0.35))
    red, green, blue = sample_rgb(
        path,
        extra_args=[
            "-crop",
            f"{width}x{crop_height}+0+{height - crop_height}",
            "+repage",
        ],
    )

    def linearize(component: int) -> float:
        value = component / 255.0
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4

    return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)


def sample_rgb(path: Path, extra_args: list[str] | None = None) -> tuple[int, int, int]:
    convert_command = image_convert_command()
    if convert_command is None:
        raise CatalogError("Missing required tool: magick or convert")
    args = convert_command + [
        str(path),
        "-auto-orient",
        "-alpha",
        "remove",
        "-colorspace",
        "sRGB",
    ]
    if extra_args:
        args.extend(extra_args)
    args.extend(
        [
            "-resize",
            "1x1!",
            "-format",
            "%[fx:int(255*r)],%[fx:int(255*g)],%[fx:int(255*b)]",
            "info:",
        ]
    )
    output = run(args).stdout.strip()
    red, green, blue = output.split(",")
    return int(red), int(green), int(blue)


def sha256(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def run(args: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(args, check=True, text=True, capture_output=True)
    except subprocess.CalledProcessError as error:
        command = " ".join(args)
        output = (error.stderr or error.stdout or "").strip()
        raise CatalogError(f"command failed: {command}\n{output}") from error


def image_convert_command() -> list[str] | None:
    if shutil.which("magick") is not None:
        return ["magick"]
    if shutil.which("convert") is not None:
        return ["convert"]
    return None


def image_identify_command() -> list[str] | None:
    if shutil.which("magick") is not None:
        return ["magick", "identify"]
    if shutil.which("identify") is not None:
        return ["identify"]
    return None


def relative(path: Path, root: Path = REPO_ROOT) -> str:
    return str(path.resolve().relative_to(root.resolve()))


def is_inside(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
    except ValueError:
        return False
    return True


class CatalogError(Exception):
    pass


if __name__ == "__main__":
    raise SystemExit(main())
