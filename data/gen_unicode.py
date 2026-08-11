#!/usr/bin/env python3
"""Generate data/unicode.json: printable BMP symbols/punctuation for the picker.

Regenerate after upgrading Python (new Unicode releases add characters):
    python3 data/gen_unicode.py
"""
import json
import unicodedata
from pathlib import Path

# Blocks to include, expressed as (start, end, block_name) tuples. Focused on
# symbol/punctuation/math/arrow blocks — the stuff users actually reach for a
# picker to find. Skipping letter blocks (they aren't why anyone opens a Unicode
# picker) and CJK/Hangul/etc. (huge, and users type those with dedicated IMEs).
BLOCKS = [
    (0x00A0, 0x00FF, "Latin-1 Punctuation & Symbols"),
    (0x2000, 0x206F, "General Punctuation"),
    (0x2070, 0x209F, "Superscripts and Subscripts"),
    (0x20A0, 0x20CF, "Currency Symbols"),
    (0x2100, 0x214F, "Letterlike Symbols"),
    (0x2150, 0x218F, "Number Forms"),
    (0x2190, 0x21FF, "Arrows"),
    (0x2200, 0x22FF, "Mathematical Operators"),
    (0x2300, 0x23FF, "Miscellaneous Technical"),
    (0x2400, 0x243F, "Control Pictures"),
    (0x2460, 0x24FF, "Enclosed Alphanumerics"),
    (0x2500, 0x257F, "Box Drawing"),
    (0x2580, 0x259F, "Block Elements"),
    (0x25A0, 0x25FF, "Geometric Shapes"),
    (0x2600, 0x26FF, "Miscellaneous Symbols"),
    (0x2700, 0x27BF, "Dingbats"),
    (0x27C0, 0x27EF, "Miscellaneous Mathematical Symbols-A"),
    (0x27F0, 0x27FF, "Supplemental Arrows-A"),
    (0x2900, 0x297F, "Supplemental Arrows-B"),
    (0x2980, 0x29FF, "Miscellaneous Mathematical Symbols-B"),
    (0x2A00, 0x2AFF, "Supplemental Mathematical Operators"),
    (0x2B00, 0x2BFF, "Miscellaneous Symbols and Arrows"),
]

# Combining marks (M*), controls (C*), separators (Zl/Zp) — not standalone
# printable characters, so exclude even when their block is otherwise in scope.
SKIP_CATEGORIES = {"Mn", "Mc", "Me", "Cc", "Cf", "Cs", "Co", "Cn", "Zl", "Zp"}


def main() -> None:
    entries = []
    for start, end, block in BLOCKS:
        for cp in range(start, end + 1):
            ch = chr(cp)
            try:
                name = unicodedata.name(ch)
            except ValueError:
                continue
            if unicodedata.category(ch) in SKIP_CATEGORIES:
                continue
            entries.append({
                "char":  ch,
                "name":  name.lower(),
                "cp":    f"{cp:04X}",
                "block": block,
            })

    out = Path(__file__).parent / "unicode.json"
    out.write_text(json.dumps(entries, ensure_ascii=False, separators=(",", ":")))
    print(f"wrote {len(entries)} entries to {out} ({out.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
