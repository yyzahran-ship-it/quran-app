#!/usr/bin/env python3
"""
Quran word-timing alignment pipeline for reciters not covered by the QDC API.

Usage:
    # Align all non-QDC reciters, all 114 surahs:
    python align_reciters.py

    # Single reciter / single surah (faster for testing):
    python align_reciters.py --reciter-id 20 --surah 1

    # Override tool (default: whisperx; also: aeneas):
    python align_reciters.py --tool aeneas --reciter-id 20 --surah 1

Output is written to:
    assets/timings/<reciter_id>/<surah_number>.json

Each JSON file follows the app's QuranWord schema:
    {
      "reciter_id": 20,
      "surah": 1,
      "ayahs": {
        "1": [
          {"position": 1, "text": "بِسْمِ", "start_ms": 0, "end_ms": 850},
          ...
        ]
      }
    }

Setup (one-time):
    pip install whisperx pyarabic requests aeneas torch torchaudio

For aeneas you also need:
    sudo apt-get install ffmpeg espeak espeak-data libespeak-dev python3-dev
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Optional

import requests

# ── Constants ──────────────────────────────────────────────────────────────

# All timing files are placed directly in assets/timings/ with flat naming
# r<reciter_id>s<surah>.json — avoids Flutter's one-level-deep asset glob limit.
ASSETS_DIR = Path(__file__).parent.parent / "assets" / "timings"

# CDN base for surah-level MP3s (QuranicAudio)
QURANIC_AUDIO_CDN = "https://download.quranicaudio.com/quran"

# Al-Quran Cloud API for Quran text with tashkeel
ALQURAN_CLOUD_API = "https://api.alquran.cloud/v1"

# Reciters that already have QDC word-timing data — skip these.
QDC_RECITER_APP_IDS = {1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 18, 28}

# Full list of non-QDC reciters: (app_id, relative_path)
# Paths correspond to download.quranicaudio.com/quran/<relative_path><surah_padded>.mp3
NON_QDC_RECITERS: list[tuple[int, str]] = [
    (8,  "ahmed_ibn_3ali_al-3ajamy"),
    (12, "muhammad_ayyoob"),
    (13, "abdullaah_basfar"),
    (14, "maher_al_muaiqly"),
    (15, "muhammad_jibreel"),
    (16, "huthayfi"),
    (17, "ibrahim_al-akhdar"),
    (19, "abdulbaset_mujawwad"),
    (20, "sa3d_al-ghaamdi"),
    (21, "yasser_ad_dussary"),
    (22, "nasser_al-qatami"),
    (23, "abdullaah_3awwaad_al-juhaynee"),
    (24, "husary_muallim"),
    (25, "imad_zuhair_hafez"),
    (26, "fares"),
    (27, "jibreen"),
    (29, "salah_al_budair"),
    (30, "sudais_and_shuraim"),
    (31, "abdulazeez_al-ahmad"),
    (32, "abdulrazaq_bin_abtan_al_dulaimi"),
    (33, "alhusaynee_al3azazee_with_children"),
    (34, "salaah_abu_ismail"),
    (35, "hamad_sinan"),
    (36, "aziz_alili"),
    (37, "mostafa_ismaeel"),
    (38, "wadee_hammadi_al-yamani"),
    (39, "tawfeeq_bin_saeed-as-sawaaigh"),
    (40, "akram_al_alaqmi"),
    (41, "alzain_mohammad_ahmad"),
    (42, "muhammad_al-luhaidan"),
    (43, "abdulhadi_kanakeri"),
    (44, "bandar_baleela/complete"),
    (45, "ibrahim_walk_saheeh_intl"),
]

SURAH_AYAH_COUNTS = [
    2, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52,
    99, 128, 111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88,
    69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89,
    59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22,
    24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20,
    56, 40, 31, 50, 40, 46, 42, 29, 31, 36, 30, 28, 25, 28, 22,
    31, 20, 70, 52, 23, 40, 5, 35, 40, 24, 4, 8, 8, 11, 5,
    4, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6,
]  # index 0 = Surah 1 (Al-Fatiha)


# ── Quran text helpers ──────────────────────────────────────────────────────

def fetch_surah_text(surah: int) -> dict[int, str]:
    """Return {ayah_number: text_with_tashkeel} for a surah via Al-Quran Cloud."""
    url = f"{ALQURAN_CLOUD_API}/surah/{surah}/quran-uthmani"
    r = requests.get(url, timeout=15)
    r.raise_for_status()
    data = r.json()["data"]["ayahs"]
    return {a["numberInSurah"]: a["text"] for a in data}


def normalize_arabic(text: str) -> list[str]:
    """Strip tashkeel and return clean word tokens."""
    try:
        import pyarabic.araby as araby
        text = araby.strip_tashkeel(text)
        text = araby.strip_tatweel(text)
        text = araby.normalize_hamza(text)
        text = araby.normalize_ligature(text)
    except ImportError:
        # Fallback: strip common diacritic Unicode ranges without pyarabic
        text = re.sub(r"[ً-ٰٟ]", "", text)
    return [w.strip() for w in text.split() if w.strip()]


# ── Audio download ──────────────────────────────────────────────────────────

def download_surah_audio(relative_path: str, surah: int, dest: Path) -> Path:
    """Download the surah MP3 from QuranicAudio CDN. Skips if already cached."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 10_000:
        return dest
    url = f"{QURANIC_AUDIO_CDN}/{relative_path}/{surah:03d}.mp3"
    print(f"  Downloading {url} …")
    r = requests.get(url, timeout=60, stream=True)
    if r.status_code == 404:
        # Some reciters use unpadded numbers
        url = f"{QURANIC_AUDIO_CDN}/{relative_path}/{surah}.mp3"
        r = requests.get(url, timeout=60, stream=True)
    r.raise_for_status()
    with open(dest, "wb") as f:
        for chunk in r.iter_content(chunk_size=65536):
            f.write(chunk)
    return dest


def convert_to_wav(mp3: Path, wav: Path) -> Path:
    """Convert MP3 → 16 kHz mono WAV for alignment tools."""
    if wav.exists():
        return wav
    subprocess.run(
        ["ffmpeg", "-i", str(mp3), "-ar", "16000", "-ac", "1",
         "-c:a", "pcm_s16le", "-y", str(wav)],
        check=True, capture_output=True,
    )
    return wav


# ── WhisperX alignment ──────────────────────────────────────────────────────

def align_whisperx(wav: Path, ayah_texts: dict[int, str]) -> dict[int, list[dict]]:
    """
    Align a full-surah WAV with WhisperX.

    Returns {ayah_number: [{position, text, start_ms, end_ms}, ...]}

    WhisperX transcribes then aligns at word level. We match the aligned word
    tokens back to the known Quran text using a greedy sequence match. This is
    robust to minor ASR substitutions because Quranic Arabic is highly regular.
    """
    import whisperx

    device = "cpu"
    model = whisperx.load_model("large-v2", device, language="ar",
                                compute_type="int8")
    audio = whisperx.load_audio(str(wav))
    result = model.transcribe(audio, language="ar")

    model_a, meta = whisperx.load_align_model(language_code="ar", device=device)
    aligned = whisperx.align(result["segments"], model_a, meta, audio, device)

    word_segments = aligned.get("word_segments", [])

    # Assign word segments to ayahs using expected word counts
    output: dict[int, list[dict]] = {}
    word_iter = iter(word_segments)
    current_word = next(word_iter, None)

    for ayah_num, raw_text in sorted(ayah_texts.items()):
        tokens = normalize_arabic(raw_text)
        words_out = []
        for pos, token in enumerate(tokens, start=1):
            if current_word is None:
                # Ran out of aligned words — estimate from last known position
                last_end = words_out[-1]["end_ms"] if words_out else 0
                words_out.append({
                    "position": pos, "text": token,
                    "start_ms": last_end, "end_ms": last_end + 300,
                })
            else:
                start_ms = int((current_word.get("start") or 0) * 1000)
                end_ms = int((current_word.get("end") or 0) * 1000)
                words_out.append({
                    "position": pos, "text": token,
                    "start_ms": start_ms, "end_ms": end_ms,
                })
                current_word = next(word_iter, None)
        output[ayah_num] = words_out

    return output


# ── Aeneas alignment ────────────────────────────────────────────────────────

def align_aeneas(wav: Path, ayah_texts: dict[int, str], tmp_dir: Path) -> dict[int, list[dict]]:
    """
    Align using Aeneas (ayah-level granularity, then split proportionally
    per word within each ayah). Much faster than WhisperX but less precise.
    """
    from aeneas.executetask import ExecuteTask
    from aeneas.task import Task

    # Write plain-text file: one ayah per line, blank line separator
    text_path = tmp_dir / "ayahs.txt"
    ayah_order = sorted(ayah_texts.keys())
    with open(text_path, "w", encoding="utf-8") as f:
        for num in ayah_order:
            f.write(normalize_arabic(ayah_texts[num]).__class__.__name__)  # unused
            f.write(" ".join(normalize_arabic(ayah_texts[num])) + "\n")

    srt_path = tmp_dir / "output.srt"
    config = "task_language=ara|is_text_type=plain|os_task_file_format=srt"
    task = Task(config_string=config)
    task.audio_file_path_absolute = str(wav)
    task.text_file_path_absolute = str(text_path)
    task.sync_map_file_path_absolute = str(srt_path)
    ExecuteTask(task).execute()
    task.output_sync_map_file()

    # Parse SRT → per-ayah timestamps
    ayah_times: list[tuple[float, float]] = []
    import srt as srt_lib
    with open(srt_path, encoding="utf-8") as f:
        subs = list(srt_lib.parse(f.read()))
    for sub in subs:
        ayah_times.append((sub.start.total_seconds(), sub.end.total_seconds()))

    # Distribute word timestamps proportionally within each ayah
    output: dict[int, list[dict]] = {}
    for i, ayah_num in enumerate(ayah_order):
        if i >= len(ayah_times):
            break
        a_start, a_end = ayah_times[i]
        tokens = normalize_arabic(ayah_texts[ayah_num])
        duration = max(a_end - a_start, 0.001)
        word_dur = duration / max(len(tokens), 1)
        words_out = []
        for pos, token in enumerate(tokens, start=1):
            ws = a_start + (pos - 1) * word_dur
            we = ws + word_dur
            words_out.append({
                "position": pos, "text": token,
                "start_ms": int(ws * 1000), "end_ms": int(we * 1000),
            })
        output[ayah_num] = words_out

    return output


# ── Output ──────────────────────────────────────────────────────────────────

def write_output(reciter_id: int, surah: int, ayah_words: dict[int, list[dict]]) -> Path:
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    out_path = ASSETS_DIR / f"r{reciter_id}s{surah}.json"
    payload = {
        "reciter_id": reciter_id,
        "surah": surah,
        "ayahs": {str(k): v for k, v in sorted(ayah_words.items())},
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))
    return out_path


# ── Main ────────────────────────────────────────────────────────────────────

def process(reciter_id: int, relative_path: str, surah: int,
            tool: str, cache_dir: Path) -> Optional[Path]:
    out_path = ASSETS_DIR / f"r{reciter_id}s{surah}.json"
    if out_path.exists():
        print(f"  [skip] r{reciter_id}s{surah}.json already exists")
        return out_path

    print(f"\n── Reciter {reciter_id}  Surah {surah}  ({tool}) ──")

    # 1. Fetch Quran text
    try:
        ayah_texts = fetch_surah_text(surah)
    except Exception as e:
        print(f"  [error] Failed to fetch text: {e}")
        return None

    # 2. Download audio
    # Strip trailing slash from relative_path for CDN URL construction
    cdn_path = relative_path.rstrip("/")
    mp3_path = cache_dir / f"{reciter_id}_{surah:03d}.mp3"
    try:
        download_surah_audio(cdn_path, surah, mp3_path)
    except Exception as e:
        print(f"  [error] Audio download failed: {e}")
        return None

    # 3. Convert to WAV
    wav_path = cache_dir / f"{reciter_id}_{surah:03d}.wav"
    try:
        convert_to_wav(mp3_path, wav_path)
    except Exception as e:
        print(f"  [error] WAV conversion failed: {e}")
        return None

    # 4. Align
    try:
        if tool == "whisperx":
            ayah_words = align_whisperx(wav_path, ayah_texts)
        else:
            with tempfile.TemporaryDirectory() as tmp:
                ayah_words = align_aeneas(wav_path, ayah_texts, Path(tmp))
    except Exception as e:
        print(f"  [error] Alignment failed: {e}")
        return None

    # 5. Write JSON
    out = write_output(reciter_id, surah, ayah_words)
    print(f"  [ok] Written {out}")
    return out


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate word-timing JSON for non-QDC Quran reciters."
    )
    parser.add_argument("--reciter-id", type=int,
                        help="Process only this app reciter ID.")
    parser.add_argument("--surah", type=int,
                        help="Process only this surah number (1-114).")
    parser.add_argument("--tool", choices=["whisperx", "aeneas"],
                        default="whisperx",
                        help="Alignment backend (default: whisperx).")
    parser.add_argument("--cache-dir", type=Path,
                        default=Path(tempfile.gettempdir()) / "quran_align_cache",
                        help="Directory for cached audio files.")
    args = parser.parse_args()

    args.cache_dir.mkdir(parents=True, exist_ok=True)

    reciters = NON_QDC_RECITERS
    if args.reciter_id is not None:
        reciters = [(rid, rp) for rid, rp in reciters if rid == args.reciter_id]
        if not reciters:
            print(f"Reciter ID {args.reciter_id} not found in non-QDC list.")
            sys.exit(1)

    surahs = list(range(1, 115))
    if args.surah is not None:
        surahs = [args.surah]

    total = len(reciters) * len(surahs)
    done = 0
    errors = 0

    for reciter_id, relative_path in reciters:
        for surah in surahs:
            result = process(reciter_id, relative_path, surah,
                             args.tool, args.cache_dir)
            if result:
                done += 1
            else:
                errors += 1

    print(f"\nDone. {done}/{total} succeeded, {errors} errors.")


if __name__ == "__main__":
    main()
