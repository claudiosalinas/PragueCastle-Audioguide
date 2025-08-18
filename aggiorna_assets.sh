#!/bin/bash

# Percorso al tuo progetto Flutter (modificalo se serve)
PROJECT_DIR="$PWD"
AUDIO_DIR="$PROJECT_DIR/assets/audio"
PUBSPEC_FILE="$PROJECT_DIR/pubspec.yaml"

# Backup di sicurezza
cp "$PUBSPEC_FILE" "$PUBSPEC_FILE.bak"

# Rimuove la vecchia sezione assets: e la ricrea
# Mantiene tutto prima della vecchia definizione di assets:
awk '/assets:/{exit} {print}' "$PUBSPEC_FILE" > "$PUBSPEC_FILE.tmp"

# Aggiunge la sezione aggiornata
echo "assets:" >> "$PUBSPEC_FILE.tmp"

for file in "$AUDIO_DIR"/*.mp3; do
  filename=$(basename "$file")
  echo "  - assets/audio/$filename" >> "$PUBSPEC_FILE.tmp"
done

# Sovrascrive il pubspec.yaml
mv "$PUBSPEC_FILE.tmp" "$PUBSPEC_FILE"

echo "✅ pubspec.yaml aggiornato con i file audio trovati."
echo "💾 Backup salvato in $PUBSPEC_FILE.bak"

