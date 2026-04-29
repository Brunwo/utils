

curl -sg "https://openrouter.ai/api/frontend/models/find?max_price=0&order=most-popular&output_modalities=text" | jq -r '.data.models[] | select(.endpoint.is_free == true and .has_text_output == true) | .slug'