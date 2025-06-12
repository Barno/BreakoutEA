//+------------------------------------------------------------------+
//|                                              TelegramLogger.mqh |
//|                                    Telegram Notifications System |
//|                                              Versione Semplificata |
//+------------------------------------------------------------------+

#ifndef TELEGRAM_LOGGER_MQH
#define TELEGRAM_LOGGER_MQH

#include "Enums.mqh"

//+------------------------------------------------------------------+
//| Strutture per configurazione Telegram                          |
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
//| TelegramLogger Class - Versione Base                           |
//+------------------------------------------------------------------+
class TelegramLogger
{
private:
    TelegramConfig m_config;                    // Configurazione
    string m_lastError;                        // Ultimo errore
    int m_messagesSent;                        // Contatore messaggi inviati
    datetime m_lastMessageTime;               // Ultimo messaggio inviato
    
    // Rate limiting semplice
    int m_messagesThisHour;                   // Messaggi nell'ora corrente
    datetime m_hourStartTime;                 // Inizio ora corrente

public:
    TelegramLogger();
    ~TelegramLogger();
    
    // Main Interface
    bool Initialize(const TelegramConfig& config);
    bool IsEnabled() const { return m_config.enabled; }
    
    // Debug & Monitoring Messages
    bool SendServerTimeCheck(datetime serverTime, datetime expectedTime = 0);
    bool SendSessionAlert(const string sessionName, datetime sessionTime, bool isForming);
    bool SendCandleOHLC(const string sessionName, double open, double high, double low, double close);
    bool SendSystemHealth(const string status, const string details = "");
    
    // Info & Status
    string GetLastError() const { return m_lastError; }
    int GetMessagesSent() const { return m_messagesSent; }
    datetime GetLastMessageTime() const { return m_lastMessageTime; }
    bool SendTelegramMessage(const string messageText);

private:
    // Core functionality
    bool ValidateConfig() const;
    bool CheckRateLimit();
    void SetError(const string error);
    string EscapeText(const string text);
    string FormatTime(datetime time);
    string FormatPrice(double price);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
TelegramLogger::TelegramLogger() : m_lastError(""),
                                  m_messagesSent(0),
                                  m_lastMessageTime(0),
                                  m_messagesThisHour(0),
                                  m_hourStartTime(0)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
TelegramLogger::~TelegramLogger()
{
}

//+------------------------------------------------------------------+
//| Inizializza TelegramLogger                                      |
//+------------------------------------------------------------------+
bool TelegramLogger::Initialize(const TelegramConfig& config)
{
    Print("TelegramLogger: Initializing...");
    
    m_config = config;
    m_lastError = "";
    
    if(!ValidateConfig())
    {
        return false;
    }
    
    m_hourStartTime = TimeCurrent();
    m_messagesThisHour = 0;
    
    Print("TelegramLogger: Initialized successfully");
    Print("Bot Token: ", StringLen(m_config.botToken) > 0 ? "***SET***" : "NOT SET");
    Print("Chat ID: ", m_config.chatID);
    Print("Enabled: ", m_config.enabled ? "YES" : "NO");
    
    return true;
}

//+------------------------------------------------------------------+
//| Invia controllo orario server                                  |
//+------------------------------------------------------------------+
bool TelegramLogger::SendServerTimeCheck(datetime serverTime, datetime expectedTime = 0)
{
    if(!m_config.enabled) return true;
    
    if(!CheckRateLimit()) return false;
    
    string message = "🕐 *SERVER TIME CHECK*\n";
    message += "Server Time: `" + FormatTime(serverTime) + "`\n";
    message += "Symbol: " + Symbol() + "\n";
    message += "Timeframe: " + EnumToString(Period());
    
    return SendTelegramMessage(message);
}

//+------------------------------------------------------------------+
//| Invia alert sessione                                           |
//+------------------------------------------------------------------+
bool TelegramLogger::SendSessionAlert(const string sessionName, datetime sessionTime, bool isForming)
{
    if(!m_config.enabled) return true;
    
    if(!CheckRateLimit()) return false;
    
    string emoji = isForming ? "🔔" : "✅";
    string status = isForming ? "FORMING" : "CLOSED";
    
    string message = emoji + " *" + sessionName + " " + status + "*\n";
    message += "Time: `" + FormatTime(sessionTime) + "`\n";
    message += "Symbol: " + Symbol();
    
    return SendTelegramMessage(message);
}

//+------------------------------------------------------------------+
//| Invia dati OHLC candela                                        |
//+------------------------------------------------------------------+
bool TelegramLogger::SendCandleOHLC(const string sessionName, double open, double high, double low, double close)
{
    if(!m_config.enabled) return true;
    
    if(!CheckRateLimit()) return false;
    
    double body = MathAbs(close - open);
    double range = high - low;
    
    string message = "📈 *" + sessionName + " OHLC*\n";
    message += "Open: `" + FormatPrice(open) + "`\n";
    message += "High: `" + FormatPrice(high) + "`\n";
    message += "Low: `" + FormatPrice(low) + "`\n";
    message += "Close: `" + FormatPrice(close) + "`\n";
    message += "Body: `" + FormatPrice(body) + "`\n";
    message += "Range: `" + FormatPrice(range) + "`";
    
    return SendTelegramMessage(message);
}

//+------------------------------------------------------------------+
//| Invia stato sistema                                            |
//+------------------------------------------------------------------+
bool TelegramLogger::SendSystemHealth(const string status, const string details = "")
{
    if(!m_config.enabled) return true;
    
    string emoji = "ℹ️";
    if(status == "STARTUP") emoji = "🚀";
    else if(status == "SHUTDOWN") emoji = "🛑";
    else if(status == "ERROR") emoji = "❌";
    
    string message = emoji + " *SYSTEM " + status + "*\n";
    if(details != "")
    {
        message += details;
    }
    
    return SendTelegramMessage(message);
}

//+------------------------------------------------------------------+
//| Invia messaggio via Telegram API                               |
//+------------------------------------------------------------------+
bool TelegramLogger::SendTelegramMessage(const string messageText)
{
    if(StringLen(m_config.botToken) == 0 || StringLen(m_config.chatID) == 0)
    {
        SetError("Bot token or chat ID not configured");
        return false;
    }
    
    // Costruisci i dati POST
    string postData = "chat_id=" + m_config.chatID + "&text=" + messageText;
    
    // CAMBIA: usa char array (come documentazione)
    char data[];
    int data_size = StringLen(postData);
    StringToCharArray(postData, data, 0, data_size);
    
    // CAMBIA: usa char array per risultato
    char result[];
    string result_headers;
    
    string url = "https://api.telegram.org/bot" + m_config.botToken + "/sendMessage";
    
    // WebRequest con parametri corretti
    int response = WebRequest("POST", url, NULL, NULL, 5000, data, data_size, result, result_headers);
    
    if(response == 200)
    {
        m_messagesSent++;
        m_lastMessageTime = TimeCurrent();
        Print("TelegramLogger: Message sent successfully");
        return true;
    }
    else
    {
        string error = "HTTP Response: " + IntegerToString(response);
        if(ArraySize(result) > 0)
        {
            // CAMBIA: conversione corretta char array
            string responseText = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
            error += " | Response: " + responseText;
        }
        SetError(error);
        Print("TelegramLogger ERROR: ", error);
        return false;
    }
}


//+------------------------------------------------------------------+
//| Valida configurazione                                          |
//+------------------------------------------------------------------+
bool TelegramLogger::ValidateConfig() const
{
    if(!m_config.enabled)
    {
        Print("TelegramLogger: Disabled by configuration");
        return true; // Non è un errore se disabilitato
    }
    
    if(StringLen(m_config.botToken) == 0)
    {
        Print("TelegramLogger ERROR: Bot token not provided");
        return false;
    }
    
    if(StringLen(m_config.chatID) == 0)
    {
        Print("TelegramLogger ERROR: Chat ID not provided");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Controlla rate limiting                                        |
//+------------------------------------------------------------------+
bool TelegramLogger::CheckRateLimit()
{
    datetime currentTime = TimeCurrent();
    
    // Reset contatore se è passata un'ora
    if(currentTime - m_hourStartTime >= 3600)
    {
        m_hourStartTime = currentTime;
        m_messagesThisHour = 0;
    }
    
    // Limite di 20 messaggi per ora
    if(m_messagesThisHour >= 20)
    {
        SetError("Rate limit exceeded (20 messages/hour)");
        return false;
    }
    
    m_messagesThisHour++;
    return true;
}

//+------------------------------------------------------------------+
//| Imposta errore                                                 |
//+------------------------------------------------------------------+
void TelegramLogger::SetError(const string error)
{
    m_lastError = error;
    Print("TelegramLogger ERROR: ", error);
}

//+------------------------------------------------------------------+
//| Escape caratteri speciali per Markdown (per adesso Non utilizzata)|
//+------------------------------------------------------------------+
string TelegramLogger::EscapeText(const string text)
{
    string escaped = text;
    
    // URL encode caratteri speciali
    escaped = StringReplace(escaped, "+", "%2B");
    escaped = StringReplace(escaped, " ", "+");
    escaped = StringReplace(escaped, "&", "%26");
    escaped = StringReplace(escaped, "=", "%3D");
    escaped = StringReplace(escaped, "\n", "%0A");
    escaped = StringReplace(escaped, "*", "%2A");
    escaped = StringReplace(escaped, "_", "%5F");
    escaped = StringReplace(escaped, "`", "%60");
    
    return escaped;
}

//+------------------------------------------------------------------+
//| Formatta tempo                                                 |
//+------------------------------------------------------------------+
string TelegramLogger::FormatTime(datetime time)
{
    return TimeToString(time, TIME_DATE | TIME_MINUTES);
}

//+------------------------------------------------------------------+
//| Formatta prezzo                                                |
//+------------------------------------------------------------------+
string TelegramLogger::FormatPrice(double price)
{
    return DoubleToString(price, _Digits);
}

#endif // TELEGRAM_LOGGER_MQH