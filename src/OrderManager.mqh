//+------------------------------------------------------------------+
//|                                                OrderManager.mqh |
//|                                      Order Execution & Management |
//|                                              Single Responsibility |
//+------------------------------------------------------------------+

#ifndef ORDER_MANAGER_MQH
#define ORDER_MANAGER_MQH

#include "Enums.mqh"

//+------------------------------------------------------------------+
//| OrderManager Class                                              |
//+------------------------------------------------------------------+
class OrderManager
{
private:
    string m_lastError;
    int m_maxRetries;
    int m_retryDelay;
    int m_slippage;
    
    // Magic number generation
    long m_baseMagic;
    
public:
    OrderManager();
    ~OrderManager();
    
    // Main interface
    bool Initialize(long baseMagic = 123456, int maxRetries = 3, int retryDelay = 100);
    
    // Order placement
    ulong CreateBuyStopOrder(const string symbol, double lots, double price, double sl, double tp = 0, const string comment = "", long magic = 0);
    ulong CreateSellStopOrder(const string symbol, double lots, double price, double sl, double tp = 0, const string comment = "", long magic = 0);
    
    // Order management
    bool ModifyOrder(ulong ticket, double price, double sl, double tp);
    bool DeleteOrder(ulong ticket);
    bool ClosePosition(ulong ticket);
    bool ClosePartialPosition(ulong ticket, double volume);
    
    // Order info
    bool GetOrderInfo(ulong ticket, OrderInfo& orderInfo);
    bool GetPositionInfo(ulong ticket, PositionInfo& positionInfo);
    
    // Magic number utilities
    long GenerateSessionMagic(int sessionType);
    SessionInfo ParseMagicNumber(long magic);
    
    // Bulk operations
    int GetOrdersByMagic(long magic, ulong& tickets[]);
    int GetPositionsByMagic(long magic, ulong& tickets[]);
    bool DeleteOrdersByMagic(long magic);
    bool ClosePositionsByMagic(long magic);
    
    // Configuration
    void SetMaxRetries(int retries) { m_maxRetries = retries; }
    void SetRetryDelay(int delayMs) { m_retryDelay = delayMs; }
    void SetSlippage(int slippagePoints) { m_slippage = slippagePoints; }
    
    // Info
    string GetLastError() const { return m_lastError; }

private:
    // Core order operations with retry
    ulong SendOrderWithRetry(MqlTradeRequest& request);
    bool ModifyOrderWithRetry(ulong ticket, double price, double sl, double tp);
    bool DeleteOrderWithRetry(ulong ticket);
    bool ClosePositionWithRetry(ulong ticket, double volume = 0);
    
    // Validation
    bool ValidateOrderRequest(const MqlTradeRequest& request);
    bool ValidateSymbol(const string symbol);
    bool ValidateVolume(const string symbol, double volume);
    bool ValidatePrices(const string symbol, double price, double sl, double tp);
    
    // Utilities
    void SetError(const string error);
    void LogTradeResult(const MqlTradeResult& result, const string operation);
    bool IsRetryableError(int errorCode);
    void Sleep(int milliseconds);
    string GetTradeActionString(ENUM_TRADE_REQUEST_ACTIONS action);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
OrderManager::OrderManager() : m_lastError(""),
                              m_maxRetries(3),
                              m_retryDelay(100),
                              m_slippage(10),
                              m_baseMagic(123456)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
OrderManager::~OrderManager()
{
}

//+------------------------------------------------------------------+
//| Inizializza OrderManager                                        |
//+------------------------------------------------------------------+
bool OrderManager::Initialize(long baseMagic = 123456, int maxRetries = 3, int retryDelay = 100)
{
    Print("OrderManager: Initializing...");
    
    m_baseMagic = baseMagic;
    m_maxRetries = maxRetries;
    m_retryDelay = retryDelay;
    
    Print("OrderManager: Base magic = ", m_baseMagic);
    Print("OrderManager: Max retries = ", m_maxRetries);
    Print("OrderManager: Retry delay = ", m_retryDelay, "ms");
    Print("OrderManager: Initialized successfully");
    
    return true;
}

//+------------------------------------------------------------------+
//| Crea ordine Buy Stop                                           |
//+------------------------------------------------------------------+
ulong OrderManager::CreateBuyStopOrder(const string symbol, double lots, double price, double sl, double tp = 0, const string comment = "", long magic = 0)
{
    Print("OrderManager: Creating Buy Stop order for ", symbol);
    Print("  Lots: ", DoubleToString(lots, 3));
    Print("  Price: ", DoubleToString(price, _Digits));
    Print("  SL: ", DoubleToString(sl, _Digits));
    Print("  TP: ", DoubleToString(tp, _Digits));
    
    // Prepara request
    MqlTradeRequest request = {};
    request.action = TRADE_ACTION_PENDING;
    request.type = ORDER_TYPE_BUY_STOP;
    request.symbol = symbol;
    request.volume = lots;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = m_slippage;
    request.magic = (magic == 0) ? GenerateSessionMagic(1) : magic;
    request.comment = (comment == "") ? "BreakoutEA BuyStop" : comment;
    request.type_filling = ORDER_FILLING_FOK;
    
    // Validazione
    if(!ValidateOrderRequest(request))
    {
        return 0;
    }
    
    // Invia ordine con retry
    ulong ticket = SendOrderWithRetry(request);
    
    if(ticket > 0)
    {
        Print("✅ Buy Stop order created successfully: #", ticket);
    }
    else
    {
        Print("❌ Failed to create Buy Stop order: ", m_lastError);
    }
    
    return ticket;
}

//+------------------------------------------------------------------+
//| Crea ordine Sell Stop                                          |
//+------------------------------------------------------------------+
ulong OrderManager::CreateSellStopOrder(const string symbol, double lots, double price, double sl, double tp = 0, const string comment = "", long magic = 0)
{
    Print("OrderManager: Creating Sell Stop order for ", symbol);
    Print("  Lots: ", DoubleToString(lots, 3));
    Print("  Price: ", DoubleToString(price, _Digits));
    Print("  SL: ", DoubleToString(sl, _Digits));
    Print("  TP: ", DoubleToString(tp, _Digits));
    
    // Prepara request
    MqlTradeRequest request = {};
    request.action = TRADE_ACTION_PENDING;
    request.type = ORDER_TYPE_SELL_STOP;
    request.symbol = symbol;
    request.volume = lots;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = m_slippage;
    request.magic = (magic == 0) ? GenerateSessionMagic(1) : magic;
    request.comment = (comment == "") ? "BreakoutEA SellStop" : comment;
    request.type_filling = ORDER_FILLING_FOK;
    
    // Validazione
    if(!ValidateOrderRequest(request))
    {
        return 0;
    }
    
    // Invia ordine con retry
    ulong ticket = SendOrderWithRetry(request);
    
    if(ticket > 0)
    {
        Print("✅ Sell Stop order created successfully: #", ticket);
    }
    else
    {
        Print("❌ Failed to create Sell Stop order: ", m_lastError);
    }
    
    return ticket;
}

//+------------------------------------------------------------------+
//| Genera magic number per sessione                               |
//+------------------------------------------------------------------+
long OrderManager::GenerateSessionMagic(int sessionType)
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    // Format: YYMMDDHHMM + SessionType (ultimo digit)
    long magic = (dt.year % 100) * 100000000L +  // YY
                 dt.mon * 1000000L +              // MM
                 dt.day * 10000L +                // DD
                 dt.hour * 100L +                 // HH
                 dt.min * 1L +                    // MM
                 sessionType;                     // Session type
    
    Print("OrderManager: Generated magic number: ", magic, " for session type ", sessionType);
    return magic;
}

//+------------------------------------------------------------------+
//| Parse magic number per estrarre info sessione                  |
//+------------------------------------------------------------------+
SessionInfo OrderManager::ParseMagicNumber(long magic)
{
    SessionInfo info;
    
    info.sessionType = (int)(magic % 10);
    magic /= 10;
    info.minute = (int)(magic % 100);
    magic /= 100;
    info.hour = (int)(magic % 100);
    magic /= 100;
    info.day = (int)(magic % 100);
    magic /= 100;
    info.month = (int)(magic % 100);
    magic /= 100;
    info.year = (int)(magic % 100) + 2000;
    
    return info;
}

//+------------------------------------------------------------------+
//| Invia ordine con retry logic                                   |
//+------------------------------------------------------------------+
ulong OrderManager::SendOrderWithRetry(MqlTradeRequest& request)
{
    MqlTradeResult result = {};
    
    for(int attempt = 1; attempt <= m_maxRetries; attempt++)
    {
        Print("OrderManager: Sending order (attempt ", attempt, "/", m_maxRetries, ")");
        
        ResetLastError();
        bool success = OrderSend(request, result);
        
        LogTradeResult(result, GetTradeActionString(request.action));
        
        if(success && result.retcode == TRADE_RETCODE_DONE)
        {
            Print("OrderManager: Order sent successfully on attempt ", attempt);
            return result.order;
        }
        
        // Se non è un errore che vale la pena riprovare, esci
        if(!IsRetryableError(result.retcode))
        {
            SetError("Non-retryable error: " + IntegerToString(result.retcode) + " - " + result.comment);
            break;
        }
        
        // Attendi prima del prossimo tentativo
        if(attempt < m_maxRetries)
        {
            Print("OrderManager: Retrying in ", m_retryDelay, "ms...");
            Sleep(m_retryDelay);
        }
    }
    
    SetError("Order failed after " + IntegerToString(m_maxRetries) + " attempts. Last error: " + 
             IntegerToString(result.retcode) + " - " + result.comment);
    return 0;
}

//+------------------------------------------------------------------+
//| Ottiene ordini per magic number                                |
//+------------------------------------------------------------------+
int OrderManager::GetOrdersByMagic(long magic, ulong& tickets[])
{
    ArrayResize(tickets, 0);
    int count = 0;
    
    int totalOrders = OrdersTotal();
    for(int i = 0; i < totalOrders; i++)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == magic)
        {
            ArrayResize(tickets, count + 1);
            tickets[count] = ticket;
            count++;
        }
    }
    
    Print("OrderManager: Found ", count, " orders with magic ", magic);
    return count;
}

//+------------------------------------------------------------------+
//| Ottiene posizioni per magic number                             |
//+------------------------------------------------------------------+
int OrderManager::GetPositionsByMagic(long magic, ulong& tickets[])
{
    ArrayResize(tickets, 0);
    int count = 0;
    
    int totalPositions = PositionsTotal();
    for(int i = 0; i < totalPositions; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == magic)
        {
            ArrayResize(tickets, count + 1);
            tickets[count] = ticket;
            count++;
        }
    }
    
    Print("OrderManager: Found ", count, " positions with magic ", magic);
    return count;
}

//+------------------------------------------------------------------+
//| Elimina ordini per magic number                                |
//+------------------------------------------------------------------+
bool OrderManager::DeleteOrdersByMagic(long magic)
{
    ulong tickets[];
    int count = GetOrdersByMagic(magic, tickets);
    
    bool allSuccess = true;
    for(int i = 0; i < count; i++)
    {
        if(!DeleteOrder(tickets[i]))
        {
            allSuccess = false;
        }
    }
    
    Print("OrderManager: Deleted ", count, " orders with magic ", magic, ". Success: ", allSuccess);
    return allSuccess;
}

//+------------------------------------------------------------------+
//| Chiude posizioni per magic number                              |
//+------------------------------------------------------------------+
bool OrderManager::ClosePositionsByMagic(long magic)
{
    ulong tickets[];
    int count = GetPositionsByMagic(magic, tickets);
    
    bool allSuccess = true;
    for(int i = 0; i < count; i++)
    {
        if(!ClosePosition(tickets[i]))
        {
            allSuccess = false;
        }
    }
    
    Print("OrderManager: Closed ", count, " positions with magic ", magic, ". Success: ", allSuccess);
    return allSuccess;
}

//+------------------------------------------------------------------+
//| Elimina singolo ordine                                         |
//+------------------------------------------------------------------+
bool OrderManager::DeleteOrder(ulong ticket)
{
    if(!OrderSelect(ticket))
    {
        SetError("Order not found: " + IntegerToString(ticket));
        return false;
    }
    
    MqlTradeRequest request = {};
    request.action = TRADE_ACTION_REMOVE;
    request.order = ticket;
    
    MqlTradeResult result = {};
    bool success = OrderSend(request, result);
    
    LogTradeResult(result, "DELETE ORDER");
    
    if(success && result.retcode == TRADE_RETCODE_DONE)
    {
        Print("✅ Order deleted successfully: #", ticket);
        return true;
    }
    else
    {
        SetError("Failed to delete order #" + IntegerToString(ticket) + ": " + 
                IntegerToString(result.retcode) + " - " + result.comment);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Chiude posizione                                               |
//+------------------------------------------------------------------+
bool OrderManager::ClosePosition(ulong ticket)
{
    if(!PositionSelectByTicket(ticket))
    {
        SetError("Position not found: " + IntegerToString(ticket));
        return false;
    }
    
    string symbol = PositionGetString(POSITION_SYMBOL);
    double volume = PositionGetDouble(POSITION_VOLUME);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    MqlTradeRequest request = {};
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = volume;
    request.type = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.position = ticket;
    request.deviation = m_slippage;
    request.type_filling = ORDER_FILLING_FOK;
    
    return ClosePositionWithRetry(ticket, 0);
}

//+------------------------------------------------------------------+
//| Chiude posizione parziale                                      |
//+------------------------------------------------------------------+
bool OrderManager::ClosePartialPosition(ulong ticket, double volume)
{
    if(!PositionSelectByTicket(ticket))
    {
        SetError("Position not found: " + IntegerToString(ticket));
        return false;
    }
    
    double currentVolume = PositionGetDouble(POSITION_VOLUME);
    if(volume <= 0 || volume > currentVolume)
    {
        SetError("Invalid partial volume: " + DoubleToString(volume, 3));
        return false;
    }
    
    return ClosePositionWithRetry(ticket, volume);
}

//+------------------------------------------------------------------+
//| Chiude posizione con retry                                     |
//+------------------------------------------------------------------+
bool OrderManager::ClosePositionWithRetry(ulong ticket, double volume = 0)
{
    if(!PositionSelectByTicket(ticket))
    {
        SetError("Position not found: " + IntegerToString(ticket));
        return false;
    }
    
    string symbol = PositionGetString(POSITION_SYMBOL);
    double currentVolume = PositionGetDouble(POSITION_VOLUME);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    double closeVolume = (volume == 0) ? currentVolume : volume;
    
    MqlTradeRequest request = {};
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = closeVolume;
    request.type = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.position = ticket;
    request.deviation = m_slippage;
    request.type_filling = ORDER_FILLING_FOK;
    
    for(int attempt = 1; attempt <= m_maxRetries; attempt++)
    {
        MqlTradeResult result = {};
        bool success = OrderSend(request, result);
        
        LogTradeResult(result, "CLOSE POSITION");
        
        if(success && result.retcode == TRADE_RETCODE_DONE)
        {
            Print("✅ Position closed successfully: #", ticket, " Volume: ", DoubleToString(closeVolume, 3));
            return true;
        }
        
        if(!IsRetryableError(result.retcode))
        {
            SetError("Non-retryable error closing position: " + IntegerToString(result.retcode));
            break;
        }
        
        if(attempt < m_maxRetries)
        {
            Sleep(m_retryDelay);
        }
    }
    
    SetError("Failed to close position after " + IntegerToString(m_maxRetries) + " attempts");
    return false;
}

//+------------------------------------------------------------------+
//| Validazione request ordine                                     |
//+------------------------------------------------------------------+
bool OrderManager::ValidateOrderRequest(const MqlTradeRequest& request)
{
    if(!ValidateSymbol(request.symbol))
    {
        return false;
    }
    
    if(!ValidateVolume(request.symbol, request.volume))
    {
        return false;
    }
    
    if(!ValidatePrices(request.symbol, request.price, request.sl, request.tp))
    {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Valida simbolo                                                 |
//+------------------------------------------------------------------+
bool OrderManager::ValidateSymbol(const string symbol)
{
    if(symbol == "")
    {
        SetError("Empty symbol");
        return false;
    }
    
    if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
    {
        SetError("Symbol not available: " + symbol);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Valida volume                                                  |
//+------------------------------------------------------------------+
bool OrderManager::ValidateVolume(const string symbol, double volume)
{
    double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double stepVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    if(volume < minVolume)
    {
        SetError("Volume below minimum: " + DoubleToString(volume, 3) + " < " + DoubleToString(minVolume, 3));
        return false;
    }
    
    if(volume > maxVolume)
    {
        SetError("Volume above maximum: " + DoubleToString(volume, 3) + " > " + DoubleToString(maxVolume, 3));
        return false;
    }
    
    // Verifica step
    double remainder = MathMod(volume, stepVolume);
    if(remainder > 0.0001) // Tolleranza per errori floating point
    {
        SetError("Volume not aligned to step: " + DoubleToString(volume, 3) + 
                 " (step: " + DoubleToString(stepVolume, 3) + ")");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Valida prezzi                                                  |
//+------------------------------------------------------------------+
bool OrderManager::ValidatePrices(const string symbol, double price, double sl, double tp)
{
    if(price <= 0)
    {
        SetError("Invalid price: " + DoubleToString(price, _Digits));
        return false;
    }
    
    if(sl <= 0)
    {
        SetError("Invalid stop loss: " + DoubleToString(sl, _Digits));
        return false;
    }
    
    // TP può essere 0 (disabilitato)
    if(tp < 0)
    {
        SetError("Invalid take profit: " + DoubleToString(tp, _Digits));
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Log risultato trade                                            |
//+------------------------------------------------------------------+
void OrderManager::LogTradeResult(const MqlTradeResult& result, const string operation)
{
    Print("=== TRADE RESULT: ", operation, " ===");
    Print("Return Code: ", result.retcode, " (", result.comment, ")");
    Print("Order: #", result.order);
    Print("Deal: #", result.deal);
    if(result.volume > 0)
        Print("Volume: ", DoubleToString(result.volume, 3));
    if(result.price > 0)
        Print("Price: ", DoubleToString(result.price, _Digits));
}

//+------------------------------------------------------------------+
//| Verifica se errore è riprovabile                              |
//+------------------------------------------------------------------+
bool OrderManager::IsRetryableError(int errorCode)
{
    switch(errorCode)
    {
        case TRADE_RETCODE_REQUOTE:
        case TRADE_RETCODE_CONNECTION:
        case TRADE_RETCODE_PRICE_CHANGED:
        case TRADE_RETCODE_TIMEOUT:
        case TRADE_RETCODE_PRICE_OFF:
        case TRADE_RETCODE_SERVER_DISABLES_AT:
            return true;
        default:
            return false;
    }
}

//+------------------------------------------------------------------+
//| Sleep function                                                 |
//+------------------------------------------------------------------+
void OrderManager::Sleep(int milliseconds)
{
    datetime startTime = GetTickCount();
    while(GetTickCount() - startTime < milliseconds)
    {
        // Busy wait - in un EA reale potresti usare altri metodi
    }
}

//+------------------------------------------------------------------+
//| Ottiene string per trade action                               |
//+------------------------------------------------------------------+
string OrderManager::GetTradeActionString(ENUM_TRADE_REQUEST_ACTIONS action)
{
    switch(action)
    {
        case TRADE_ACTION_DEAL: return "DEAL";
        case TRADE_ACTION_PENDING: return "PENDING";
        case TRADE_ACTION_SLTP: return "MODIFY";
        case TRADE_ACTION_MODIFY: return "MODIFY";
        case TRADE_ACTION_REMOVE: return "REMOVE";
        default: return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Ottiene informazioni ordine                                    |
//+------------------------------------------------------------------+
bool OrderManager::GetOrderInfo(ulong ticket, OrderInfo& orderInfo)
{
    if(!OrderSelect(ticket))
    {
        SetError("Order not found: " + IntegerToString(ticket));
        return false;
    }
    
    orderInfo.ticket = ticket;
    orderInfo.symbol = OrderGetString(ORDER_SYMBOL);
    orderInfo.type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
    orderInfo.volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
    orderInfo.priceOpen = OrderGetDouble(ORDER_PRICE_OPEN);
    orderInfo.sl = OrderGetDouble(ORDER_SL);
    orderInfo.tp = OrderGetDouble(ORDER_TP);
    orderInfo.magic = OrderGetInteger(ORDER_MAGIC);
    orderInfo.timeSetup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
    orderInfo.comment = OrderGetString(ORDER_COMMENT);
    
    return true;
}

//+------------------------------------------------------------------+
//| Ottiene informazioni posizione                                 |
//+------------------------------------------------------------------+
bool OrderManager::GetPositionInfo(ulong ticket, PositionInfo& positionInfo)
{
    if(!PositionSelectByTicket(ticket))
    {
        SetError("Position not found: " + IntegerToString(ticket));
        return false;
    }
    
    positionInfo.ticket = ticket;
    positionInfo.symbol = PositionGetString(POSITION_SYMBOL);
    positionInfo.type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    positionInfo.volume = PositionGetDouble(POSITION_VOLUME);
    positionInfo.priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
    positionInfo.priceCurrent = PositionGetDouble(POSITION_PRICE_CURRENT);
    positionInfo.sl = PositionGetDouble(POSITION_SL);
    positionInfo.tp = PositionGetDouble(POSITION_TP);
    positionInfo.profit = PositionGetDouble(POSITION_PROFIT);
    positionInfo.magic = PositionGetInteger(POSITION_MAGIC);
    positionInfo.timeOpen = (datetime)PositionGetInteger(POSITION_TIME);
    positionInfo.comment = PositionGetString(POSITION_COMMENT);
    
    return true;
}

//+------------------------------------------------------------------+
//| Modifica ordine                                                |
//+------------------------------------------------------------------+
bool OrderManager::ModifyOrder(ulong ticket, double price, double sl, double tp)
{
    if(!OrderSelect(ticket))
    {
        SetError("Order not found: " + IntegerToString(ticket));
        return false;
    }
    
    MqlTradeRequest request = {};
    request.action = TRADE_ACTION_MODIFY;
    request.order = ticket;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    
    MqlTradeResult result = {};
    bool success = OrderSend(request, result);
    
    LogTradeResult(result, "MODIFY ORDER");
    
    if(success && result.retcode == TRADE_RETCODE_DONE)
    {
        Print("✅ Order modified successfully: #", ticket);
        return true;
    }
    else
    {
        SetError("Failed to modify order #" + IntegerToString(ticket) + ": " + 
                IntegerToString(result.retcode) + " - " + result.comment);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Set error                                                       |
//+------------------------------------------------------------------+
void OrderManager::SetError(const string error)
{
    m_lastError = error;
    Print("OrderManager ERROR: ", error);
}

#endif // ORDER_MANAGER_MQH