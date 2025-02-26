#!/usr/bin/env python3
"""
DocumentFilter: A configurable tool for removing sensitive data from text content.
Can process files or direct text streams with customizable filtering rules.
"""

import re
import os
import json
import hashlib
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Callable, Union, Pattern, Optional, Set, Tuple


class DocumentFilter:
    """Primary class for filtering sensitive content from documents."""

    DEFAULT_CONFIG = {
        "filters": {
            "api_keys": {
                "enabled": True,
                "patterns": [
                    r"(?i)(?:api[_-]?key|access[_-]?token|secret[_-]?key)['\"]?\s*[:=]\s*['\"]?([a-zA-Z0-9_\-\.]{20,})['\"]\s*",
                    r"(?:[A-Za-z0-9+/]{40,}[=]{0,2})",  # Base64-like strings
                    r"(?i)gh[pousr]_[a-zA-Z0-9_]{16,}",  # GitHub tokens
                    r"(?i)sk-[a-zA-Z0-9]{20,}"  # OpenAI API keys
                ],
                "replacement": "[API_KEY_REMOVED]"
            },
            "credentials": {
                "enabled": True,
                "patterns": [
                    r"(?i)(?:password|passwd|pwd)['\"]?\s*[:=]\s*['\"]?([^'\"\s]{3,})['\"]?\s*",
                    r"(?i)(?:username|login|user)['\"]?\s*[:=]\s*['\"]?([^'\"\s]{3,})['\"]?\s*",
                    r"(?i)(?:pass|password|pwd)(?:word)?[\s]*[:=][\s]*['\"]*([^'\"\s]{3,})['\"]*"
                ],
                "replacement": "[CREDENTIALS_REMOVED]"
            },
            "emails": {
                "enabled": True,
                "patterns": [
                    r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"
                ],
                "replacement": "[EMAIL_REMOVED]"
            },
            "phone_numbers": {
                "enabled": True,
                "patterns": [
                    r"(?:\+\d{1,3}[\s\-]?)?\(?\d{3}\)?[\s\-]?\d{3}[\s\-]?\d{4}",
                    r"\+\d{1,3}[\s\-]?\d{1,14}(?:\s*ext\.?\s*\d{1,5})?"
                ],
                "replacement": "[PHONE_NUMBER_REMOVED]"
            },
            "urls_with_auth": {
                "enabled": True,
                "patterns": [
                    r"(?i)(?:https?://)(?:[^:@/\n]+:[^:@/\n]+@)(?:[^\s/\n]+)"
                ],
                "replacement": "[URL_WITH_AUTH_REMOVED]"
            },
            "ip_addresses": {
                "enabled": True,
                "patterns": [
                    r"\b(?:\d{1,3}\.){3}\d{1,3}\b",  # IPv4
                    r"(?:[0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|(?:[0-9a-fA-F]{1,4}:){1,7}:|(?:[0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}"  # Simple IPv6
                ],
                "replacement": "[IP_ADDRESS_REMOVED]"
            },
            "names": {
                "enabled": False,  # Off by default as it can be overly aggressive
                "nlp_based": True,
                "replacement": "[NAME_REMOVED]"
            },
            "places": {
                "enabled": False,  # Off by default as it can be overly aggressive
                "nlp_based": True,
                "replacement": "[PLACE_REMOVED]"
            }
        },
        "nlp": {
            "enabled": False,
            "model": "en_core_web_sm"
        },
        "cache": {
            "enabled": True,
            "extension": ".filtered",
            "use_hash": True
        },
        "loglevel": "INFO"
    }

    def __init__(self, config_path: Optional[str] = None):
        """
        Initialize the DocumentFilter with optional configuration.
        
        Args:
            config_path: Path to JSON configuration file
        """
        self.config = self.DEFAULT_CONFIG.copy()
        
        if config_path:
            self._load_config(config_path)
            
        self.compiled_patterns = self._compile_patterns()
        self.nlp = None
        
        # Initialize NLP if needed and enabled
        if self.config["nlp"]["enabled"]:
            self._initialize_nlp()

    def _load_config(self, config_path: str) -> None:
        """Load configuration from a JSON file."""
        try:
            with open(config_path, 'r') as f:
                user_config = json.load(f)
                
            # Deep merge the configurations
            self._deep_merge(self.config, user_config)
            
        except (json.JSONDecodeError, FileNotFoundError) as e:
            raise ValueError(f"Error loading configuration: {str(e)}")

    def _deep_merge(self, base: Dict, update: Dict) -> None:
        """Recursively merge update dict into base dict."""
        for key, value in update.items():
            if key in base and isinstance(base[key], dict) and isinstance(value, dict):
                self._deep_merge(base[key], value)
            else:
                base[key] = value

    def _compile_patterns(self) -> Dict[str, List[Pattern]]:
        """Compile regex patterns for faster processing."""
        compiled = {}
        for filter_name, filter_config in self.config["filters"].items():
            if filter_config.get("enabled", False) and not filter_config.get("nlp_based", False):
                compiled[filter_name] = [re.compile(pattern) for pattern in filter_config.get("patterns", [])]
        return compiled

    def _initialize_nlp(self) -> None:
        """Initialize NLP model if enabled."""
        try:
            import spacy
            model_name = self.config["nlp"]["model"]
            self.nlp = spacy.load(model_name)
            print(f"Loaded NLP model: {model_name}")
        except ImportError:
            print("Spacy not installed. NLP-based filtering will be disabled.")
            self.config["nlp"]["enabled"] = False
        except OSError:
            print(f"NLP model {self.config['nlp']['model']} not found. Run: python -m spacy download {self.config['nlp']['model']}")
            self.config["nlp"]["enabled"] = False

    def _should_use_cache(self, file_path: Path) -> bool:
        """
        Determine if we should use cached version of a file.
        
        Args:
            file_path: Path to the original file
            
        Returns:
            Boolean indicating if cache should be used
        """
        if not self.config["cache"]["enabled"]:
            return False
            
        cache_path = self._get_cache_path(file_path)
        
        if not cache_path.exists():
            return False
            
        # Check if original file was modified after cache was created
        return file_path.stat().st_mtime < cache_path.stat().st_mtime

    def _get_cache_path(self, file_path: Path) -> Path:
        """
        Get the path for the cached filtered version of a file.
        
        Args:
            file_path: Path to the original file
            
        Returns:
            Path to the cached filtered file
        """
        if self.config["cache"]["use_hash"]:
            # Use hash of file path to avoid long paths or special chars
            file_hash = hashlib.md5(str(file_path.absolute()).encode()).hexdigest()
            cache_dir = Path(file_path.parent, ".document_filter_cache")
            cache_dir.mkdir(exist_ok=True)
            return Path(cache_dir, f"{file_hash}{self.config['cache']['extension']}")
        else:
            # Simply append the extension
            return Path(f"{file_path}{self.config['cache']['extension']}")

    def _filter_text_with_regex(self, text: str) -> str:
        """
        Apply regex-based filters to text.
        
        Args:
            text: Input text to filter
            
        Returns:
            Filtered text
        """
        filtered_text = text
        
        for filter_name, patterns in self.compiled_patterns.items():
            replacement = self.config["filters"][filter_name]["replacement"]
            for pattern in patterns:
                filtered_text = pattern.sub(replacement, filtered_text)
                
        return filtered_text

    def _filter_text_with_nlp(self, text: str) -> str:
        """
        Apply NLP-based filters to text.
        
        Args:
            text: Input text to filter
            
        Returns:
            Filtered text with entities removed
        """
        if not self.nlp or not self.config["nlp"]["enabled"]:
            return text
            
        doc = self.nlp(text)
        
        # Create a list of spans to redact
        spans_to_redact = []
        
        # Check for named entities if enabled
        if self.config["filters"]["names"]["enabled"]:
            for ent in doc.ents:
                if ent.label_ in ("PERSON", "PER"):
                    spans_to_redact.append((ent.start_char, ent.end_char, "names"))
                    
        # Check for place entities if enabled
        if self.config["filters"]["places"]["enabled"]:
            for ent in doc.ents:
                if ent.label_ in ("GPE", "LOC", "FAC"):
                    spans_to_redact.append((ent.start_char, ent.end_char, "places"))
        
        # Sort spans in reverse order to avoid index issues when replacing
        spans_to_redact.sort(reverse=True, key=lambda x: x[0])
        
        # Replace each span with the appropriate replacement
        result = text
        for start, end, filter_type in spans_to_redact:
            replacement = self.config["filters"][filter_type]["replacement"]
            result = result[:start] + replacement + result[end:]
            
        return result

    def filter_text(self, text: str) -> str:
        """
        Apply all enabled filters to text.
        
        Args:
            text: Input text to filter
            
        Returns:
            Filtered text with sensitive information removed
        """
        # Apply regex-based filters
        filtered_text = self._filter_text_with_regex(text)
        
        # Apply NLP-based filters if enabled
        if self.config["nlp"]["enabled"]:
            filtered_text = self._filter_text_with_nlp(filtered_text)
            
        return filtered_text

    def filter_file(self, file_path: Union[str, Path]) -> Tuple[str, bool]:
        """
        Filter a file, with optional caching.
        
        Args:
            file_path: Path to the file to filter
            
        Returns:
            Tuple of (filtered content, whether cache was used)
        """
        path = Path(file_path)
        
        if not path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")
            
        # Check if we can use cached version
        if self._should_use_cache(path):
            cache_path = self._get_cache_path(path)
            with open(cache_path, 'r', encoding='utf-8') as f:
                return f.read(), True
                
        # Read and filter the file
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        filtered_content = self.filter_text(content)
        
        # Save to cache if enabled
        if self.config["cache"]["enabled"]:
            cache_path = self._get_cache_path(path)
            with open(cache_path, 'w', encoding='utf-8') as f:
                f.write(filtered_content)
                
        return filtered_content, False

    def filter_stream(self, stream_input) -> str:
        """
        Filter a text stream.
        
        Args:
            stream_input: An iterable text stream
            
        Returns:
            Filtered content
        """
        # Join all lines from the stream
        content = ''.join(stream_input)
        return self.filter_text(content)

    def save_config(self, config_path: str) -> None:
        """
        Save current configuration to a file.
        
        Args:
            config_path: Path to save the configuration
        """
        with open(config_path, 'w') as f:
            json.dump(self.config, f, indent=2)


def main():
    """Command line interface for the DocumentFilter tool."""
    parser = argparse.ArgumentParser(description='Filter sensitive data from text files or streams')
    parser.add_argument('input', nargs='?', help='Input file path (omit to read from stdin)')
    parser.add_argument('-c', '--config', help='Path to configuration file')
    parser.add_argument('-o', '--output', help='Output file path (omit to write to stdout)')
    parser.add_argument('--save-config', help='Save default config to specified path')
    parser.add_argument('--disable-cache', action='store_true', help='Disable file caching')
    parser.add_argument('--enable-nlp', action='store_true', help='Enable NLP-based filtering')
    
    args = parser.parse_args()
    
    # Handle config generation request
    if args.save_config:
        with open(args.save_config, 'w') as f:
            json.dump(DocumentFilter.DEFAULT_CONFIG, f, indent=2)
        print(f"Default configuration saved to {args.save_config}")
        return
    
    # Initialize the filter
    doc_filter = DocumentFilter(args.config)
    
    # Apply command-line overrides
    if args.disable_cache:
        doc_filter.config["cache"]["enabled"] = False
    
    if args.enable_nlp:
        doc_filter.config["nlp"]["enabled"] = True
        doc_filter._initialize_nlp()
    
    try:
        # Process input
        if args.input:
            # Filter a file
            filtered_content, used_cache = doc_filter.filter_file(args.input)
            if used_cache:
                print(f"Used cached version of {args.input}")
        else:
            # Filter from stdin
            import sys
            filtered_content = doc_filter.filter_stream(sys.stdin)
        
        # Output results
        if args.output:
            with open(args.output, 'w', encoding='utf-8') as f:
                f.write(filtered_content)
            print(f"Filtered content written to {args.output}")
        else:
            print(filtered_content)
            
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()