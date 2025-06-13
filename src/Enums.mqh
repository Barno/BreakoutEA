//+------------------------------------------------------------------+
//|                                                        Enums.mqh |
//|                                    Enumerazioni e Strutture Base |
//|                                              COMPLETE VERSION     |
//+------------------------------------------------------------------+

#ifndef ENUMS_MQH
#define ENUMS_MQH

//+------------------------------------------------------------------+
//| Enumerazioni Essenziali                                        |
//+------------------------------------------------------------------+

// Tipo di asset (auto-detection)
enum AssetType
{
   ASSET_FOREX,        // Forex pairs
   ASSET_INDICES,      // Indici  
   ASSET_CRYPTO,       // Crypto
   ASSET_COMMODITY,    // Materie prime
   ASSET_UNKNOWN       // Non riconosciuto
};

// Stato sessione trading
enum SessionState
{
   SESSION_WAITING,         // In attesa apertura
   SESSION_ACTIVE,          // Attiva con ordini
   SESSION_DONE_FOR_SESSION, // Target raggiunti
   SESSION_EXPIRED          // Scaduta
};

// Livelli di logging
enum LogLevel
{
   LOG_INFO,           // Informazioni
   LOG_WARNING,        // Avvisi
   LOG_ERROR,          // Errori
   LOG_CRITICAL        // Critici
};

//+------------------------------------------------------------------+
//| Strutture Dati Base                                            |
//+------------------------------------------------------------------+

// Dati candela di riferimento
struct CandleData
{
   datetime time;
   double   open;
   double   high;
   double   low;
   double   close;
   
   // Metodi essenziali const corretti
   double GetBody() const { return MathAbs(close - open); }
   bool IsDoji(double threshold) const { return GetBody() <= threshold; }
   
   CandleData() : time(0), open(0), high(0), low(0), close(0) {}
};

// Livelli di entrata breakout
struct EntryLevels
{
   double buyEntry;     // Buy Stop level
   double sellEntry;    // Sell Stop level  
   double buySL;        // Buy Stop Loss
   double sellSL;       // Sell Stop Loss
   bool   valid;        // Livelli validi
   
   EntryLevels() : buyEntry(0), sellEntry(0), buySL(0), sellSL(0), valid(false) {}
};

// Take Profit configuration
struct TPLevel
{
   double riskReward;   // R:R ratio (es. 2.0)
   double percentage;   // % volume (es. 50.0)
   bool   hit;          // Target raggiunto
   
   TPLevel() : riskReward(0), percentage(0), hit(false) {}
   TPLevel(double rr, double pct) : riskReward(rr), percentage(pct), hit(false) {}
};

//+------------------------------------------------------------------+
//| ✅ STRUCT PER MARGINCALCULATOR                                 |
//+------------------------------------------------------------------+

struct PositionSizeInfo
{
   double totalLots;        // Lotti totali calcolati
   double riskAmount;       // Importo rischio in USD
   double stopLossPoints;   // Distanza SL in punti
   double tickValue;        // Valore tick
   double tickSize;         // Dimensione tick
   double pointValue;       // Valore punto
   bool isValid;            // Se il calcolo è valido
   string errorReason;      // Motivo errore se non valido
   
   
   void SyncFields()
   {
      // Sincronizzazione campi per compatibilità
      if(!isValid && errorReason == "") 
         errorReason = "Invalid calculation";
   }
   
   PositionSizeInfo() : totalLots(0), riskAmount(0), stopLossPoints(0), 
                       tickValue(0), tickSize(0), isValid(false), errorReason("") {}
};

// In Enums.mqh, sostituisci MarginInfo con:

struct MarginInfo
{
   double requiredMargin;   // Margine richiesto
   double availableMargin;  // Margine disponibile
   double marginPercent;    // Percentuale utilizzo margine
   double futureUsedMargin; // Margine futuro utilizzato
   double marginUtilization; // Utilizzo margine %
   bool canOpen;            // Se può aprire posizione
   bool canOpenPosition;    // Alias per canOpen
   string errorReason;      // Motivo errore
   string lastError;        // Ultimo errore
   
   MarginInfo() : requiredMargin(0), availableMargin(0), marginPercent(0), 
                 futureUsedMargin(0), marginUtilization(0), canOpen(false), 
                 canOpenPosition(false), errorReason(""), lastError("") {}
};

//+------------------------------------------------------------------+
//| ✅ STRUCT PER ASSETDETECTOR                                    |
//+------------------------------------------------------------------+

struct AssetInfo
{
   AssetType type;          // Tipo asset rilevato
   string baseSymbol;       // Simbolo base (es. EUR in EURUSD)
   string quoteSymbol;      // Simbolo quota (es. USD in EURUSD)
   double pointValue;       // Valore punto
   double tickValue;        // Valore tick
   double tickSize;         // Dimensione tick
   double contractSize;     // Dimensione contratto
   double marginRate;       // Tasso margine
   string baseQuoteCurrency; // Formato "BASE/QUOTE"
   int digits;              // Cifre decimali
   bool isValid;            // Se informazioni sono valide
   
   AssetInfo() : type(ASSET_UNKNOWN), baseSymbol(""), quoteSymbol(""), 
                pointValue(0), tickValue(0), tickSize(0), contractSize(0), 
                marginRate(0), baseQuoteCurrency(""), digits(0), isValid(false) {}
};

//+------------------------------------------------------------------+
//| ✅ STRUCT PER CANDLEANALYZER                                   |
//+------------------------------------------------------------------+

struct CandleFilters
{
    bool corpoFilterActive;         // Se attivare filtro corpo
    double forexCorpoMinPips;       // Corpo minimo Forex (pips)
    double indicesCorpoMinPoints;   // Corpo minimo Indici (punti)
    double cryptoCorpoMinPoints;    // Corpo minimo Crypto (punti)
    double commodityCorpoMinPoints; // Corpo minimo Commodity (punti)
    
    CandleFilters() : corpoFilterActive(false), forexCorpoMinPips(5.0), 
                     indicesCorpoMinPoints(3.0), cryptoCorpoMinPoints(50.0), 
                     commodityCorpoMinPoints(5.0) {}
};

//+------------------------------------------------------------------+
//| ✅ STRUCT PER ORDERMANAGER                                     |
//+------------------------------------------------------------------+

struct OrderInfo
{
    ulong ticket;               // Ticket ordine
    string symbol;              // Simbolo
    ENUM_ORDER_TYPE type;       // Tipo ordine
    double volume;              // Volume
    double priceOpen;           // Prezzo apertura
    double sl;                  // Stop Loss
    double tp;                  // Take Profit
    long magic;                 // Magic number
    datetime timeSetup;         // Tempo setup
    string comment;             // Commento
    
    OrderInfo() : ticket(0), symbol(""), type(ORDER_TYPE_BUY), volume(0), 
                 priceOpen(0), sl(0), tp(0), magic(0), timeSetup(0), comment("") {}
};

struct PositionInfo
{
    ulong ticket;               // Ticket posizione
    string symbol;              // Simbolo
    ENUM_POSITION_TYPE type;    // Tipo posizione
    double volume;              // Volume corrente
    double volumeInitial;       // Volume iniziale
    double priceOpen;           // Prezzo apertura
    double priceCurrent;        // Prezzo corrente
    double sl;                  // Stop Loss corrente
    double tp;                  // Take Profit corrente
    double profit;              // Profitto corrente
    long magic;                 // Magic number
    datetime timeOpen;          // Tempo apertura
    string comment;             // Commento
    
    PositionInfo() : ticket(0), symbol(""), type(POSITION_TYPE_BUY), volume(0), volumeInitial(0),
                    priceOpen(0), priceCurrent(0), sl(0), tp(0), profit(0), magic(0), timeOpen(0), comment("") {}
};

struct SessionInfo
{
    int year;                   // Anno
    int month;                  // Mese
    int day;                    // Giorno
    int hour;                   // Ora
    int minute;                 // Minuto
    int sessionType;            // Tipo sessione (1=morning, 2=afternoon)
    int orderSequence;          // Sequenza ordine nella sessione
    
    SessionInfo() : year(0), month(0), day(0), hour(0), minute(0), sessionType(0), orderSequence(0) {}
};

//+------------------------------------------------------------------+
//| ✅ STRUCT PER TELEGRAMLOGGER                                   |
//+------------------------------------------------------------------+

struct TelegramConfig
{
    string botToken;        // Token bot Telegram
    string chatID;          // Chat ID destinazione
    bool enabled;           // Se notifiche sono abilitate
    int maxRetries;         // Tentativi massimi per messaggio
    int retryDelay;         // Delay tra tentativi (millisecondi)
    
    TelegramConfig() : botToken(""), chatID(""), enabled(false), maxRetries(3), retryDelay(1000) {}
};

//+------------------------------------------------------------------+
//| Calcola target multipli per strategia                          |
//+------------------------------------------------------------------+

struct RiskParameters
{
   double riskPercent;      // Percentuale rischio (es. 0.5%)
   double riskPercentage;   // Alias per compatibilità
   double tp1RiskReward;    // R:R TP1 (es. 2.0)
   double tp2RiskReward;    // R:R TP2 (es. 3.0)
   double tp1Volume;        // Volume TP1 % (es. 50.0) - ORIGINALE
   double tp2Volume;        // Volume TP2 % (es. 50.0) - ORIGINALE
   double tp1VolumePercent; // Alias per compatibilità
   double tp2VolumePercent; // Alias per compatibilità
   bool breakEvenAfterTP1;  // Breakeven dopo TP1
   
   RiskParameters() : riskPercent(0.5), riskPercentage(0.5), tp1RiskReward(2.0), tp2RiskReward(3.0),
                     tp1Volume(50.0), tp2Volume(50.0), tp1VolumePercent(50.0), tp2VolumePercent(50.0),
                     breakEvenAfterTP1(true) {}
};

// In Enums.mqh, sostituisci MultiTargetInfo con:

struct MultiTargetInfo
{
   double tp1Price;         // Prezzo TP1
   double tp2Price;         // Prezzo TP2
   double tp1Volume;        // Volume TP1 (%) - ORIGINALE
   double tp2Volume;        // Volume TP2 (%) - ORIGINALE
   double tp1Lots;          // Lotti TP1
   double tp2Lots;          // Lotti TP2
   double remainingLots;    // Lotti rimanenti
   double totalRisk;        // Rischio totale
   double riskPerTarget;    // Rischio per target
   bool isValid;            // Se calcolo è valido
   string errorReason;      // Motivo errore
   
   MultiTargetInfo() : tp1Price(0), tp2Price(0), tp1Volume(0), tp2Volume(0), 
                      tp1Lots(0), tp2Lots(0), remainingLots(0),
                      totalRisk(0), riskPerTarget(0), isValid(false), errorReason("") {}
};
//+------------------------------------------------------------------+
//| ✅ STRUCT PER TIMEMANAGER                                      |
//+------------------------------------------------------------------+

struct TradingHours
{
    int startHour;          // Ora inizio trading
    int startMinute;        // Minuto inizio trading
    int endHour;            // Ora fine trading  
    int endMinute;          // Minuto fine trading
    bool isActive;          // Se questo orario è attivo
    
    TradingHours() : startHour(0), startMinute(0), endHour(23), endMinute(59), isActive(true) {}
    TradingHours(int sH, int sM, int eH, int eM) : startHour(sH), startMinute(sM), endHour(eH), endMinute(eM), isActive(true) {}
};

struct TimeZoneInfo
{
    string timeZoneName;    // Nome timezone
    int offsetHours;        // Offset da GMT
    bool isDSTActive;       // Se ora legale è attiva
    
    TimeZoneInfo() : timeZoneName(""), offsetHours(0), isDSTActive(false) {}
};

//+------------------------------------------------------------------+
//| Costanti Essenziali                                            |
//+------------------------------------------------------------------+

#define MAX_SESSIONS 5         // Max sessioni simultanee
#define MAX_TAKEPROFIT 5       // Max take profit
#define HEARTBEAT_INTERVAL 3600 // Heartbeat ogni ora

//+------------------------------------------------------------------+
//| Funzioni Utility Essenziali                                    |
//+------------------------------------------------------------------+

string AssetTypeToString(AssetType type)
{
   switch(type)
   {
      case ASSET_FOREX:     return "FOREX";
      case ASSET_INDICES:   return "INDICES"; 
      case ASSET_CRYPTO:    return "CRYPTO";
      case ASSET_COMMODITY: return "COMMODITY";
      default:              return "UNKNOWN";
   }
}

string SessionStateToString(SessionState state)
{
   switch(state)
   {
      case SESSION_WAITING:         return "WAITING";
      case SESSION_ACTIVE:          return "ACTIVE";
      case SESSION_DONE_FOR_SESSION: return "DONE";
      case SESSION_EXPIRED:         return "EXPIRED";
      default:                      return "UNKNOWN";
   }
}

#endif // ENUMS_MQH