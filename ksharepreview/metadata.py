"""Extrator leve de metadados OpenGraph, Twitter Cards, HTML e imagens de banner."""

from __future__ import annotations

import html
import urllib.parse
from dataclasses import dataclass, field
from html.parser import HTMLParser
from typing import Any

import requests

DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
)


@dataclass
class LinkMetadata:
    input_url: str
    final_url: str
    domain: str
    status_code: int = 200
    title: str = ""
    description: str = ""
    site_name: str = ""
    card_type: str = ""
    theme_color: str = ""
    canonical_url: str = ""
    favicon_url: str = ""
    banner_url: str = ""
    images: list[dict[str, str]] = field(default_factory=list)
    tags: list[dict[str, str]] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "input_url": self.input_url,
            "final_url": self.final_url,
            "domain": self.domain,
            "status_code": self.status_code,
            "title": self.title,
            "description": self.description,
            "site_name": self.site_name,
            "card_type": self.card_type,
            "theme_color": self.theme_color,
            "canonical_url": self.canonical_url,
            "favicon_url": self.favicon_url,
            "banner_url": self.banner_url,
            "images": self.images,
            "tags": self.tags,
        }


class _HeadMetaParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.in_title = False
        self.title_parts: list[str] = []
        self.meta_tags: list[tuple[str, str]] = []
        self.link_tags: list[dict[str, str]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        t = tag.lower()
        attr_map = {k.lower(): (v or "").strip() for k, v in attrs}

        if t == "title":
            self.in_title = True
        elif t == "meta":
            key = attr_map.get("property") or attr_map.get("name") or attr_map.get("itemprop") or ""
            val = attr_map.get("content") or attr_map.get("value") or ""
            if key and val:
                self.meta_tags.append((key, val))
        elif t == "link":
            rel = attr_map.get("rel", "").lower()
            href = attr_map.get("href", "")
            if rel and href:
                self.link_tags.append({
                    "rel": rel,
                    "href": href,
                    "sizes": attr_map.get("sizes", ""),
                    "type": attr_map.get("type", ""),
                })

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() == "title":
            self.in_title = False

    def handle_data(self, data: str) -> None:
        if self.in_title:
            self.title_parts.append(data)


def normalize_url(raw_url: str) -> str:
    url = (raw_url or "").strip()
    if not url:
        raise ValueError("Informe uma URL válida.")
    if not url.startswith(("http://", "https://")):
        url = "https://" + url
    parsed = urllib.parse.urlsplit(url)
    if not parsed.netloc:
        raise ValueError("URL inválida. Exemplo: https://github.com")
    return url


def _abs_url(base_url: str, candidate: str) -> str:
    c = (candidate or "").strip()
    if not c:
        return ""
    return urllib.parse.urljoin(base_url, c)


def parse_html_metadata(html_text: str, final_url: str, input_url: str = "", status_code: int = 200) -> LinkMetadata:
    parser = _HeadMetaParser()
    parser.feed(html_text)
    parser.close()

    parsed_url = urllib.parse.urlsplit(final_url)
    domain = parsed_url.netloc
    html_title = html.unescape("".join(parser.title_parts)).strip()

    meta_map: dict[str, str] = {}
    tags: list[dict[str, str]] = []
    for k, v in parser.meta_tags:
        lk = k.lower()
        meta_map.setdefault(lk, v)
        group = "OpenGraph" if lk.startswith("og:") else ("Twitter / X" if lk.startswith("twitter:") else "HTML")
        tags.append({"group": group, "key": k, "value": v})

    canonical = ""
    favicon = ""
    apple_icon = ""
    for link in parser.link_tags:
        rels = set(link["rel"].split())
        href_abs = _abs_url(final_url, link["href"])
        if "canonical" in rels and not canonical:
            canonical = href_abs
        if "apple-touch-icon" in rels and not apple_icon:
            apple_icon = href_abs
        elif "icon" in rels and not favicon:
            favicon = href_abs

    if not favicon:
        favicon = apple_icon or f"{parsed_url.scheme}://{domain}/favicon.ico"

    title = (
        meta_map.get("og:title")
        or meta_map.get("twitter:title")
        or html_title
        or domain
    )
    description = (
        meta_map.get("og:description")
        or meta_map.get("twitter:description")
        or meta_map.get("description")
        or ""
    )
    site_name = (
        meta_map.get("og:site_name")
        or meta_map.get("twitter:site")
        or domain
    )
    card_type = meta_map.get("twitter:card") or meta_map.get("og:type") or "website"
    theme_color = meta_map.get("theme-color") or ""

    images: list[dict[str, str]] = []
    seen_imgs: set[str] = set()
    image_keys = [
        ("og:image:secure_url", "OpenGraph (HTTPS)"),
        ("og:image", "OpenGraph Banner"),
        ("og:image:url", "OpenGraph Banner"),
        ("twitter:image:src", "Twitter / X Banner"),
        ("twitter:image", "Twitter / X Banner"),
    ]
    for mkey, label in image_keys:
        for k, v in parser.meta_tags:
            if k.lower() == mkey:
                img_abs = _abs_url(final_url, v)
                if img_abs and img_abs not in seen_imgs:
                    seen_imgs.add(img_abs)
                    images.append({"label": label, "tag": k, "url": img_abs})

    if apple_icon and apple_icon not in seen_imgs:
        seen_imgs.add(apple_icon)
        images.append({"label": "Apple Touch Icon", "tag": "apple-touch-icon", "url": apple_icon})
    if favicon and favicon not in seen_imgs:
        seen_imgs.add(favicon)
        images.append({"label": "Favicon", "tag": "icon", "url": favicon})

    banner_url = next(
        (img["url"] for img in images if "Banner" in img["label"] or "HTTPS" in img["label"]),
        "",
    )

    if html_title:
        tags.insert(0, {"group": "HTML", "key": "<title>", "value": html_title})
    if canonical:
        tags.append({"group": "HTML", "key": "rel=canonical", "value": canonical})
    if favicon:
        tags.append({"group": "HTML", "key": "rel=icon", "value": favicon})

    return LinkMetadata(
        input_url=input_url or final_url,
        final_url=final_url,
        domain=domain,
        status_code=status_code,
        title=title,
        description=description,
        site_name=site_name,
        card_type=card_type,
        theme_color=theme_color,
        canonical_url=canonical or final_url,
        favicon_url=favicon,
        banner_url=banner_url,
        images=images,
        tags=tags,
    )


def fetch_link_metadata(raw_url: str, timeout: int = 12) -> LinkMetadata:
    """Busca a URL e extrai metadados OpenGraph/Twitter/HTML."""
    url = normalize_url(raw_url)
    headers = {
        "User-Agent": DEFAULT_USER_AGENT,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.8",
    }
    resp = requests.get(url, headers=headers, timeout=timeout, allow_redirects=True)
    resp.raise_for_status()
    if resp.encoding is None or resp.encoding.lower() == "iso-8859-1":
        resp.encoding = resp.apparent_encoding or "utf-8"
    return parse_html_metadata(
        resp.text,
        final_url=resp.url,
        input_url=url,
        status_code=resp.status_code,
    )
