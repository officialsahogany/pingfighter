#!/opt/homebrew/opt/python@3.11/bin/python3.11
import cv2
import numpy as np
from pathlib import Path
from moviepy import VideoFileClip
from moviepy.video.io.ffmpeg_tools import ffmpeg_merge_video_audio

INPUT_VIDEO = Path('stagevideo/stage6.mp4')
TEMPLATE_IMAGE = Path('stagevideo/watermark_sample.jpeg')
OUTPUT_TEMP_VIDEO = INPUT_VIDEO.with_name('stage6_overlay_video_tmp.mp4')
OUTPUT_TEMP_AUDIO = INPUT_VIDEO.with_name('stage6_overlay_audio_tmp.m4a')
OUTPUT_TEMP_FINAL = INPUT_VIDEO.with_name('stage6_overlay_tmp.mp4')

SCALE_FACTORS = [0.82, 0.88, 0.92, 0.96, 1.0, 1.04]
THRESHOLD = 0.34
MISS_LIMIT = 8
PAD_RATIO_X = 0.28
PAD_RATIO_Y = 0.35
BLUR_SIGMA = 7
OVERLAY_ALPHA = 0.42
RNG = np.random.default_rng(42)


def build_templates(template_gray_base: np.ndarray):
    templates = []
    for scale in SCALE_FACTORS:
        resized = cv2.resize(
            template_gray_base,
            None,
            fx=scale,
            fy=scale,
            interpolation=cv2.INTER_AREA,
        )
        if resized.size == 0:
            continue
        templates.append(resized)
    return templates


def create_overlay(shape, frame_index: int) -> np.ndarray:
    height, width = shape[:2]
    y = np.linspace(0.0, 1.0, height, dtype=np.float32)
    x = np.linspace(0.0, 1.0, width, dtype=np.float32)
    xv, yv = np.meshgrid(x, y)

    phase = frame_index * 0.11
    wave1 = np.sin((xv * 5.3 + yv * 2.7) * np.pi + phase)
    wave2 = np.cos((xv * 8.1 - yv * 3.4) * np.pi + phase * 1.7)
    wave3 = np.sin((xv * 3.0 + yv * 9.0) * np.pi - phase * 0.6)

    pattern = 0.5 + 0.25 * wave1 + 0.18 * wave2 + 0.12 * wave3
    pattern = np.clip(pattern, 0.0, 1.0)

    base_colors = np.stack(
        [
            40 + 70 * pattern,  # Blue
            60 + 110 * pattern,  # Green
            120 + 120 * pattern,  # Red
        ],
        axis=-1,
    )

    noise = RNG.standard_normal(size=(height, width, 3)).astype(np.float32)
    noise = cv2.GaussianBlur(noise, (0, 0), sigmaX=max(width, height) * 0.12)
    noise = (noise - noise.min()) / max(float(np.ptp(noise)), 1e-6)
    overlay = 0.75 * base_colors + 80 * noise
    overlay = cv2.GaussianBlur(overlay, (0, 0), sigmaX=max(width, height) * 0.08)
    return np.clip(overlay, 0, 255).astype(np.uint8)


def blend_region(frame, bbox, frame_index):
    x1, y1, x2, y2 = bbox
    roi = frame[y1:y2, x1:x2]
    if roi.size == 0:
        return

    blurred = cv2.GaussianBlur(roi, (0, 0), sigmaX=BLUR_SIGMA, sigmaY=BLUR_SIGMA)
    overlay = create_overlay(roi.shape, frame_index)
    blended = cv2.addWeighted(blurred, 1 - OVERLAY_ALPHA, overlay, OVERLAY_ALPHA, 0)

    # Soften edges
    mask = np.zeros((y2 - y1, x2 - x1), dtype=np.float32)
    cv2.rectangle(mask, (0, 0), (mask.shape[1], mask.shape[0]), 1.0, thickness=-1)
    mask = cv2.GaussianBlur(mask, (0, 0), sigmaX=BLUR_SIGMA * 0.8)
    mask = mask[..., None]
    frame[y1:y2, x1:x2] = (roi * (1 - mask) + blended * mask).astype(np.uint8)


def detect_watermark(frame_gray, templates):
    best_val = -1.0
    best_loc = None
    best_template = None

    for temp_gray in templates:
        th, tw = temp_gray.shape
        if frame_gray.shape[0] < th or frame_gray.shape[1] < tw:
            continue
        res = cv2.matchTemplate(frame_gray, temp_gray, cv2.TM_CCOEFF_NORMED)
        _, max_val, _, max_loc = cv2.minMaxLoc(res)
        if max_val > best_val:
            best_val = max_val
            best_loc = max_loc
            best_template = temp_gray
    return best_val, best_loc, best_template


def enlarge_bbox(x, y, w, h, frame_width, frame_height):
    pad_x = int(round(w * PAD_RATIO_X))
    pad_y = int(round(h * PAD_RATIO_Y))
    x1 = max(0, x - pad_x)
    y1 = max(0, y - pad_y)
    x2 = min(frame_width, x + w + pad_x)
    y2 = min(frame_height, y + h + pad_y)
    return x1, y1, x2, y2


def process_video():
    if not INPUT_VIDEO.exists():
        raise SystemExit(f"Video not found: {INPUT_VIDEO}")
    if not TEMPLATE_IMAGE.exists():
        raise SystemExit(f"Template not found: {TEMPLATE_IMAGE}")

    template_gray_base = cv2.imread(str(TEMPLATE_IMAGE), cv2.IMREAD_GRAYSCALE)
    if template_gray_base is None:
        raise SystemExit('Failed to read template image')

    templates = build_templates(template_gray_base)
    if not templates:
        raise SystemExit('No templates generated')

    with VideoFileClip(str(INPUT_VIDEO)) as clip:
        fps = clip.fps or 30.0
        if clip.audio:
            clip.audio.write_audiofile(str(OUTPUT_TEMP_AUDIO), codec='aac', logger=None)

    cap = cv2.VideoCapture(str(INPUT_VIDEO))
    if not cap.isOpened():
        raise SystemExit('Failed to open input video')

    frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS) or fps

    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    writer = cv2.VideoWriter(
        str(OUTPUT_TEMP_VIDEO),
        fourcc,
        fps,
        (frame_width, frame_height),
    )
    if not writer.isOpened():
        cap.release()
        raise SystemExit('Failed to open VideoWriter')

    prev_loc = None
    prev_shape = None
    miss_count = 0
    frame_index = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        best_val, best_loc, best_template = detect_watermark(frame_gray, templates)

        use_loc = None
        use_shape = None

        if best_val >= THRESHOLD and best_loc is not None and best_template is not None:
            use_loc = best_loc
            use_shape = best_template.shape[::-1]
            prev_loc = best_loc
            prev_shape = use_shape
            miss_count = 0
        elif prev_loc is not None and prev_shape is not None and miss_count < MISS_LIMIT:
            use_loc = prev_loc
            use_shape = prev_shape
            miss_count += 1
        else:
            prev_loc = None
            prev_shape = None
            miss_count = 0

        if use_loc is not None and use_shape is not None:
            tw, th = use_shape
            bbox = enlarge_bbox(use_loc[0], use_loc[1], tw, th, frame_width, frame_height)
            blend_region(frame, bbox, frame_index)

        writer.write(frame)
        frame_index += 1

    cap.release()
    writer.release()

    if OUTPUT_TEMP_AUDIO.exists():
        ffmpeg_merge_video_audio(
            str(OUTPUT_TEMP_VIDEO),
            str(OUTPUT_TEMP_AUDIO),
            str(OUTPUT_TEMP_FINAL),
        )
        OUTPUT_TEMP_AUDIO.unlink(missing_ok=True)
    else:
        Path(OUTPUT_TEMP_VIDEO).rename(OUTPUT_TEMP_FINAL)

    OUTPUT_TEMP_VIDEO.unlink(missing_ok=True)
    if OUTPUT_TEMP_FINAL.exists():
        OUTPUT_TEMP_FINAL.replace(INPUT_VIDEO)


if __name__ == '__main__':
    process_video()
