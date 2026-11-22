"""Testes unitários do extrator de metadados do KSharePreview."""

from __future__ import annotations

import unittest
from unittest.mock import MagicMock, patch

from ksharepreview.metadata import fetch_link_metadata, normalize_url, parse_html_metadata


SAMPLE_HTML = """<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <title>KDE Community</title>
  <meta name="description" content="Comunidade de software livre KDE.">
  <meta name="theme-color" content="#3daee9">
  <link rel="canonical" href="https://kde.org/">
  <link rel="icon" href="/favicon.png">
  <meta property="og:title" content="KDE — Liberdade Digital">
  <meta property="og:description" content="Plasma, Kirigami e aplicativos livres.">
  <meta property="og:site_name" content="KDE">
  <meta property="og:image" content="/assets/banner.png">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:image" content="https://cdn.kde.org/twitter-card.jpg">
</head>
<body></body>
</html>
"""


class TestMetadataParser(unittest.TestCase):
    def test_normalize_url(self) -> None:
        self.assertEqual(normalize_url("kde.org"), "https://kde.org")
        self.assertEqual(normalize_url("http://example.com/a"), "http://example.com/a")
        self.assertEqual(normalize_url('  "<https://example.com/my page>"  '), "https://example.com/my%20page")
        with self.assertRaises(ValueError):
            normalize_url("   ")

    def test_fetch_fallback_on_400(self) -> None:
        resp_400 = MagicMock(status_code=400, text="Bad Request", url="https://example.com", encoding="utf-8")
        resp_200 = MagicMock(status_code=200, text=SAMPLE_HTML, url="https://kde.org/", encoding="utf-8")
        with patch("ksharepreview.metadata.requests.Session") as mock_session_cls:
            mock_sess = mock_session_cls.return_value
            mock_sess.get.side_effect = [resp_400, resp_200]
            meta = fetch_link_metadata("https://kde.org/")
            self.assertEqual(meta.title, "KDE — Liberdade Digital")
            self.assertEqual(mock_sess.get.call_count, 2)

    def test_parse_opengraph_twitter_and_relative_images(self) -> None:
        meta = parse_html_metadata(SAMPLE_HTML, final_url="https://kde.org/pt/")
        self.assertEqual(meta.title, "KDE — Liberdade Digital")
        self.assertEqual(meta.description, "Plasma, Kirigami e aplicativos livres.")
        self.assertEqual(meta.site_name, "KDE")
        self.assertEqual(meta.card_type, "summary_large_image")
        self.assertEqual(meta.theme_color, "#3daee9")
        self.assertEqual(meta.banner_url, "https://kde.org/assets/banner.png")
        self.assertEqual(meta.favicon_url, "https://kde.org/favicon.png")

        img_urls = [img["url"] for img in meta.images]
        self.assertIn("https://kde.org/assets/banner.png", img_urls)
        self.assertIn("https://cdn.kde.org/twitter-card.jpg", img_urls)
        self.assertIn("https://kde.org/favicon.png", img_urls)
        self.assertGreaterEqual(len(meta.tags), 8)


if __name__ == "__main__":
    unittest.main()
