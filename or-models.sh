#!/bin/bash
    echo "OpenRouter Models CLI - Browse models with filtering similar to web interface"
VERSION="1.0.0"
OUTPUT_FORMAT="table"
SORT_BY="popular"
MAX_PRICE=""
OUTPUT_MODALITY="text"
INPUT_MODALITY=""
PROVIDER=""
AUTHOR=""
CONTEXT_MIN=""
CONTEXT_MAX=""
SHOW_HIDDEN="false"
JSON_OUTPUT="false"

show_help() {
cat << EOF
OpenRouter Models CLI - Browse models with filtering similar to web interface
USAGE: or-models [OPTIONS]
FILTERS:
--max-price NUM Maximum price per million tokens (default: free only)
--output-modality TYPE Output modality: text, image, audio, video (default: text)
--input-modality TYPE Input modality: text, image, audio, video, file
--provider NAME Filter by provider (e.g., openai, google, anthropic)
--author NAME Filter by model author
--context-min NUM Minimum context length in tokens
--context-max NUM Maximum context length in tokens
--show-hidden Include hidden/deprecated models
SORTING:
--sort ORDER Sort by: popular, newest, weekly, price-low, price-high, 
context-high, throughput-high, latency-low (default: popular)
        echo "DISPLAY:"
        echo "--format FORMAT Output format: table, list, csv, json, id, quiet (default: table)"  # id: outputs model identifier for API calls (e.g., tencent/hy3-preview:free)
--json Output raw JSON (equivalent to --format json)
--quiet Only show model names (no headers/formatting)
EXAMPLES:
# Show free text models (most popular first)
or-models
# Show free image generation models
or-models --output-modality image
# Models with context > 1M tokens
or-models --context-min 1000000
# OpenAI models only
or-models --provider openai
# Video input models
or-models --input-modality video
# Sort by price (free first, then cheapest)
or-models --sort price-low --max-price 1
# JSON output for scripting
or-models --json | jq '.[] | {name, slug}'
# Just names (one per line)
or-models --quiet
# CSV export
or-models --format csv > models.csv
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
case $1 in
--max-price) MAX_PRICE="$2"; shift 2 ;;
--output-modality) OUTPUT_MODALITY="$2"; shift 2 ;;
--input-modality) INPUT_MODALITY="$2"; shift 2 ;;
--provider) PROVIDER="$2"; shift 2 ;;
--author) AUTHOR="$2"; shift 2 ;;
--context-min) CONTEXT_MIN="$2"; shift 2 ;;
--context-max) CONTEXT_MAX="$2"; shift 2 ;;
--show-hidden) SHOW_HIDDEN="true"; shift ;;
--sort) SORT_BY="$2"; shift 2 ;;
--format) OUTPUT_FORMAT="$2"; shift 2 ;;
--json) JSON_OUTPUT="true"; OUTPUT_FORMAT="json"; shift ;;
--quiet) OUTPUT_FORMAT="quiet"; shift ;;
--help|-h) show_help; exit 0 ;;
--version) echo "or-models $VERSION"; exit 0 ;;
*) echo "Unknown option: $1"; show_help; exit 1 ;;
esac
done

# Build URL with filters
BASE_URL="https://openrouter.ai/api/frontend/models/find"
PARAMS=()

[[ -n "$MAX_PRICE" ]] && PARAMS+=("max_price=$MAX_PRICE")
[[ -n "$OUTPUT_MODALITY" ]] && PARAMS+=("output_modalities=$OUTPUT_MODALITY")
[[ -n "$INPUT_MODALITY" ]] && PARAMS+=("input_modalities=$INPUT_MODALITY")
[[ -n "$SORT_BY" ]] && PARAMS+=("order=$SORT_BY")

# Add sorting mappings
case $SORT_BY in
popular) ORDER="most-popular" ;;
newest) ORDER="newest" ;;
weekly) ORDER="top-weekly" ;;
price-low) ORDER="price-low" ;;
price-high) ORDER="price-high" ;;
context-high) ORDER="context-high" ;;
throughput-high) ORDER="throughput-high" ;;
latency-low) ORDER="latency-low" ;;
*) ORDER="most-popular" ;;
esac
PARAMS+=("order=$ORDER")

# Build query string
if [[ ${#PARAMS[@]} -gt 0 ]]; then
QUERY="?"
for i in "${!PARAMS[@]}"; do
[[ $i -gt 0 ]] && QUERY+="&"
QUERY+="${PARAMS[$i]}"
done
else
QUERY="?max_price=0&output_modalities=text&order=most-popular"
fi

# Fetch and filter data
fetch_models() {
    curl -s "${BASE_URL}${QUERY}" |
        jq -r \
            --argjson show_hidden "$SHOW_HIDDEN" \
            --arg provider "$PROVIDER" \
            --arg author "$AUTHOR" \
            --argjson context_min "${CONTEXT_MIN:-0}" \
            --argjson context_max "${CONTEXT_MAX:-999999999}" \
            '.data.models[] |
                select(.endpoint.is_free == true) |
                select(.has_text_output == true) |
                select(.endpoint.is_hidden == false or $show_hidden == true) |
                select($provider == "" or .author == $provider) |
                select($author == "" or .author == $author) |
                select(.context_length >= $context_min and .context_length <= $context_max) |
                { name: .name, slug: .slug, author: .author, context: .context_length, input_price: .endpoint.pricing.prompt, output_price: .endpoint.pricing.completion, modalities: .output_modalities, reasoning: .supports_reasoning }'
}

# Format output based on user preference
case $OUTPUT_FORMAT in
table)
echo -e "\n\033[1mOpenRouter Models\033[0m (Free | Text Output | Sorted by: $SORT_BY)\n"
printf "%-40s %-20s %-12s %-12s %-10s\n" "MODEL NAME" "AUTHOR" "INPUT" "OUTPUT" "CONTEXT"
printf "%s\n" "$(printf '=%.0s' {1..100})"
        fetch_models | jq -r '"\(.name | .[0:38]) \(.author | .[0:18]) \(.input_price) \(.output_price) \(.context/1000 | floor)K"' | column -t
;;
list)
fetch_models | jq -r '" • \(.name) [\(.author)] - Context: \(.context/1000 | floor)K"'
;;
csv)
echo '"Model Name","Author","Input Price","Output Price","Context","Supports Reasoning"'
fetch_models | jq -r '[.name, .author, .input_price, .output_price, .context, .reasoning] | @csv'
;;
json)
fetch_models | jq -s '.'
;;
quiet)
fetch_models | jq -r '.name'
;;
id)
    # Output model identifier in the form "provider/slug:free" (or appropriate price tag)
    price_tag="free"
    if [[ -n "$MAX_PRICE" && "$MAX_PRICE" != "0" ]]; then
        price_tag="paid"
    fi
    # Use bash variable outside of jq to avoid quoting issues
    # The slug may contain the provider prefix (e.g., "tencent/hy3-preview"), so strip any leading segment
    fetch_models | jq -r "\"\(.author)/\(.slug | split(\"/\")[-1]):${price_tag}\""
    ;;
*)
fetch_models | jq -r '.name'
;;
esac