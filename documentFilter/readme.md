
The DocumentFilter tool provides a comprehensive solution for removing sensitive information from text documents. Here's an overview of its features:

### Key Features

1. **Multiple Filter Types**:
   - API keys detection (various formats)
   - Credentials (usernames/passwords)
   - Email addresses
   - Phone numbers
   - URLs with authentication information
   - IP addresses
   - Optional NLP-based filtering for names and places

2. **Configurable Operation**:
   - JSON-based configuration
   - Filters can be individually enabled/disabled
   - Custom regex patterns can be added
   - Replacement text can be customized

3. **Flexible Input Handling**:
   - Process individual files (Markdown, text, etc.)
   - Process text streams (stdin)

4. **Caching System**:
   - Stores processed files with custom extension
   - Uses file modification timestamps for cache freshness
   - Option to use hashed filenames for cleaner organization

5. **Command Line Interface**:
   - Process files directly from command line
   - Pipe content through stdin
   - Override configuration options

### Usage Examples

**Basic file filtering**:
```bash
python document_filter.py sensitive_document.md -o filtered_document.md
```

**Using custom configuration**:
```bash
python document_filter.py sensitive_document.md -c my_config.json
```

**Filtering from a stream**:
```bash
cat sensitive_document.md | python document_filter.py > filtered_document.md
```

**Create a default configuration file**:
```bash
python document_filter.py --save-config my_config.json
```
