"""
gen_wordcoords.py — Generate word-level bounding box database for Mushaf page image overlay.

Input:
  - /tmp/wordcoords_check.db  (built from glyphs.sql, 83881 rows)
  - assets/quran/ayahcoords.db  (ayah-line bounding boxes in 1024×1634 space)

Output:
  - assets/quran/wordcoords.db  — word positions in the same 1024×1634 coordinate space
    Schema: page_number, surah, ayah, position, x, y, width, height
    One row per word per ayah (verse-end markers excluded).

The glyphs.sql coordinate space is different from the 1024×1634 space used by the app.
We compute a per-page affine transformation from page-level bounds in both databases
and apply it to every word bounding box.

Pages 1-2 (Al-Fatihah / start of Al-Baqarah) have different layouts — we handle them
separately using their own per-page bounds.

Usage:
  python3 scripts/gen_wordcoords.py
"""

import sqlite3
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

GLYPH_DB   = '/tmp/wordcoords_check.db'
AYAH_DB    = os.path.join(PROJECT_ROOT, 'assets', 'quran', 'ayahcoords.db')
OUTPUT_DB  = os.path.join(PROJECT_ROOT, 'assets', 'quran', 'wordcoords.db')


def main():
    glyph_conn = sqlite3.connect(GLYPH_DB)
    ayah_conn  = sqlite3.connect(AYAH_DB)

    # Collect per-page bounds from both databases.
    print('Computing per-page transformations...')
    glyph_bounds = {}
    for row in glyph_conn.execute(
        'SELECT page_number, MIN(min_x), MIN(min_y), MAX(max_x), MAX(max_y) '
        'FROM glyphs GROUP BY page_number'
    ):
        glyph_bounds[row[0]] = (row[1], row[2], row[3], row[4])

    ayah_bounds = {}
    for row in ayah_conn.execute(
        'SELECT page_number, MIN(x), MIN(y), MAX(x+width), MAX(y+height) '
        'FROM page GROUP BY page_number'
    ):
        ayah_bounds[row[0]] = (row[1], row[2], row[3], row[4])

    # Compute per-page (sx, sy, ox, oy) where:
    #   x_out = ox + (x_in - gx1) * sx
    #   y_out = oy + (y_in - gy1) * sy
    transforms = {}
    for pg, (gx1, gy1, gx2, gy2) in glyph_bounds.items():
        if pg not in ayah_bounds:
            continue
        ax1, ay1, ax2, ay2 = ayah_bounds[pg]
        gw = gx2 - gx1
        gh = gy2 - gy1
        if gw == 0 or gh == 0:
            continue
        sx = (ax2 - ax1) / gw
        sy = (ay2 - ay1) / gh
        transforms[pg] = (sx, sy, ax1, ay1, gx1, gy1)

    # Count word positions per ayah to detect verse-end markers.
    # The last position for each (page, surah, ayah) is the verse marker — skip it.
    print('Counting max positions per ayah...')
    max_pos = {}
    for row in glyph_conn.execute(
        'SELECT page_number, sura_number, ayah_number, MAX(position) '
        'FROM glyphs GROUP BY page_number, sura_number, ayah_number'
    ):
        max_pos[(row[0], row[1], row[2])] = row[3]

    # Transform and write output.
    if os.path.exists(OUTPUT_DB):
        os.remove(OUTPUT_DB)

    out_conn = sqlite3.connect(OUTPUT_DB)
    out_conn.execute('''
        CREATE TABLE word_coords (
            page_number INTEGER,
            surah       INTEGER,
            ayah        INTEGER,
            position    INTEGER,
            x           INTEGER,
            y           INTEGER,
            width       INTEGER,
            height      INTEGER
        )
    ''')
    out_conn.execute('CREATE INDEX idx_page ON word_coords (page_number, surah, ayah)')

    batch = []
    skipped = 0
    transformed = 0

    print('Transforming word coordinates...')
    for row in glyph_conn.execute(
        'SELECT page_number, sura_number, ayah_number, position, min_x, min_y, max_x, max_y '
        'FROM glyphs ORDER BY page_number, sura_number, ayah_number, position'
    ):
        pg, sura, ayah_n, pos, gx1w, gy1w, gx2w, gy2w = row

        # Skip verse-end marker (always the last position).
        key = (pg, sura, ayah_n)
        if pos == max_pos.get(key, -1):
            skipped += 1
            continue

        if pg not in transforms:
            skipped += 1
            continue

        sx, sy, ax1, ay1, gx1, gy1 = transforms[pg]

        # Handle NULL coordinates (some glyphs have None for y values).
        if gx1w is None or gy1w is None or gx2w is None or gy2w is None:
            skipped += 1
            continue

        x_out  = round(ax1 + (gx1w - gx1) * sx)
        y_out  = round(ay1 + (gy1w - gy1) * sy)
        x2_out = round(ax1 + (gx2w - gx1) * sx)
        y2_out = round(ay1 + (gy2w - gy1) * sy)

        w = max(1, x2_out - x_out)
        h = max(1, y2_out - y_out)

        batch.append((pg, sura, ayah_n, pos, x_out, y_out, w, h))
        transformed += 1

        if len(batch) >= 5000:
            out_conn.executemany(
                'INSERT INTO word_coords VALUES (?,?,?,?,?,?,?,?)', batch
            )
            batch.clear()

    if batch:
        out_conn.executemany(
            'INSERT INTO word_coords VALUES (?,?,?,?,?,?,?,?)', batch
        )

    out_conn.commit()

    row_count = out_conn.execute('SELECT COUNT(*) FROM word_coords').fetchone()[0]
    db_size_kb = os.path.getsize(OUTPUT_DB) // 1024

    print(f'\nDone.')
    print(f'  Transformed: {transformed}')
    print(f'  Skipped (markers/errors): {skipped}')
    print(f'  Rows in output: {row_count}')
    print(f'  DB size: {db_size_kb} KB  ({OUTPUT_DB})')

    out_conn.close()
    glyph_conn.close()
    ayah_conn.close()


if __name__ == '__main__':
    main()
