#!/usr/bin/env python3
"""Builds a large made-up library for timing ShelfSpace: <books> books in author folders, about a third with reading progress
(a sidecar saying finished or how far in), a few duplicated in a second folder. The files are sparse, so they take the size
they say without taking the disk space.

usage: make-library.py <library dir> <books>
"""
import os, random, sys

lib, count = sys.argv[1], int(sys.argv[2])
rng = random.Random(7)  # the same library every run
exts = ["epub"] * 8 + ["pdf", "cbz", "mobi"]
authors = max(1, count // 12)
made = []
for i in range(count):
    author = f"Author {i % authors:04d}"
    ext = rng.choice(exts)
    folder = os.path.join(lib, author[:8] + " " + author[-2:], author)  # two levels, as libraries sorted by letter often are
    os.makedirs(folder, exist_ok=True)
    name = f"Book {i:05d}.{ext}"
    path = os.path.join(folder, name)
    size = rng.randint(200_000, 3_000_000) if ext in ("epub", "mobi") else rng.randint(5_000_000, 250_000_000)
    with open(path, "wb") as f:
        f.truncate(size)
    made.append(path)
    r = rng.random()
    if r < 0.33:
        sdr = os.path.splitext(path)[0] + ".sdr"
        os.makedirs(sdr, exist_ok=True)
        done = r < 0.15
        with open(os.path.join(sdr, f"metadata.{ext}.lua"), "w") as f:
            f.write('return {\n    ["percent_finished"] = %s,\n    ["summary"] = { ["status"] = "%s" },\n    ["doc_props"] = { ["title"] = "Book %05d", ["authors"] = "%s" },\n}\n'
                    % ("1" if done else "0.%d" % rng.randint(1, 9), "complete" if done else "reading", i, author))
# a few copies of the same book in a second folder, for the Duplicates tab
dup = os.path.join(lib, "Copies")
os.makedirs(dup, exist_ok=True)
for path in made[: max(1, count // 100)]:
    with open(os.path.join(dup, os.path.basename(path)), "wb") as f:
        f.truncate(os.path.getsize(path) + 1)  # a different size, so they are never compared byte for byte
print(f"{count} books in {lib}")
