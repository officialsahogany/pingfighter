#!/opt/homebrew/opt/python@3.11/bin/python3.11
"""Hard-code watermark removal for stage6.mp4 using inpainting."""

import cv2
import numpy as np
from pathlib import Path
from moviepy import VideoFileClip
from moviepy.video.io.ffmpeg_tools import ffmpeg_merge_video_audio

INPUT_VIDEO = Path('stagevideo/stage6.mp4')
TEMP_VIDEO = INPUT_VIDEO.with_name('stage6_fixed_video_tmp.mp4')
TEMP_AUDIO = INPUT_VIDEO.with_name('stage6_fixed_audio_tmp.m4a')
TEMP_OUTPUT = INPUT_VIDEO.with_name('stage6_fixed_tmp.mp4')

# (start_sec, end_sec, (x1, x2, y1, y2)) bounds designed from watermark positions
WATERMARK_WINDOWS = [
    (0.0, 2.0, (30, 340, 25, 210)),
    (2.0, 5.0, (900, 1240, 240, 420)),
    (5.0, 8.0, (35, 340, 520, 690)),
    (8.0, 10.2, (30, 340, 25, 210)),
]

EDGE_BLUR_SIGMA = 3.0
NOISE_INTENSITY = 10.0


def get_window(time_sec: float):
    for start, end, bbox in WATERMARK_WINDOWS:
        if start <= time_sec < end:
            return bbox
    return WATERMARK_WINDOWS[-1][2]


def clamp_bbox(bbox, width, height, pad=14):
    x1, x2, y1, y2 = bbox
    x1 = max(0, x1 - pad)
    y1 = max(0, y1 - pad)
    x2 = min(width, x2 + pad)
    y2 = min(height, y2 + pad)
    return x1, x2, y1, y2


def process():
    if not INPUT_VIDEO.exists():
        raise SystemExit(f"Video not found: {INPUT_VIDEO}")

    with VideoFileClip(str(INPUT_VIDEO)) as clip:
        fps = clip.fps or 30.0
        duration = clip.duration
        if clip.audio:
            clip.audio.write_audiofile(str(TEMP_AUDIO), codec='aac', logger=None)

    cap = cv2.VideoCapture(str(INPUT_VIDEO))
    if not cap.isOpened():
        raise SystemExit('Failed to open input video')

    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS) or fps

    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    writer = cv2.VideoWriter(str(TEMP_VIDEO), fourcc, fps, (width, height))
    if not writer.isOpened():
        cap.release()
        raise SystemExit('Failed to open VideoWriter')

    frame_index = 0
    total_frames = int(duration * fps) + 1

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        time_sec = frame_index / fps
        bbox = clamp_bbox(get_window(time_sec), width, height)
        x1, x2, y1, y2 = bbox
        if x1 < x2 and y1 < y2:
            roi_h = y2 - y1
            roi_w = x2 - x1

            top_strip = frame[max(0, y1 - 15):y1, x1:x2]
            bottom_strip = frame[y2:min(height, y2 + 15), x1:x2]
            if top_strip.size:
                top_color = top_strip.mean(axis=(0, 1))
            else:
                top_color = frame.mean(axis=(0, 1))
            if bottom_strip.size:
                bottom_color = bottom_strip.mean(axis=(0, 1))
            else:
                bottom_color = frame.mean(axis=(0, 1))

            gradient = np.linspace(0.0, 1.0, roi_h, dtype=np.float32)[:, None]
            top_vec = top_color.reshape(1, 1, 3)
            bottom_vec = bottom_color.reshape(1, 1, 3)
            fill_col = top_vec * (1 - gradient[..., None]) + bottom_vec * gradient[..., None]
            fill = np.repeat(fill_col, roi_w, axis=1)

            rng = np.random.default_rng(int(frame_index * 97))
            noise = rng.normal(0.0, NOISE_INTENSITY, size=(roi_h, roi_w, 3)).astype(np.float32)
            patch = np.clip(fill + noise, 0, 255).astype(np.uint8)
            patch = cv2.GaussianBlur(patch, (0, 0), sigmaX=EDGE_BLUR_SIGMA)

            frame[y1:y2, x1:x2] = patch

        writer.write(frame)
        frame_index += 1

    cap.release()
    writer.release()

    if TEMP_AUDIO.exists():
        ffmpeg_merge_video_audio(str(TEMP_VIDEO), str(TEMP_AUDIO), str(TEMP_OUTPUT))
        TEMP_AUDIO.unlink(missing_ok=True)
    else:
        Path(TEMP_VIDEO).rename(TEMP_OUTPUT)

    TEMP_VIDEO.unlink(missing_ok=True)
    if TEMP_OUTPUT.exists():
        TEMP_OUTPUT.replace(INPUT_VIDEO)


if __name__ == '__main__':
    process()
