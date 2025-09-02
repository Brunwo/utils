#!/usr/bin/env python3
"""
Web Scraper Tool using Jina AI Markdown URL Prefix

This tool takes a URL, prefixes it with Jina AI's markdown service,
fetches the content, and outputs the markdown version.
"""

import sys
import requests
from urllib.parse import urlparse

def is_valid_url(url):
    """Check if the provided URL is valid."""
    try:
        result = urlparse(url)
        return all([result.scheme, result.netloc])
    except:
        return False

def scrape_to_markdown(url):
    """Scrape the webpage and return markdown content using Jina AI."""
    if not is_valid_url(url):
        print(f"Error: Invalid URL provided: {url}")
        return None

    # Construct Jina AI URL
    jina_url = f"https://r.jina.ai/{url}"

    try:
        response = requests.get(jina_url, timeout=30)
        response.raise_for_status()

        return response.text
    except requests.exceptions.RequestException as e:
        print(f"Error fetching content: {e}")
        return None

def main():
    if len(sys.argv) != 2:
        print("Usage: python scraper.py <URL>")
        print("Example: python scraper.py https://example.com")
        sys.exit(1)

    url = sys.argv[1]
    markdown_content = scrape_to_markdown(url)

    if markdown_content:
        print(markdown_content)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
