//+------------------------------------------------------------------+
//|                                             ChartVisualizer.mqh |
//|                                    Disegno Righe Verticali     |
//|                                              Single Responsibility |
//+------------------------------------------------------------------+

#ifndef CHART_VISUALIZER_MQH
#define CHART_VISUALIZER_MQH

#include "Enums.mqh"
#include "TimeManager.mqh"

//+------------------------------------------------------------------+
//| ChartVisualizer Class                                           |
//+------------------------------------------------------------------+
class ChartVisualizer
{
private:
    string m_objectPrefix;          // Prefisso per oggetti grafici
    color  m_lineColor;             // Colore linee verticali
    int    m_lineWidth;             // Spessore linee
    ENUM_LINE_STYLE m_lineStyle;   // Stile linee
    datetime m_lastCleanupDate;     // Ultima data cleanup
    
    // Array per tracking oggetti creati
    string m_createdObjects[];
    int    m_objectCount;
    
    // TimeManager per calcoli temporali
    TimeManager* m_timeManager;

public:
    ChartVisualizer();
    ~ChartVisualizer();
    
    // Main interface
    bool Initialize(color lineColor = clrRed, int lineWidth = 1, ENUM_LINE_STYLE lineStyle = STYLE_SOLID);
    bool DrawReferenceCandle(datetime candleTime, string sessionName = "");
    bool DrawSessionReferences(int session1Hour, int session1Min, int session2Hour, int session2Min, bool isSummerTime);
    bool CleanupPreviousDayLines();
    bool CleanupAllLines();
    
    // Configuration
    void SetLineColor(color newColor) { m_lineColor = newColor; }
    void SetLineWidth(int newWidth) { m_lineWidth = newWidth; }
    void SetLineStyle(ENUM_LINE_STYLE newStyle) { m_lineStyle = newStyle; }
    
    // Info
    int GetObjectCount() const { return m_objectCount; }
    datetime GetLastCleanupDate() const { return m_lastCleanupDate; }

private:
    string GenerateObjectName(datetime candleTime, string sessionName);
    bool CreateVerticalLine(string objectName, datetime time);
    bool CreateTimeLabel(string labelName, datetime time);
    bool DeleteObject(string objectName);
    bool ShouldCleanupObject(string objectName, datetime currentDate);
    void AddToObjectList(string objectName);
    void RemoveFromObjectList(string objectName);
    datetime GetDateOnly(datetime fullDateTime);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
ChartVisualizer::ChartVisualizer() : m_objectPrefix("BreakoutEA_RefLine_"),
                                    m_lineColor(clrRed),
                                    m_lineWidth(1),
                                    m_lineStyle(STYLE_SOLID),
                                    m_lastCleanupDate(0),
                                    m_objectCount(0),
                                    m_timeManager(NULL)
{
    ArrayResize(m_createdObjects, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
ChartVisualizer::~ChartVisualizer()
{
    CleanupAllLines();
    
    // Cleanup TimeManager
    if(m_timeManager != NULL)
    {
        delete m_timeManager;
        m_timeManager = NULL;
    }
}

//+------------------------------------------------------------------+
//| Inizializza il visualizzatore                                   |
//+------------------------------------------------------------------+
bool ChartVisualizer::Initialize(color lineColor = clrRed, int lineWidth = 1, ENUM_LINE_STYLE lineStyle = STYLE_SOLID)
{
    Print("ChartVisualizer: Initializing...");
    
    m_lineColor = lineColor;
    m_lineWidth = lineWidth;
    m_lineStyle = lineStyle;
    m_lastCleanupDate = GetDateOnly(TimeCurrent());
    
    // Inizializza TimeManager interno
    m_timeManager = new TimeManager();
    if(m_timeManager == NULL)
    {
        Print("ChartVisualizer ERROR: Failed to create TimeManager");
        return false;
    }
    
    // Cleanup eventuali linee precedenti
    CleanupAllLines();
    
    Print("ChartVisualizer: Initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Disegna righe di riferimento per entrambe le sessioni          |
//+------------------------------------------------------------------+
bool ChartVisualizer::DrawSessionReferences(int session1Hour, int session1Min, int session2Hour, int session2Min, bool isSummerTime)
{
    if(m_timeManager == NULL)
    {
        Print("ChartVisualizer ERROR: TimeManager not initialized");
        return false;
    }
    
    Print("ChartVisualizer: Drawing session references...");
    Print("DST Status: ", isSummerTime ? "SUMMER (+1h)" : "WINTER (base)");
    
    bool success = true;
    
    // Crea e disegna Session 1
    datetime session1Time = m_timeManager.CreateBrokerSessionTime(session1Hour, session1Min, isSummerTime);
    if(session1Time > 0)
    {
        if(DrawReferenceCandle(session1Time, "Session1"))
        {
            Print("✅ Session1 line: ", TimeToString(session1Time, TIME_DATE | TIME_MINUTES), " broker time");
            m_timeManager.LogSessionTime("SESSION 1", session1Hour, session1Min, isSummerTime);
        }
        else
        {
            Print("❌ Failed to draw Session1 line");
            success = false;
        }
    }
    else
    {
        Print("❌ Invalid Session1 time calculated");
        success = false;
    }
    
    // Crea e disegna Session 2
    datetime session2Time = m_timeManager.CreateBrokerSessionTime(session2Hour, session2Min, isSummerTime);
    if(session2Time > 0)
    {
        if(DrawReferenceCandle(session2Time, "Session2"))
        {
            Print("✅ Session2 line: ", TimeToString(session2Time, TIME_DATE | TIME_MINUTES), " broker time");
            m_timeManager.LogSessionTime("SESSION 2", session2Hour, session2Min, isSummerTime);
        }
        else
        {
            Print("❌ Failed to draw Session2 line");
            success = false;
        }
    }
    else
    {
        Print("❌ Invalid Session2 time calculated");
        success = false;
    }
    
    if(success)
    {
        Print("ChartVisualizer: All session references drawn successfully");
    }
    else
    {
        Print("ChartVisualizer: Some session references failed to draw");
    }
    
    return success;
}

//+------------------------------------------------------------------+
//| Disegna riga verticale su candela di riferimento               |
//+------------------------------------------------------------------+
bool ChartVisualizer::DrawReferenceCandle(datetime candleTime, string sessionName = "")
{
    // Genera nome univoco per l'oggetto
    string objectName = GenerateObjectName(candleTime, sessionName);
    
    // Crea la linea verticale
    if(!CreateVerticalLine(objectName, candleTime))
    {
        Print("ChartVisualizer ERROR: Failed to create vertical line for ", TimeToString(candleTime));
        return false;
    }
    
    // Aggiungi alla lista oggetti tracciati
    AddToObjectList(objectName);
    
    Print("ChartVisualizer: Reference line created at ", TimeToString(candleTime), 
          sessionName != "" ? " (Session: " + sessionName + ")" : "");
    
    return true;
}

//+------------------------------------------------------------------+
//| Pulisce linee del giorno precedente                            |
//+------------------------------------------------------------------+
bool ChartVisualizer::CleanupPreviousDayLines()
{
    datetime currentDate = GetDateOnly(TimeCurrent());
    
    // Se è ancora lo stesso giorno, non fare cleanup
    if(currentDate == m_lastCleanupDate)
        return true;
    
    Print("ChartVisualizer: Cleaning up previous day lines...");
    
    int cleaned = 0;
    
    // Scansiona tutti gli oggetti tracciati
    for(int i = m_objectCount - 1; i >= 0; i--)
    {
        if(ShouldCleanupObject(m_createdObjects[i], currentDate))
        {
            if(DeleteObject(m_createdObjects[i]))
            {
                RemoveFromObjectList(m_createdObjects[i]);
                cleaned++;
            }
        }
    }
    
    m_lastCleanupDate = currentDate;
    
    Print("ChartVisualizer: Cleaned up ", cleaned, " previous day lines");
    return true;
}

//+------------------------------------------------------------------+
//| Pulisce tutte le linee                                         |
//+------------------------------------------------------------------+
bool ChartVisualizer::CleanupAllLines()
{
    Print("ChartVisualizer: Cleaning up all lines...");
    
    int cleaned = 0;
    
    // Elimina tutti gli oggetti tracciati
    for(int i = 0; i < m_objectCount; i++)
    {
        if(DeleteObject(m_createdObjects[i]))
            cleaned++;
    }
    
    // Reset array
    ArrayResize(m_createdObjects, 0);
    m_objectCount = 0;
    
    Print("ChartVisualizer: Cleaned up ", cleaned, " lines");
    return true;
}

//+------------------------------------------------------------------+
//| Genera nome univoco per l'oggetto grafico                      |
//+------------------------------------------------------------------+
string ChartVisualizer::GenerateObjectName(datetime candleTime, string sessionName)
{
    string name = m_objectPrefix;
    name += TimeToString(candleTime, TIME_DATE | TIME_MINUTES);
    name = StringReplace(name, ":", "");
    name = StringReplace(name, " ", "_");
    name = StringReplace(name, ".", "");
    
    if(sessionName != "")
        name += "_" + sessionName;
    
    return name;
}

//+------------------------------------------------------------------+
//| Crea linea verticale sul grafico con testo orario              |
//+------------------------------------------------------------------+
bool ChartVisualizer::CreateVerticalLine(string objectName, datetime time)
{
    // Elimina oggetto se già esiste
    if(ObjectFind(0, objectName) >= 0)
        ObjectDelete(0, objectName);
    
    // Crea nuova linea verticale
    if(!ObjectCreate(0, objectName, OBJ_VLINE, 0, time, 0))
    {
        Print("ChartVisualizer ERROR: Failed to create vertical line object: ", objectName);
        return false;
    }
    
    // Imposta proprietà linea
    ObjectSetInteger(0, objectName, OBJPROP_COLOR, m_lineColor);
    ObjectSetInteger(0, objectName, OBJPROP_WIDTH, m_lineWidth);
    ObjectSetInteger(0, objectName, OBJPROP_STYLE, m_lineStyle);
    ObjectSetInteger(0, objectName, OBJPROP_BACK, true);  // Dietro il grafico
    ObjectSetInteger(0, objectName, OBJPROP_SELECTABLE, false);  // Non selezionabile
    ObjectSetInteger(0, objectName, OBJPROP_HIDDEN, true);  // Nascosto nella lista oggetti
    
    // Imposta descrizione
    string description = "Reference Candle: " + TimeToString(time, TIME_DATE | TIME_MINUTES);
    ObjectSetString(0, objectName, OBJPROP_TEXT, description);
    
    // Crea testo con orario in basso alla linea
    string textObjectName = objectName + "_Text";
    if(CreateTimeLabel(textObjectName, time))
    {
        Print("ChartVisualizer: Time label created for ", TimeToString(time, TIME_MINUTES));
    }
    
    // Refresh chart
    ChartRedraw(0);
    
    return true;
}

//+------------------------------------------------------------------+
//| Crea etichetta temporale per la linea verticale                |
//+------------------------------------------------------------------+
bool ChartVisualizer::CreateTimeLabel(string labelName, datetime time)
{
    // Elimina etichetta se già esiste
    if(ObjectFind(0, labelName) >= 0)
        ObjectDelete(0, labelName);
    
    // Ottieni range prezzo del grafico per posizionamento
    double chartHigh = ChartGetDouble(0, CHART_PRICE_MAX);
    double chartLow = ChartGetDouble(0, CHART_PRICE_MIN);
    double priceRange = chartHigh - chartLow;
    
    // Posiziona testo nel 10% inferiore del grafico
    double labelPrice = chartLow + (priceRange * 0.10);
    
    // Crea oggetto testo
    if(!ObjectCreate(0, labelName, OBJ_TEXT, 0, time, labelPrice))
    {
        Print("ChartVisualizer ERROR: Failed to create time label: ", labelName);
        return false;
    }
    
    // Imposta proprietà del testo
    string timeText = TimeToString(time, TIME_MINUTES);  // Solo HH:MM
    ObjectSetString(0, labelName, OBJPROP_TEXT, timeText);
    ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, m_lineColor);
    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_UPPER);
    ObjectSetInteger(0, labelName, OBJPROP_BACK, false);  // Sopra il grafico
    ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
    
    return true;
}

//+------------------------------------------------------------------+
//| Elimina oggetto grafico                                        |
//+------------------------------------------------------------------+
bool ChartVisualizer::DeleteObject(string objectName)
{
    bool success = true;
    
    // Elimina linea principale
    if(ObjectFind(0, objectName) >= 0)
    {
        if(!ObjectDelete(0, objectName))
        {
            Print("ChartVisualizer WARNING: Failed to delete object: ", objectName);
            success = false;
        }
    }
    
    // Elimina etichetta associata
    string textObjectName = objectName + "_Text";
    if(ObjectFind(0, textObjectName) >= 0)
    {
        if(!ObjectDelete(0, textObjectName))
        {
            Print("ChartVisualizer WARNING: Failed to delete text label: ", textObjectName);
            success = false;
        }
    }
    
    if(success)
    {
        ChartRedraw(0);
    }
    
    return success;
}

//+------------------------------------------------------------------+
//| Determina se oggetto deve essere eliminato                     |
//+------------------------------------------------------------------+
bool ChartVisualizer::ShouldCleanupObject(string objectName, datetime currentDate)
{
    // Estrai data dall'oggetto (dal nome)
    // Il nome contiene la data/ora, quindi possiamo fare un parsing semplice
    
    // Per ora, criterio semplice: se l'oggetto esiste da più di 1 giorno
    datetime objectTime = 0;
    
    // Prova a ottenere il tempo dall'oggetto se esiste ancora
    if(ObjectFind(0, objectName) >= 0)
    {
        objectTime = (datetime)ObjectGetInteger(0, objectName, OBJPROP_TIME);
        datetime objectDate = GetDateOnly(objectTime);
        
        // Elimina se è di un giorno precedente
        return (objectDate < currentDate);
    }
    
    return true;  // Se non esiste più, rimuovi dalla lista
}

//+------------------------------------------------------------------+
//| Aggiunge oggetto alla lista tracciata                          |
//+------------------------------------------------------------------+
void ChartVisualizer::AddToObjectList(string objectName)
{
    // Ridimensiona array se necessario
    ArrayResize(m_createdObjects, m_objectCount + 1);
    
    // Aggiungi nuovo oggetto
    m_createdObjects[m_objectCount] = objectName;
    m_objectCount++;
}

//+------------------------------------------------------------------+
//| Rimuove oggetto dalla lista tracciata                          |
//+------------------------------------------------------------------+
void ChartVisualizer::RemoveFromObjectList(string objectName)
{
    // Trova oggetto nella lista
    for(int i = 0; i < m_objectCount; i++)
    {
        if(m_createdObjects[i] == objectName)
        {
            // Sposta elementi successivi
            for(int j = i; j < m_objectCount - 1; j++)
            {
                m_createdObjects[j] = m_createdObjects[j + 1];
            }
            
            m_objectCount--;
            ArrayResize(m_createdObjects, m_objectCount);
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Ottiene solo la data (senza orario)                            |
//+------------------------------------------------------------------+
datetime ChartVisualizer::GetDateOnly(datetime fullDateTime)
{
    MqlDateTime dt;
    TimeToStruct(fullDateTime, dt);
    dt.hour = 0;
    dt.min = 0;
    dt.sec = 0;
    return StructToTime(dt);
}

#endif // CHART_VISUALIZER_MQH