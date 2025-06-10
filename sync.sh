#!/bin/bash

# Script di sincronizzazione SEMPLIFICATO per Mac
# Copia tutto nella cartella Experts di MT5

echo "🚀 Syncing BreakoutEA to MT5..."

# Percorsi
PROJECT_DIR="$(pwd)/src"
FOLDER="BenStrategy"
MT5_EXPERTS_BASE="/Users/$USER/Library/Application Support/net.metaquotes.wine.metatrader5/MQL5/Experts"
MT5_EXPERTS="$MT5_EXPERTS_BASE/$FOLDER"

echo "🔍 Checking paths..."
echo "📁 MT5_EXPERTS_BASE: $MT5_EXPERTS_BASE"
echo "📁 TARGET_FOLDER: $MT5_EXPERTS"

# Verifica che la cartella base Experts esista
if [ ! -d "$MT5_EXPERTS_BASE" ]; then
    echo "❌ MT5 Experts base folder not found at: $MT5_EXPERTS_BASE"
    exit 1
fi

# Crea la cartella BenStrategy se non esiste
if [ ! -d "$MT5_EXPERTS" ]; then
    echo "📁 Creating BenStrategy folder..."
    mkdir -p "$MT5_EXPERTS"
    echo "✅ Folder created: $MT5_EXPERTS"
else
    echo "📁 BenStrategy folder already exists"
fi

# Copia TUTTI i file .mq5 e .mqh nella cartella BenStrategy

echo "📄 Copying all files to BenStrategy folder...$PROJECT_DIR"
cp "$PROJECT_DIR"/*.mq5 "$MT5_EXPERTS/" 2>/dev/null || echo "⚠️  No .mq5 files found"
cp "$PROJECT_DIR"/*.mqh "$MT5_EXPERTS/" 2>/dev/null || echo "⚠️  No .mqh files found"

# Mostra i file copiati
echo "📋 Files in BenStrategy folder:"
ls -la "$MT5_EXPERTS"

echo "✅ Sync completed!"
echo "💡 Now go to MT5 and compile BreakoutEA.mq5 from BenStrategy folder"
echo "📂 Path: Experts → BenStrategy → BreakoutEA.mq5"

# Opzionale: apri MT5 automaticamente
# open -a "MetaTrader 5"