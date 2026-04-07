"""Перекодирование видео в H.264 + AAC MP4 для совместимости с Flutter video_player на Windows/macOS."""

from __future__ import annotations

import logging
import os
import shutil
import subprocess
import tempfile
from typing import Optional

logger = logging.getLogger(__name__)


def try_transcode_to_desktop_mp4(video_bytes: bytes) -> Optional[bytes]:
    """
    Возвращает MP4 (H.264 + AAC), который обычно воспроизводится на десктопе.
    Если ffmpeg недоступен или перекодирование не удалось — None (используем исходный файл).
    """
    if not video_bytes or not shutil.which("ffmpeg"):
        if not shutil.which("ffmpeg"):
            logger.debug("ffmpeg не найден в PATH — перекодирование пропущено")
        return None

    path_in = ""
    path_out = ""
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".bin") as f_in:
            f_in.write(video_bytes)
            path_in = f_in.name

        path_out = path_in + ".desktop.mp4"

        def run_ffmpeg(args: list[str]) -> None:
            subprocess.run(
                args,
                check=True,
                capture_output=True,
                timeout=300,
            )

        base_cmd = [
            "ffmpeg",
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            path_in,
            "-c:v",
            "libx264",
            "-preset",
            "fast",
            "-crf",
            "23",
            "-pix_fmt",
            "yuv420p",
            "-movflags",
            "+faststart",
        ]
        try:
            run_ffmpeg(
                base_cmd
                + [
                    "-c:a",
                    "aac",
                    "-b:a",
                    "128k",
                    path_out,
                ]
            )
        except subprocess.CalledProcessError as e:
            err = (e.stderr or b"").decode(errors="replace")
            logger.info(
                "ffmpeg с аудио не удался, пробуем без аудио: %s",
                err[:400],
            )
            try:
                run_ffmpeg(base_cmd + ["-an", path_out])
            except subprocess.CalledProcessError as e2:
                logger.warning(
                    "ffmpeg перекодирование не удалось: %s",
                    (e2.stderr or b"").decode(errors="replace")[:500],
                )
                return None

        with open(path_out, "rb") as f:
            out = f.read()
        if len(out) < 32:
            return None
        return out
    except (OSError, subprocess.TimeoutExpired) as e:
        logger.warning("ошибка при перекодировании видео: %s", e)
        return None
    finally:
        for p in (path_in, path_out):
            if p and os.path.isfile(p):
                try:
                    os.unlink(p)
                except OSError:
                    pass
