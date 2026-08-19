"""Normalize generated route-aim gauge art to the runtime canvas contract.

The source artwork remains an image-generation output.  This tool only owns
deterministic canvas placement, final sizing, and the baked MIX-compatible
arrow halo required by the tower R4 art brief.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageFilter


FAN_SIZE = (256, 192)
FAN_SOURCE_PIVOT = (0.5, 0.875)
FAN_TARGET_PIVOT = (128, 168)
FAN_CONTENT_SCALE = 0.60

ARROW_SIZE = (128, 128)
ARROW_TARGET_BODY = (32, 80)
ARROW_TARGET_CENTER = (64, 64)
ARROW_ALPHA_THRESHOLD = 16
ARROW_GLOW_RADIUS = 3.0
ARROW_GLOW_ALPHA = 0.10
ARROW_GLOW_COLOR = (255, 207, 89)


def _resample() -> Image.Resampling:
	return Image.Resampling.LANCZOS


def _prepare_fan(source: Path) -> Image.Image:
	image = Image.open(source).convert("RGBA").resize(FAN_SIZE, _resample())
	scaled_size = (
		round(FAN_SIZE[0] * FAN_CONTENT_SCALE),
		round(FAN_SIZE[1] * FAN_CONTENT_SCALE),
	)
	image = image.resize(scaled_size, _resample())
	scaled_pivot = (
		round(FAN_SOURCE_PIVOT[0] * scaled_size[0]),
		round(FAN_SOURCE_PIVOT[1] * scaled_size[1]),
	)
	paste_at = (
		FAN_TARGET_PIVOT[0] - scaled_pivot[0],
		FAN_TARGET_PIVOT[1] - scaled_pivot[1],
	)
	canvas = Image.new("RGBA", FAN_SIZE, (0, 0, 0, 0))
	canvas.alpha_composite(image, paste_at)
	return canvas


def _threshold_bbox(alpha: Image.Image, threshold: int) -> tuple[int, int, int, int]:
	mask = alpha.point(lambda value: 255 if value > threshold else 0)
	bbox = mask.getbbox()
	if bbox is None:
		raise ValueError("arrow source has no visible pixels above the alpha threshold")
	return bbox


def _prepare_arrow(source: Path) -> Image.Image:
	image = Image.open(source).convert("RGBA")
	bbox = _threshold_bbox(image.getchannel("A"), ARROW_ALPHA_THRESHOLD)
	body = image.crop(bbox).resize(ARROW_TARGET_BODY, _resample())
	body_at = (
		ARROW_TARGET_CENTER[0] - ARROW_TARGET_BODY[0] // 2,
		ARROW_TARGET_CENTER[1] - ARROW_TARGET_BODY[1] // 2,
	)
	body_canvas = Image.new("RGBA", ARROW_SIZE, (0, 0, 0, 0))
	body_canvas.alpha_composite(body, body_at)

	body_alpha = body_canvas.getchannel("A")
	glow_alpha = body_alpha.filter(ImageFilter.GaussianBlur(ARROW_GLOW_RADIUS))
	glow_alpha = glow_alpha.point(lambda value: round(value * ARROW_GLOW_ALPHA))
	glow = Image.new("RGBA", ARROW_SIZE, ARROW_GLOW_COLOR + (0,))
	glow.putalpha(glow_alpha)
	glow.alpha_composite(body_canvas)
	return glow


def _validate(image: Image.Image, expected_size: tuple[int, int], label: str) -> None:
	if image.mode != "RGBA" or image.size != expected_size:
		raise ValueError(f"{label}: expected RGBA {expected_size}, got {image.mode} {image.size}")
	alpha = image.getchannel("A")
	if alpha.getextrema() != (0, 255):
		raise ValueError(f"{label}: alpha must contain both transparent and opaque pixels")
	for point in ((0, 0), (expected_size[0] - 1, 0), (0, expected_size[1] - 1), (expected_size[0] - 1, expected_size[1] - 1)):
		if alpha.getpixel(point) != 0:
			raise ValueError(f"{label}: canvas corner is not transparent at {point}")


def main() -> int:
	parser = argparse.ArgumentParser()
	parser.add_argument("--fan-source", type=Path, required=True)
	parser.add_argument("--arrow-source", type=Path, required=True)
	parser.add_argument("--output-dir", type=Path, required=True)
	args = parser.parse_args()

	args.output_dir.mkdir(parents=True, exist_ok=True)
	fan = _prepare_fan(args.fan_source)
	arrow = _prepare_arrow(args.arrow_source)
	_validate(fan, FAN_SIZE, "fan")
	_validate(arrow, ARROW_SIZE, "arrow")

	fan_path = args.output_dir / "route_aim_gauge_fan_imagegen_v1.png"
	arrow_path = args.output_dir / "route_aim_gauge_arrow_imagegen_v1.png"
	fan.save(fan_path, "PNG", optimize=True)
	arrow.save(arrow_path, "PNG", optimize=True)
	print(f"wrote {fan_path} | RGBA {fan.size} | alpha_bbox={fan.getchannel('A').getbbox()}")
	print(f"wrote {arrow_path} | RGBA {arrow.size} | alpha_bbox={arrow.getchannel('A').getbbox()}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
