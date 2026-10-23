"""A tiny stand-in for data/build_handbook.py, used by test_extract_claims.py. Same shapes, made-up content."""
SRC = {
    "srcA": "Author A. A made-up source for tests. 2020.",
    "srcB": "Author B. Another made-up source for tests. 2021.",
    "srcUnused": "Author C. Listed but never cited. 2022.",
}

CHAPTERS = [
    {
        "slug": "alpha",
        "part": "A",
        "title": "Alpha",
        "summary": "Fixture chapter.",
        "minutes": 1,
        "sources": ["srcA"],
        "blocks": [
            {"t": "lead", "text": "Most people can start walking today without seeing a doctor."},
            {"t": "stats", "items": [
                {"value": "150", "unit": "min", "label": "of moderate activity a week", "source": "srcA"},
                {"value": "2", "unit": "days", "label": "of strength work a week"},
            ]},
            {"t": "bars", "title": "Weekly minutes", "unit": "min", "items": [{"label": "Walk", "value": 150, "note": None}], "source": "srcA"},
            {"t": "table", "head": ["Food", "Protein"], "rows": [["Paneer", "18 g"], ["Dal", "24 g"]], "source": "srcB"},
            {"t": "compare", "do": {"title": "Do", "items": ["Warm up first"]}, "dont": {"title": "Don't", "items": ["Train through chest pain"]}},
            {"t": "evidence", "text": "Creatine 3 to 5 g a day is safe for healthy adults.", "source": "srcGhost", "grade": "strong"},
        ],
    },
]
