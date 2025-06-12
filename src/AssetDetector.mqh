//+------------------------------------------------------------------+
//|                                               AssetDetector.mqh |
//|                                     Asset Detection & Analysis   |
//|                                              SOLID Architecture  |
//+------------------------------------------------------------------+

#ifndef ASSET_DETECTOR_MQH
#define ASSET_DETECTOR_MQH

#include "Enums.mqh"

//+------------------------------------------------------------------+
//| Strutture per Margin Information                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| AssetDetector Class - Smart Asset Recognition                  |
//+------------------------------------------------------------------+
class AssetDetector
{
private:
    string m_lastError;                        // Ultimo errore
    int m_cacheTimeout;                       // Timeout cache in secondi
    
    // Cache per performance - usa AssetInfo
    AssetInfo m_cachedInfo;
    string m_cachedSymbol;
    datetime m_cacheTime;

public:
    AssetDetector();
    ~AssetDetector();
    
    // Main Interface - usa AssetInfo dal MarginCalculator
    AssetInfo DetectAsset(const string symbol);
    AssetType GetAssetType(const string symbol);
    double GetPointValue(const string symbol);
    double GetPipValue(const string symbol);
    
    // Enhanced Features
    string GetBaseSymbol(const string symbol);
    string GetQuoteSymbol(const string symbol);
    bool IsForexPair(const string symbol);
    bool IsIndex(const string symbol);
    bool IsCrypto(const string symbol);
    bool IsCommodity(const string symbol);
    
    // Configuration
    void SetCacheTimeout(int seconds) { m_cacheTimeout = seconds; }
    int GetCacheTimeout() const { return m_cacheTimeout; }
    void ClearCache();
    
    // Info & Status
    string GetLastError() const { return m_lastError; }
    int GetCacheSize() const { return (m_cachedSymbol != "") ? 1 : 0; }

private:
    // Asset Type Detection
    AssetType DetectAssetType(const string symbol);
    AssetType DetectForexPattern(const string symbol);
    AssetType DetectIndexPattern(const string symbol);
    AssetType DetectCryptoPattern(const string symbol);
    AssetType DetectCommodityPattern(const string symbol);
    
    // Symbol Analysis
    void ParseForexPair(const string symbol, string& base, string& quote);
    void ParseIndexSymbol(const string symbol, string& base, string& quote);
    void ParseCryptoSymbol(const string symbol, string& base, string& quote);
    void ParseCommoditySymbol(const string symbol, string& base, string& quote);
    
    // Point Value Calculation
    double CalculatePointValue(const string symbol, AssetType type);
    double CalculateForexPointValue(const string symbol);
    double CalculateIndexPointValue(const string symbol);
    double CalculateCryptoPointValue(const string symbol);
    double CalculateCommodityPointValue(const string symbol);
    
    // Cache Management - usa AssetInfo
    bool IsCacheValid(const string symbol);
    void UpdateCache(const string symbol, const AssetInfo& info);
    
    // Utilities
    bool IsValidCurrency(const string currency);
    string NormalizeSymbol(const string symbol);
    void SetError(const string error);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
AssetDetector::AssetDetector() : m_lastError(""),
                                m_cacheTimeout(300),
                                m_cachedSymbol(""),
                                m_cacheTime(0)
{
    Print("AssetDetector: Initialized with cache timeout ", m_cacheTimeout, " seconds");
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
AssetDetector::~AssetDetector()
{
}

//+------------------------------------------------------------------+
//| Rileva asset completo (MAIN METHOD) - usa AssetInfo           |
//+------------------------------------------------------------------+
AssetInfo AssetDetector::DetectAsset(const string symbol)
{
    // Controlla cache
    if(IsCacheValid(symbol))
    {
        return m_cachedInfo;
    }
    
    AssetInfo info;
    
    // Normalizza simbolo
    string normalizedSymbol = NormalizeSymbol(symbol);
    if(normalizedSymbol == "")
    {
        SetError("Invalid symbol: " + symbol);
        return info;
    }
    
    // Rileva tipo asset
    info.type = DetectAssetType(normalizedSymbol);
    if(info.type == ASSET_UNKNOWN)
    {
        SetError("Cannot detect asset type for: " + symbol);
        return info;
    }
    
    // Parse simboli base/quote - popola i NUOVI campi
    switch(info.type)
    {
        case ASSET_FOREX:
            ParseForexPair(normalizedSymbol, info.baseSymbol, info.quoteSymbol);
            break;
        case ASSET_INDICES:
            ParseIndexSymbol(normalizedSymbol, info.baseSymbol, info.quoteSymbol);
            break;
        case ASSET_CRYPTO:
            ParseCryptoSymbol(normalizedSymbol, info.baseSymbol, info.quoteSymbol);
            break;
        case ASSET_COMMODITY:
            ParseCommoditySymbol(normalizedSymbol, info.baseSymbol, info.quoteSymbol);
            break;
    }
    
    // Calcola point value - popola il NUOVO campo
    info.pointValue = CalculatePointValue(normalizedSymbol, info.type);
    
    // ✅ NUOVO: Popola anche i campi ORIGINALI per compatibilità
    info.contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    info.digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    info.tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    info.tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    info.marginRate = SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
    info.baseQuoteCurrency = info.baseSymbol + "/" + info.quoteSymbol;
    
    // Aggiorna cache
    UpdateCache(symbol, info);
    
    Print("AssetDetector: Detected ", symbol, " as ", AssetTypeToString(info.type));
    Print("  Base/Quote: ", info.baseSymbol, "/", info.quoteSymbol);
    Print("  Point Value: ", DoubleToString(info.pointValue, 4));
    if(info.type == ASSET_FOREX)
    {
        double pipValue = info.pointValue * 10; // 1 pip = 10 points per Forex
        Print("  Pip Value: ", DoubleToString(pipValue, 4));
    }
    
    return info;
}

//+------------------------------------------------------------------+
//| Ottiene solo il tipo asset                                     |
//+------------------------------------------------------------------+
AssetType AssetDetector::GetAssetType(const string symbol)
{
    AssetInfo info = DetectAsset(symbol);
    return info.type;
}

//+------------------------------------------------------------------+
//| Ottiene point value                                            |
//+------------------------------------------------------------------+
double AssetDetector::GetPointValue(const string symbol)
{
    AssetInfo info = DetectAsset(symbol);
    return info.pointValue;
}

//+------------------------------------------------------------------+
//| Ottiene pip value (Forex only)                                 |
//+------------------------------------------------------------------+
double AssetDetector::GetPipValue(const string symbol)
{
    AssetInfo info = DetectAsset(symbol);
    return (info.type == ASSET_FOREX) ? (info.pointValue * 10) : 0;
}

//+------------------------------------------------------------------+
//| PRIVATE METHODS - Asset Type Detection                         |
//+------------------------------------------------------------------+

AssetType AssetDetector::DetectAssetType(const string symbol)
{
    string upperSymbol = symbol;
    StringToUpper(upperSymbol);
    
    // Prova detection in ordine di priorità
    AssetType detected = DetectForexPattern(upperSymbol);
    if(detected != ASSET_UNKNOWN) return detected;
    
    detected = DetectIndexPattern(upperSymbol);
    if(detected != ASSET_UNKNOWN) return detected;
    
    detected = DetectCryptoPattern(upperSymbol);
    if(detected != ASSET_UNKNOWN) return detected;
    
    detected = DetectCommodityPattern(upperSymbol);
    if(detected != ASSET_UNKNOWN) return detected;
    
    return ASSET_UNKNOWN;
}

AssetType AssetDetector::DetectForexPattern(const string symbol)
{
    // Pattern Forex: 6-8 caratteri con valute riconosciute
    if(StringLen(symbol) < 6 || StringLen(symbol) > 8) return ASSET_UNKNOWN;
    
    // Lista valute principali
    string currencies[] = {"USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "NZD", 
                          "NOK", "SEK", "DKK", "PLN", "CZK", "HUF", "TRY", "ZAR", "CNH"};
    
    // Estrai base e quote (3 caratteri ciascuna)
    string base = StringSubstr(symbol, 0, 3);
    string quote = StringSubstr(symbol, 3, 3);
    
    // Verifica se entrambe sono valute valide
    bool baseValid = false, quoteValid = false;
    
    for(int i = 0; i < ArraySize(currencies); i++)
    {
        if(base == currencies[i]) baseValid = true;
        if(quote == currencies[i]) quoteValid = true;
    }
    
    return (baseValid && quoteValid) ? ASSET_FOREX : ASSET_UNKNOWN;
}

AssetType AssetDetector::DetectIndexPattern(const string symbol)
{
    // Pattern Indici: keywords + numeri
    string indexKeywords[] = {"DAX", "SPX", "SP500", "NAS", "NASDAQ", "FTSE", "CAC", 
                             "NIKKEI", "ASX", "HSI", "KOSPI", "SMI", "AEX", "IBEX", "US30", "US500"};
    
    for(int i = 0; i < ArraySize(indexKeywords); i++)
    {
        if(StringFind(symbol, indexKeywords[i]) >= 0)
            return ASSET_INDICES;
    }
    
    return ASSET_UNKNOWN;
}

AssetType AssetDetector::DetectCryptoPattern(const string symbol)
{
    // Pattern Crypto: keywords crypto
    string cryptoKeywords[] = {"BTC", "ETH", "LTC", "XRP", "ADA", "DOT", "LINK", 
                              "BCH", "XLM", "EOS", "TRX", "CRYPTO", "COIN"};
    
    for(int i = 0; i < ArraySize(cryptoKeywords); i++)
    {
        if(StringFind(symbol, cryptoKeywords[i]) >= 0)
            return ASSET_CRYPTO;
    }
    
    return ASSET_UNKNOWN;
}

AssetType AssetDetector::DetectCommodityPattern(const string symbol)
{
    // Pattern Commodity: metalli preziosi, energia, agricoli
    string commodityKeywords[] = {"XAU", "GOLD", "SILVER", "XAG", "CRUDE", "OIL", "BRENT", 
                                 "WTI", "GAS", "PLATINUM", "PALLADIUM", "COPPER", "WHEAT", "CORN"};
    
    for(int i = 0; i < ArraySize(commodityKeywords); i++)
    {
        if(StringFind(symbol, commodityKeywords[i]) >= 0)
            return ASSET_COMMODITY;
    }
    
    return ASSET_UNKNOWN;
}

//+------------------------------------------------------------------+
//| PRIVATE METHODS - Symbol Parsing                               |
//+------------------------------------------------------------------+

void AssetDetector::ParseForexPair(const string symbol, string& base, string& quote)
{
    if(StringLen(symbol) >= 6)
    {
        base = StringSubstr(symbol, 0, 3);
        quote = StringSubstr(symbol, 3, 3);
    }
}

void AssetDetector::ParseIndexSymbol(const string symbol, string& base, string& quote)
{
    base = symbol;  // Index name come base
    quote = "POINTS"; // Unità di misura
}

void AssetDetector::ParseCryptoSymbol(const string symbol, string& base, string& quote)
{
    // Cerca pattern BTCUSD, ETHUSD, etc.
    if(StringFind(symbol, "USD") >= 0)
    {
        int usdPos = StringFind(symbol, "USD");
        base = StringSubstr(symbol, 0, usdPos);
        quote = "USD";
    }
    else if(StringFind(symbol, "EUR") >= 0)
    {
        int eurPos = StringFind(symbol, "EUR");
        base = StringSubstr(symbol, 0, eurPos);
        quote = "EUR";
    }
    else
    {
        base = symbol;
        quote = "CRYPTO";
    }
}

void AssetDetector::ParseCommoditySymbol(const string symbol, string& base, string& quote)
{
    // Commodity vs USD principalmente
    if(StringFind(symbol, "USD") >= 0)
    {
        int usdPos = StringFind(symbol, "USD");
        base = StringSubstr(symbol, 0, usdPos);
        quote = "USD";
    }
    else
    {
        base = symbol;
        quote = "USD"; // Default per commodity
    }
}

//+------------------------------------------------------------------+
//| PRIVATE METHODS - Point Value Calculation                      |
//+------------------------------------------------------------------+

double AssetDetector::CalculatePointValue(const string symbol, AssetType type)
{
    switch(type)
    {
        case ASSET_FOREX:
            return CalculateForexPointValue(symbol);
        case ASSET_INDICES:
            return CalculateIndexPointValue(symbol);
        case ASSET_CRYPTO:
            return CalculateCryptoPointValue(symbol);
        case ASSET_COMMODITY:
            return CalculateCommodityPointValue(symbol);
        default:
            return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    }
}

double AssetDetector::CalculateForexPointValue(const string symbol)
{
    // Per Forex, MT5 calcola già correttamente il tick value
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickSize > 0)
    {
        // Point value = tick value / tick size
        return tickValue / tickSize;
    }
    
    return tickValue;
}

double AssetDetector::CalculateIndexPointValue(const string symbol)
{
    // Per indici: generalmente tick value È il point value
    return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
}

double AssetDetector::CalculateCryptoPointValue(const string symbol)
{
    // Per crypto: simile a Forex
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickSize > 0)
    {
        return tickValue / tickSize;
    }
    
    return tickValue;
}

double AssetDetector::CalculateCommodityPointValue(const string symbol)
{
    // Per commodity: tick value
    return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
}

//+------------------------------------------------------------------+
//| PRIVATE METHODS - Cache & Utilities                            |
//+------------------------------------------------------------------+

bool AssetDetector::IsCacheValid(const string symbol)
{
    return (symbol == m_cachedSymbol && 
            TimeCurrent() - m_cacheTime < m_cacheTimeout);
}

void AssetDetector::UpdateCache(const string symbol, const AssetInfo& info)
{
    m_cachedSymbol = symbol;
    m_cachedInfo = info;
    m_cacheTime = TimeCurrent();
}

void AssetDetector::ClearCache()
{
    m_cachedSymbol = "";
    m_cacheTime = 0;
}

string AssetDetector::NormalizeSymbol(const string symbol)
{
    if(symbol == "") return "";
    
    string normalized = symbol;
    StringToUpper(normalized);
    StringTrimLeft(normalized);
    StringTrimRight(normalized);
    
    return normalized;
}

void AssetDetector::SetError(const string error)
{
    m_lastError = error;
    Print("AssetDetector ERROR: ", error);
}

//+------------------------------------------------------------------+
//| PUBLIC HELPER METHODS                                          |
//+------------------------------------------------------------------+

string AssetDetector::GetBaseSymbol(const string symbol)
{
    AssetInfo info = DetectAsset(symbol);
    return info.baseSymbol;
}

string AssetDetector::GetQuoteSymbol(const string symbol)
{
    AssetInfo info = DetectAsset(symbol);
    return info.quoteSymbol;
}

bool AssetDetector::IsForexPair(const string symbol)
{
    return GetAssetType(symbol) == ASSET_FOREX;
}

bool AssetDetector::IsIndex(const string symbol)
{
    return GetAssetType(symbol) == ASSET_INDICES;
}

bool AssetDetector::IsCrypto(const string symbol)
{
    return GetAssetType(symbol) == ASSET_CRYPTO;
}

bool AssetDetector::IsCommodity(const string symbol)
{
    return GetAssetType(symbol) == ASSET_COMMODITY;
}

#endif // ASSET_DETECTOR_MQH