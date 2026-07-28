#!/usr/bin/env python3
"""
Pre-fetch word-timing data from the Quran.com QDC API for all 12 reciters
that have segment data, saving one JSON file per reciter × surah into
assets/timings/. The Flutter app then loads these bundled files instead of
making network requests at runtime, so word highlighting works offline.

Usage (from repo root):
    pip install requests
    python scripts/fetch_qdc_timings.py              # all reciters, all surahs
    python scripts/fetch_qdc_timings.py --reciter 7  # only Mishary
    python scripts/fetch_qdc_timings.py --reciter 7 --surah 1  # one surah

Output: assets/timings/qdc{qdcId}s{surah}.json
"""

import argparse
import json
import os
import time
import sys
import requests

# fmt: off
# QDC reciter IDs — verified against https://api.qurancdn.com/api/qdc/audio/reciters
# App ID → QDC ID mapping (mirrors audio_repository.dart qdcReciterId values)
QDC_RECITERS = [
    {"app_id": 4,  "qdc_id": 1,  "name": "Abdul Basit (Abdul Samad)"},
    {"app_id": 3,  "qdc_id": 2,  "name": "Abdul Basit (Murattal)"},
    {"app_id": 2,  "qdc_id": 3,  "name": "AbdurRahman As-Sudais"},
    {"app_id": 7,  "qdc_id": 4,  "name": "Abu Bakr Al-Shatri"},
    {"app_id": 9,  "qdc_id": 5,  "name": "Hani Ar-Rifai"},
    {"app_id": 5,  "qdc_id": 6,  "name": "Mahmoud Khalil Al-Husary"},
    {"app_id": 1,  "qdc_id": 7,  "name": "Mishary Rashid Al-Afasy"},
    {"app_id": 10, "qdc_id": 8,  "name": "Mohamed Siddiq Al-Minshawi"},
    {"app_id": 11, "qdc_id": 9,  "name": "Al-Minshawi (Mujawwad)"},
    {"app_id": 18, "qdc_id": 10, "name": "Saud Al-Shuraim"},
    {"app_id": 28, "qdc_id": 11, "name": "Muhammad Al-Tablawi"},
    {"app_id": 6,  "qdc_id": 12, "name": "Al-Husary (Mujawwad)"},
]

SURAH_VERSE_COUNTS = [
    7,286,200,176,120,165,206,75,129,109,123,111,43,52,99,128,111,110,98,135,
    112,78,118,64,77,227,93,88,69,60,34,30,73,54,45,83,182,88,75,85,54,53,89,
    59,37,35,38,29,18,45,60,49,62,55,78,96,29,22,24,13,14,11,11,18,12,12,30,
    52,52,44,28,28,20,56,40,31,50,22,33,30,26,28,60,70,40,52,36,71,38,38,29,
    73,11,32,7,87,96,105,105,35,137,89,64,41,55,135,58,18,33,23,78,43,34,31,
    20,21,27,33,22,22,33,28,12,11,12,13,12,12,11,17,6,10,6,7,6,8,8,4,7,3,6,
    3,6,4,5,4,5,6,5,6,5,4,4,8,4,6,6,4,4,7,5,4,5,5,5,5,6,6,6,4,
]


def fetch_surah(qdc_id: int, surah: int, session: requests.Session) -> dict | None:
    """Fetch word-timing segments for one reciter × surah from the QDC API."""
    url = (
        f"https://api.qurancdn.com/api/qdc/audio/reciters/{qdc_id}/audio_files"
        f"?chapter_number={surah}&segments=true"
    )
    try:
        resp = session.get(url, timeout=20)
        resp.raise_for_status()
        data = resp.json()
    except Exception as e:
        print(f"    ERROR fetching surah {surah}: {e}", file=sys.stderr)
        return None

    audio_files = data.get("audio_files", [])
    ayahs: dict[str, list] = {}

    for af in audio_files:
        verse_key = af.get("verse_key", "")
        parts = verse_key.split(":")
        if len(parts) != 2:
            continue
        ayah_num = parts[1]
        segments = af.get("segments")
        if not segments:
            continue

        words = []
        for seg in segments:
            if len(seg) < 3:
                continue
            words.append({
                "position": int(seg[0]),
                "text": "",
                "start_ms": int(seg[1]),
                "end_ms": int(seg[2]),
            })
        words.sort(key=lambda w: w["position"])
        ayahs[ayah_num] = words

    if not ayahs:
        return None

    return {"reciter_qdc_id": qdc_id, "surah": surah, "ayahs": ayahs}


def out_path(qdc_id: int, surah: int, out_dir: str) -> str:
    return os.path.join(out_dir, f"qdc{qdc_id}s{surah}.json")


def main():
    parser = argparse.ArgumentParser(
        description="Pre-fetch QDC word-timing data into assets/timings/"
    )
    parser.add_argument(
        "--reciter", type=int, default=None,
        help="QDC reciter ID to fetch (default: all)"
    )
    parser.add_argument(
        "--surah", type=int, default=None,
        help="Surah number 1-114 to fetch (default: all)"
    )
    parser.add_argument(
        "--out-dir", default="assets/timings",
        help="Output directory (default: assets/timings)"
    )
    parser.add_argument(
        "--delay", type=float, default=0.2,
        help="Seconds to sleep between API calls (default: 0.2)"
    )
    parser.add_argument(
        "--skip-existing", action="store_true", default=True,
        help="Skip files that already exist (default: true)"
    )
    parser.add_argument(
        "--force", action="store_true", default=False,
        help="Overwrite existing files"
    )
    args = parser.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)

    reciters = (
        [r for r in QDC_RECITERS if r["qdc_id"] == args.reciter]
        if args.reciter else QDC_RECITERS
    )
    surahs = [args.surah] if args.surah else list(range(1, 115))

    session = requests.Session()
    session.headers.update({"User-Agent": "quran-app/1.0 (asset bundler)"})

    total = len(reciters) * len(surahs)
    done = 0
    skipped = 0
    errors = 0

    for reciter in reciters:
        qdc_id = reciter["qdc_id"]
        print(f"\n[{reciter['name']} / QDC ID {qdc_id}]")

        for surah in surahs:
            path = out_path(qdc_id, surah, args.out_dir)
            done += 1

            if not args.force and os.path.exists(path):
                skipped += 1
                continue

            print(f"  Surah {surah:3d}/{114} ...", end=" ", flush=True)
            result = fetch_surah(qdc_id, surah, session)

            if result is None:
                print("no data")
                errors += 1
            else:
                ayah_count = len(result["ayahs"])
                word_counts = [len(v) for v in result["ayahs"].values()]
                total_words = sum(word_counts)
                with open(path, "w", encoding="utf-8") as f:
                    json.dump(result, f, ensure_ascii=False, separators=(",", ":"))
                print(f"OK ({ayah_count} ayahs, {total_words} words)")

            if done < total:
                time.sleep(args.delay)

    print(f"\nDone. {done - skipped - errors} fetched, {skipped} skipped, {errors} errors.")
    print(f"Output: {os.path.abspath(args.out_dir)}/")


if __name__ == "__main__":
    main()
