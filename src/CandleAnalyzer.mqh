//+------------------------------------------------------------------+
//|                                              CandleAnalyzer.mqh |
//|                                    Analisi Candele di Riferimento |
//|                                              Single Responsibility |
//+------------------------------------------------------------------+

#ifndef CANDLE_ANALYZER_MQH
#define CANDLE_ANALYZER_MQH

#include "Enums.mqh"
#include "AssetDetector.mqh"

//+------------------------------------------------------------------+
//| CandleAnalyzer Class                                            |
//+------------------------------------------------------------------+
class CandleAnalyzer
{
private:
    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    double m_spreadBuffer;
    double m_entryDistance;
    double m_slDistance;
    string m_lastError;
    
    AssetDetector* m_assetDetector;     // Reference per asset detection

public:
    CandleAnalyzer();
    ~CandleAnalyzer();
    
    // Main interface
    bool Initialize(const string symbol, ENUM_TIMEFRAMES timeframe, AssetDetector* assetDetector, double spreadBuffer = 2.0);
    bool GetReferenceCandleData(datetime sessionTime, CandleData& candleData);
    EntryLevels CalculateEntryLevels(const CandleData& candleData);
    bool ValidateSetup(const EntryLevels& levels);
    bool PassesCorporeFilter(const CandleData& candleData, const CandleFilters& filters);
    
    // Getters
    string GetSymbol() const { return m_symbol; }
    ENUM_TIMEFRAMES GetTimeframe() const { return m_timeframe; }
    string GetLastError() const { return m_lastError; }

private:
    bool FindReferenceCandleIndex(datetime sessionTime, int& candleIndex);
    double GetPoint();
    double GetSpread();
    bool ValidateSpreadConditions();
    double AdjustForSpread(double price, bool isBuyLevel);
    void SetError(const string error);
    bool IsValidCandleData(const CandleData& candleData);
    double GetCorpoMinimo(AssetType assetType, const CandleFilters& filters);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CandleAnalyzer::CandleAnalyzer() : m_symbol(""),
                                  m_timeframe(PERIOD_CURRENT),
                                  m_spreadBuffer(2.0),
                                  m_entryDistance(1.0),
                                  m_slDistance(1.0),
                                  m_lastError(""),
                                  m_assetDetector(NULL)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CandleAnalyzer::~CandleAnalyzer()
{
    m_assetDetector = NULL; // Non eliminiamo perché non è di nostra proprietà
}

//+------------------------------------------------------------------+
//| Inizializza CandleAnalyzer                                     |
//+------------------------------------------------------------------+
bool CandleAnalyzer::Initialize(const string symbol, ENUM_TIMEFRAMES timeframe, AssetDetector* assetDetector, double spreadBuffer = 2.0)
{
    Print("CandleAnalyzer: Initializing for ", symbol, " on ", EnumToString(timeframe));
    
    if(symbol == "")
    {
        SetError("Empty symbol provided");
        return false;
    }
    
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_spreadBuffer = spreadBuffer;
    m_assetDetector = assetDetector;
    
    // Converti spread buffer in points
    double point = GetPoint();
    m_entryDistance = m_spreadBuffer * point;
    m_slDistance = m_spreadBuffer * point;
    
    // Verifica che il simbolo sia disponibile
    if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
    {
        SetError("Symbol not available: " + symbol);
        return false;
    }
    
    Print("CandleAnalyzer: Point value = ", point, ", Entry distance = ", m_entryDistance);
    Print("CandleAnalyzer: Initialized successfully");
    
    return true;
}

//+------------------------------------------------------------------+
//| Ottiene dati candela di riferimento                            |
//+------------------------------------------------------------------+
bool CandleAnalyzer::GetReferenceCandleData(datetime sessionTime, CandleData& candleData)
{
    Print("CandleAnalyzer: Getting reference candle for session time: ", TimeToString(sessionTime, TIME_DATE | TIME_MINUTES));
    
    int candleIndex;
    if(!FindReferenceCandleIndex(sessionTime, candleIndex))
    {
        SetError("Cannot find reference candle for session time");
        return false;
    }
    
    // Estrai dati OHLC
    candleData.time = iTime(m_symbol, m_timeframe, candleIndex);
    candleData.open = iOpen(m_symbol, m_timeframe, candleIndex);
    candleData.high = iHigh(m_symbol, m_timeframe, candleIndex);
    candleData.low = iLow(m_symbol, m_timeframe, candleIndex);
    candleData.close = iClose(m_symbol, m_timeframe, candleIndex);
    
    // Validazione dati
    if(!IsValidCandleData(candleData))
    {
        SetError("Invalid candle data retrieved");
        return false;
    }
    
    // Log dati candela
    Print("=== REFERENCE CANDLE DATA ===");
    Print("Time: ", TimeToString(candleData.time, TIME_DATE | TIME_MINUTES));
    Print("OHLC: O=", DoubleToString(candleData.open, _Digits), 
          " H=", DoubleToString(candleData.high, _Digits),
          " L=", DoubleToString(candleData.low, _Digits), 
          " C=", DoubleToString(candleData.close, _Digits));
    Print("Body: ", DoubleToString(candleData.GetBody(), _Digits), 
          " | Range: ", DoubleToString(candleData.high - candleData.low, _Digits));
    
    return true;
}

//+------------------------------------------------------------------+
//| Calcola livelli di entrata                                     |
//+------------------------------------------------------------------+
EntryLevels CandleAnalyzer::CalculateEntryLevels(const CandleData& candleData)
{
    EntryLevels levels;
    
    if(!IsValidCandleData(candleData))
    {
        SetError("Invalid candle data for entry levels calculation");
        return levels;
    }
    
    // Calcola livelli base
    levels.buyEntry = candleData.high + m_entryDistance;
    levels.sellEntry = candleData.low - m_entryDistance;
    levels.buySL = candleData.low - m_slDistance;
    levels.sellSL = candleData.high + m_slDistance;
    
    // Ottieni prezzi correnti
    MqlTick tick;
    if(!SymbolInfoTick(m_symbol, tick))
    {
        SetError("Cannot get current tick data");
        return levels;
    }
    
    // Aggiusta per spread se necessario
    double spread = tick.ask - tick.bid;
    double spreadPoints = spread / GetPoint();
    
    Print("CandleAnalyzer: Current spread = ", DoubleToString(spreadPoints, 1), " points");
    
    // Se i livelli sono troppo vicini allo spread, aggiusta
    if(MathAbs(levels.buyEntry - tick.ask) < spread * 2)
    {
        levels.buyEntry = tick.ask + spread + m_entryDistance;
        Print("CandleAnalyzer: Adjusted buy entry for spread: ", DoubleToString(levels.buyEntry, _Digits));
    }
    
    if(MathAbs(levels.sellEntry - tick.bid) < spread * 2)
    {
        levels.sellEntry = tick.bid - spread - m_entryDistance;
        Print("CandleAnalyzer: Adjusted sell entry for spread: ", DoubleToString(levels.sellEntry, _Digits));
    }
    
    // Validazione finale livelli
    if(levels.buyEntry <= levels.buySL || levels.sellEntry >= levels.sellSL)
    {
        SetError("Invalid entry levels calculated");
        return levels;
    }
    
    levels.valid = true;
    
    // Log livelli calcolati
    Print("=== ENTRY LEVELS CALCULATED ===");
    Print("Buy Entry: ", DoubleToString(levels.buyEntry, _Digits), " | SL: ", DoubleToString(levels.buySL, _Digits));
    Print("Sell Entry: ", DoubleToString(levels.sellEntry, _Digits), " | SL: ", DoubleToString(levels.sellSL, _Digits));
    Print("Buy Risk: ", DoubleToString((levels.buyEntry - levels.buySL) / GetPoint(), 1), " points");
    Print("Sell Risk: ", DoubleToString((levels.sellSL - levels.sellEntry) / GetPoint(), 1), " points");
    
    return levels;
}

//+------------------------------------------------------------------+
//| Valida setup completo                                          |
//+------------------------------------------------------------------+
bool CandleAnalyzer::ValidateSetup(const EntryLevels& levels)
{
    if(!levels.valid)
    {
        SetError("Entry levels are not valid");
        return false;
    }
    
    // Verifica spread corrente
    if(!ValidateSpreadConditions())
    {
        SetError("Spread conditions not met");
        return false;
    }
    
    // Verifica che i livelli abbiano senso
    double buyRisk = levels.buyEntry - levels.buySL;
    double sellRisk = levels.sellSL - levels.sellEntry;
    
    if(buyRisk <= 0 || sellRisk <= 0)
    {
        SetError("Invalid risk calculation");
        return false;
    }
    
    // Verifica che i rischi siano simili (sanity check)
    double riskRatio = MathMax(buyRisk, sellRisk) / MathMin(buyRisk, sellRisk);
    if(riskRatio > 2.0)
    {
        SetError("Risk asymmetry too high between buy and sell");
        return false;
    }
    
    Print("CandleAnalyzer: Setup validation PASSED");
    return true;
}

//+------------------------------------------------------------------+
//| Verifica filtro corpo candela                                  |
//+------------------------------------------------------------------+
bool CandleAnalyzer::PassesCorporeFilter(const CandleData& candleData, const CandleFilters& filters)
{
    if(!filters.corpoFilterActive)
    {
        Print("CandleAnalyzer: Corpo filter DISABLED - Setup accepted");
        return true;
    }
    
    // Ottieni tipo asset
    AssetType assetType = ASSET_UNKNOWN;
    if(m_assetDetector != NULL)
    {
        assetType = m_assetDetector.GetAssetType(m_symbol);
    }
    
    // Calcola corpo minimo richiesto
    double corpoMinimo = GetCorpoMinimo(assetType, filters);
    double corpoEffettivo = candleData.GetBody();
    
    // Converti in unità appropriate
    if(assetType == ASSET_FOREX)
    {
        double corpoMinimoPrice = corpoMinimo * GetPoint() * 10; // Converti pips a prezzo
        bool passed = (corpoEffettivo >= corpoMinimoPrice);
        
        Print("CandleAnalyzer: Corpo filter (FOREX):");
        Print("  Required: ", DoubleToString(corpoMinimo, 1), " pips (", DoubleToString(corpoMinimoPrice, _Digits), ")");
        Print("  Actual: ", DoubleToString(corpoEffettivo, _Digits), " (", DoubleToString(corpoEffettivo / (GetPoint() * 10), 1), " pips)");
        Print("  Result: ", passed ? "PASSED" : "FAILED");
        
        return passed;
    }
    else
    {
        double corpoMinimoPrice = corpoMinimo * GetPoint(); // Converti punti a prezzo
        bool passed = (corpoEffettivo >= corpoMinimoPrice);
        
        Print("CandleAnalyzer: Corpo filter (", AssetTypeToString(assetType), "):");
        Print("  Required: ", DoubleToString(corpoMinimo, 1), " points (", DoubleToString(corpoMinimoPrice, _Digits), ")");
        Print("  Actual: ", DoubleToString(corpoEffettivo, _Digits), " (", DoubleToString(corpoEffettivo / GetPoint(), 1), " points)");
        Print("  Result: ", passed ? "PASSED" : "FAILED");
        
        return passed;
    }
}

//+------------------------------------------------------------------+
//| PRIVATE METHODS                                                 |
//+------------------------------------------------------------------+

bool CandleAnalyzer::FindReferenceCandleIndex(datetime sessionTime, int& candleIndex)
{
    // Cerca la candela che contiene il tempo di sessione
    candleIndex = iBarShift(m_symbol, m_timeframe, sessionTime);
    
    if(candleIndex < 0)
    {
        SetError("Cannot find candle for session time");
        return false;
    }
    
    // Verifica che abbiamo dati sufficienti
    int totalBars = iBars(m_symbol, m_timeframe);
    if(candleIndex >= totalBars - 1)
    {
        SetError("Insufficient candle data available");
        return false;
    }
    
    Print("CandleAnalyzer: Found reference candle at index ", candleIndex);
    return true;
}

double CandleAnalyzer::GetPoint()
{
    return SymbolInfoDouble(m_symbol, SYMBOL_POINT);
}

double CandleAnalyzer::GetSpread()
{
    MqlTick tick;
    if(SymbolInfoTick(m_symbol, tick))
    {
        return tick.ask - tick.bid;
    }
    return 0;
}

bool CandleAnalyzer::ValidateSpreadConditions()
{
    double spread = GetSpread();
    double spreadPoints = spread / GetPoint();
    
    // Usa un limite di spread massimo (es. 10 punti per Forex)
    double maxSpreadPoints = 50.0; // Configurabile
    
    if(spreadPoints > maxSpreadPoints)
    {
        SetError("Spread too high: " + DoubleToString(spreadPoints, 1) + " points");
        return false;
    }
    
    Print("CandleAnalyzer: Spread validation OK: ", DoubleToString(spreadPoints, 1), " points");
    return true;
}

void CandleAnalyzer::SetError(const string error)
{
    m_lastError = error;
    Print("CandleAnalyzer ERROR: ", error);
}

bool CandleAnalyzer::IsValidCandleData(const CandleData& candleData)
{
    return (candleData.high > candleData.low && 
            candleData.open > 0 && 
            candleData.close > 0 &&
            candleData.high >= candleData.open &&
            candleData.high >= candleData.close &&
            candleData.low <= candleData.open &&
            candleData.low <= candleData.close);
}

double CandleAnalyzer::GetCorpoMinimo(AssetType assetType, const CandleFilters& filters)
{
    switch(assetType)
    {
        case ASSET_FOREX:
            return filters.forexCorpoMinPips;
        case ASSET_INDICES:
            return filters.indicesCorpoMinPoints;
        case ASSET_CRYPTO:
            return filters.cryptoCorpoMinPoints;
        case ASSET_COMMODITY:
            return filters.commodityCorpoMinPoints;
        default:
            return filters.forexCorpoMinPips; // Default fallback
    }
}

#endif // CANDLE_ANALYZER_MQH