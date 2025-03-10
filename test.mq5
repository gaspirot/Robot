//+------------------------------------------------------------------+
//|                                                       PercentDiff.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0  // Ajusté à 0 car aucun buffer n'est utilisé

// Énumérations
enum UNIT {
    UNIT_MINUTES,
    UNIT_HOURS,
    UNIT_DAYS,
    UNIT_WEEKS,
    UNIT_MONTHS,
    UNIT_YEARS
};

enum CALC_METHOD {
    METHOD_HIGH,
    METHOD_OPEN,
    METHOD_CLOSE,
    METHOD_MEDIAN
};

enum DIFF_TYPE {
    DIFF_HIGH_LOW,
    DIFF_CLOSE_OPEN
};

// Paramètres d’entrée
input ENUM_TIMEFRAMES timeframe_bougies = PERIOD_D1;
input ENUM_TIMEFRAMES timeframe_tendance = PERIOD_H1;
input CALC_METHOD calc_method = METHOD_HIGH;
input DIFF_TYPE diff_type = DIFF_HIGH_LOW;
input bool show_trend = true;

input color header_color = clrBlue;
input color period_color = clrBlack;
input color color_positive = clrGreen;
input color color_negative = clrRed;
input color trend_up_color = clrGreen;
input color trend_down_color = clrRed;
input color trend_neutral_color = clrGray;
input color table_background = clrWhite;

input int table_x_init = 50;
input int table_y_init = 50;

input UNIT unit_period_1 = UNIT_MINUTES;
input int number_period_1 = 60;
input UNIT unit_period_2 = UNIT_HOURS;
input int number_period_2 = 24;
input UNIT unit_period_3 = UNIT_DAYS;
input int number_period_3 = 7;
input UNIT unit_period_4 = UNIT_YEARS;
input int number_period_4 = 1;

// Variables globales
int table_x, table_y;
bool dragging = false;

// Calcul de la date de début
datetime CalculateStartDate(UNIT unit, int number) {
    if (number <= 0) return 0;
    datetime now = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(now, dt);
   
    switch(unit) {
        case UNIT_YEARS:
            dt.year -= number;
            break;
        case UNIT_MONTHS:
            {
                int totalMonths = dt.mon - number;
                while (totalMonths < 1) {
                    dt.year--;
                    totalMonths += 12;
                }
                dt.mon = totalMonths;
            }
            break;
        case UNIT_DAYS:
            return now - number * 86400;
        case UNIT_HOURS:
            return now - number * 3600;
        case UNIT_MINUTES:
            return now - number * 60;
        case UNIT_WEEKS:
            return now - number * 7 * 86400;
        default:
            return 0;
    }
    int maxDay = (dt.mon == 2) ? 28 : 30;
    if (dt.day > maxDay) dt.day = maxDay;
    return StructToTime(dt);
}

// Calcul du pourcentage moyen
double CalculateAveragePercentage(ENUM_TIMEFRAMES tf, datetime start, datetime end) {
    MqlRates rates[];
    int copied = CopyRates(Symbol(), tf, start, end, rates);
    if (copied <= 0) {
        Print("Erreur : Données insuffisantes pour ", Symbol(), " sur ", EnumToString(tf));
        return 0.0;
    }
   
    double sum = 0.0, base_price = 0.0; // Initialisation par défaut pour éviter l'avertissement
    int count = 0;
    for (int i = 0; i < copied; i++) {
        double diff = (diff_type == DIFF_HIGH_LOW) ? (rates[i].high - rates[i].low) : (rates[i].close - rates[i].open);
        switch(calc_method) {
            case METHOD_HIGH: base_price = rates[i].high; break;
            case METHOD_OPEN: base_price = rates[i].open; break;
            case METHOD_CLOSE: base_price = rates[i].close; break;
            case METHOD_MEDIAN: base_price = (rates[i].high + rates[i].low) / 2; break;
        }
        if (base_price > 0) {
            sum += (diff / base_price) * 100;
            count++;
        }
    }
    return (count > 0) ? sum / count : 0.0;
}

// Détection de la tendance
string GetTrend(ENUM_TIMEFRAMES tf) {
    MqlRates rates[];
    int copied = CopyRates(Symbol(), tf, 1, 1, rates);
    if (copied == 1) {
        if (rates[0].close > rates[0].open) return "Hausse";
        else if (rates[0].close < rates[0].open) return "Baisse";
        else return "Neutre";
    }
    return "Inconnu";
}

// Afficher l'année
void DisplayYearOnChart() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    string yearText = "Année : " + IntegerToString(dt.year);
   
    ObjectCreate(0, "PercentDiff_Year", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "PercentDiff_Year", OBJPROP_XDISTANCE, 50);
    ObjectSetInteger(0, "PercentDiff_Year", OBJPROP_YDISTANCE, 20);
    ObjectSetString(0, "PercentDiff_Year", OBJPROP_TEXT, yearText);
    ObjectSetInteger(0, "PercentDiff_Year", OBJPROP_COLOR, clrGray);
}

// Ajout d'une période
void AddPeriod(string name, UNIT unit, int number, int &x, int &y, int line_height) {
    datetime start = CalculateStartDate(unit, number);
    if (start == 0) {
        Print("Erreur : Date de début invalide pour ", number, " ",
              unit == UNIT_YEARS ? "ans" : unit == UNIT_MONTHS ? "mois" :
              unit == UNIT_DAYS ? "jours" : unit == UNIT_HOURS ? "heures" :
              unit == UNIT_MINUTES ? "minutes" : "semaines");
        return;
    }
   
    double avg = CalculateAveragePercentage(timeframe_bougies, start, TimeCurrent());
   
    string period_text = StringFormat("%d %s", number,
        unit == UNIT_YEARS ? "ans" : unit == UNIT_MONTHS ? "mois" :
        unit == UNIT_DAYS ? "jours" : unit == UNIT_HOURS ? "heures" :
        unit == UNIT_MINUTES ? "minutes" : "semaines");
   
    ObjectCreate(0, "PercentDiff_Period" + name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "PercentDiff_Period" + name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, "PercentDiff_Period" + name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, "PercentDiff_Period" + name, OBJPROP_TEXT, period_text);
    ObjectSetInteger(0, "PercentDiff_Period" + name, OBJPROP_COLOR, period_color);
   
    ObjectCreate(0, "PercentDiff_Value" + name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "PercentDiff_Value" + name, OBJPROP_XDISTANCE, x + 100);
    ObjectSetInteger(0, "PercentDiff_Value" + name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, "PercentDiff_Value" + name, OBJPROP_TEXT, StringFormat("%.2f%%", avg));
    ObjectSetInteger(0, "PercentDiff_Value" + name, OBJPROP_COLOR, avg >= 0 ? color_positive : color_negative);
   
    y += line_height;
}

// Création du tableau
void CreateTable() {
    ObjectsDeleteAll(0, "PercentDiff_");
    int x = table_x, y = table_y, line_height = 20;
   
    // Fond interactif
    ObjectCreate(0, "PercentDiff_Background", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "PercentDiff_Background", OBJPROP_XDISTANCE, x - 10);
    ObjectSetInteger(0, "PercentDiff_Background", OBJPROP_YDISTANCE, y - 10);
    ObjectSetInteger(0, "PercentDiff_Background", OBJPROP_XSIZE, 220);
    ObjectSetInteger(0, "PercentDiff_Background", OBJPROP_YSIZE, (5 + (show_trend ? 1 : 0)) * line_height + 10);
    ObjectSetInteger(0, "PercentDiff_Background", OBJPROP_BGCOLOR, table_background);
    ObjectSetInteger(0, "PercentDiff_Background", OBJPROP_COLOR, table_background);
    ObjectSetInteger(0, "PercentDiff_Background", OBJPROP_BACK, false);
    ObjectSetInteger(0, "PercentDiff_Background", OBJPROP_SELECTABLE, true);

    // En-tête
    ObjectCreate(0, "PercentDiff_Header1", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "PercentDiff_Header1", OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, "PercentDiff_Header1", OBJPROP_YDISTANCE, y);
    ObjectSetString(0, "PercentDiff_Header1", OBJPROP_TEXT, "Période");
    ObjectSetInteger(0, "PercentDiff_Header1", OBJPROP_COLOR, header_color);
   
    ObjectCreate(0, "PercentDiff_Header2", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "PercentDiff_Header2", OBJPROP_XDISTANCE, x + 100);
    ObjectSetInteger(0, "PercentDiff_Header2", OBJPROP_YDISTANCE, y);
    ObjectSetString(0, "PercentDiff_Header2", OBJPROP_TEXT, "Pourcentage");
    ObjectSetInteger(0, "PercentDiff_Header2", OBJPROP_COLOR, header_color);
   
    y += line_height;
   
    // Périodes
    AddPeriod("1", unit_period_1, number_period_1, x, y, line_height);
    AddPeriod("2", unit_period_2, number_period_2, x, y, line_height);
    AddPeriod("3", unit_period_3, number_period_3, x, y, line_height);
    AddPeriod("4", unit_period_4, number_period_4, x, y, line_height);
   
    // Tendance
    if (show_trend) {
        string trend = GetTrend(timeframe_tendance);
        color trend_color = (trend == "Hausse") ? trend_up_color :
                           (trend == "Baisse") ? trend_down_color : trend_neutral_color;
        ObjectCreate(0, "PercentDiff_Trend", OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, "PercentDiff_Trend", OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, "PercentDiff_Trend", OBJPROP_YDISTANCE, y);
        ObjectSetString(0, "PercentDiff_Trend", OBJPROP_TEXT, "Tendance (" + EnumToString(timeframe_tendance) + ") : " + trend);
        ObjectSetInteger(0, "PercentDiff_Trend", OBJPROP_COLOR, trend_color);
    }
}

// Gestion des événements
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    if (id == CHARTEVENT_OBJECT_CLICK && sparam == "PercentDiff_Background") {
        dragging = true;  // Activer le déplacement si clic sur le fond
    } else if (id == CHARTEVENT_MOUSE_MOVE && dragging) {
        table_x = (int)lparam;
        table_y = (int)dparam;
        CreateTable();  // Mettre à jour la position
    } else if (id == CHARTEVENT_MOUSE_MOVE && sparam == "0" && dragging) {
        dragging = false;  // Désactiver le déplacement quand le bouton est relâché
    }
}

// Initialisation
int OnInit() {
    table_x = table_x_init;
    table_y = table_y_init;
    CreateTable();
    DisplayYearOnChart();
    return INIT_SUCCEEDED;
}

// Calcul
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[],
                const double &close[], const long &tick_volume[], const long &volume[],
                const int &spread[]) {
    return rates_total;
}

// Désinitialisation
void OnDeinit(const int reason) {
    ObjectsDeleteAll(0, "PercentDiff_");
}
