#!/opt/homebrew/opt/python@3.11/bin/python3.11
"""Remove moving watermark from stage6.mp4 by targeted animated overlay."""

import cv2
import numpy as np
from pathlib import Path
from moviepy import VideoFileClip
from moviepy.video.io.ffmpeg_tools import ffmpeg_merge_video_audio

INPUT_VIDEO = Path('stagevideo/stage6.mp4')
TEMPLATE_IMAGE = Path('stagevideo/watermark_sample.jpeg')
TEMP_VIDEO = INPUT_VIDEO.with_name('stage6_manual_video_tmp.mp4')
TEMP_AUDIO = INPUT_VIDEO.with_name('stage6_manual_audio_tmp.m4a')
TEMP_OUTPUT = INPUT_VIDEO.with_name('stage6_manual_tmp.mp4')

# Known watermark movement schedule (start_sec, end_sec, search window)
INTERVALS = [
    (0.0, 2.0, (0, 420, 0, 260)),          # left-top
    (2.0, 5.0, (780, 1270, 180, 520)),     # right-middle
    (5.0, 8.0, (0, 420, 420, 700)),        # left-bottom
    (8.0, 10.1, (0, 420, 0, 260)),         # back to left-top
]

MARGIN_X_RATIO = 0.55
MARGIN_Y_RATIO = 0.6
INPAINT_RADIUS = 7
THRESHOLD = 0.34
MISS_LIMIT = 6


def choose_interval(time_sec: float):
    for start, end, window in INTERVALS:
        if start <= time_sec < end:
            return window
    return INTERVALS[-1][2]


def blend_region(frame, bbox):
    x1, y1, x2, y2 = bbox
    if x1 >= x2 or y1 >= y2:
        return

    mask = np.zeros(frame.shape[:2], dtype=np.uint8)
    mask[y1:y2, x1:x2] = 255
    inpainted = cv2.inpaint(frame, mask, INPAINT_RADIUS, cv2.INPAINT_TELEA)
    frame[y1:y2, x1:x2] = inpainted[y1:y2, x1:x2]

    frame[y1:y2, x1:x2] = cv2.GaussianBlur(frame[y1:y2, x1:x2], (0, 0), sigmaX=2)


def detect_within_window(frame_gray, template, window):
    x1, x2, y1, y2 = window
    x1 = int(max(0, x1))
    x2 = int(min(frame_gray.shape[1], x2))
    y1 = int(max(0, y1))
    y2 = int(min(frame_gray.shape[0], y2))
    region = frame_gray[y1:y2, x1:x2]
    if region.shape[0] < template.shape[0] or region.shape[1] < template.shape[1]:
        return None
    res = cv2.matchTemplate(region, template, cv2.TM_CCOEFF_NORMED)
    _, max_val, _, max_loc = cv2.minMaxLoc(res)
    return max_val, (max_loc[0] + x1, max_loc[1] + y1)


def enlarge_bbox(x, y, w, h, frame_width, frame_height):
    pad_x = int(round(w * MARGIN_X_RATIO))
    pad_y = int(round(h * MARGIN_Y_RATIO))
    x1 = max(0, x - pad_x)
    y1 = max(0, y - pad_y)
    x2 = min(frame_width, x + w + pad_x)
    y2 = min(frame_height, y + h + pad_y)
    return x1, y1, x2, y2


def process_video():
    if not INPUT_VIDEO.exists() or not TEMPLATE_IMAGE.exists():
        raise SystemExit('Required files missing')

    template_gray = cv2.imread(str(TEMPLATE_IMAGE), cv2.IMREAD_GRAYSCALE)
    if template_gray is None:
        raise SystemExit('Failed to load template image')
    th, tw = template_gray.shape

    with VideoFileClip(str(INPUT_VIDEO)) as clip:
        fps = clip.fps or 30.0
        if clip.audio:
            clip.audio.write_audiofile(str(TEMP_AUDIO), codec='aac', logger=None)

    cap = cv2.VideoCapture(str(INPUT_VIDEO))
    if not cap.isOpened():
        raise SystemExit('Failed to open input video')

    frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS) or fps

    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    writer = cv2.VideoWriter(str(TEMP_VIDEO), fourcc, fps, (frame_width, frame_height))
    if not writer.isOpened():
        cap.release()
        raise SystemExit('Failed to open VideoWriter')

    frame_index = 0
    prev_bbox = None
    miss_count = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        time_sec = frame_index / fps
        window = choose_interval(time_sec)
        frame_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        result = detect_within_window(frame_gray, template_gray, window)

        if result is not None and result[0] >= THRESHOLD:
            max_val, loc = result
            x, y = loc
            bbox = enlarge_bbox(x, y, tw, th, frame_width, frame_height)
            prev_bbox = bbox
            miss_count = 0
        elif prev_bbox is not None and miss_count < MISS_LIMIT:
            bbox = prev_bbox
            miss_count += 1
        else:
            bbox = None
            prev_bbox = None
            miss_count = 0

        if bbox is not None:
            blend_region(frame, bbox)

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
    process_video()
