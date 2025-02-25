//+------------------------------------------------------------------+
//|                                         Heiken_Ashi_Ameliore.mq5 |
//|Ind. Heiken Ashi avec tampons suppl.    : corps, mèches, tendance |
//+------------------------------------------------------------------+
#property copyright "2024, Lucas Troncy - David Lhoyer"

//--- indicator settings
#property indicator_chart_window
#property indicator_buffers 9
#property indicator_plots   5

//--- ====================== PLOT 1 ======================
//--- Bougies colorées Heiken Ashi (draw_color_candles)
#property indicator_label1  "Heiken Ashi Am Open;Heiken Ashi Am High;Heiken Ashi Am Low;Heiken Ashi Am Close"

#property indicator_type1   DRAW_COLOR_CANDLES
//  Deux couleurs : bleu pour haussier, rouge pour baissier
#property indicator_color1  DodgerBlue, Red

//--- ====================== PLOT 2 ======================
//--- Buffer "Bullish" (DRAW_NONE => pas de tracé, mais data visible)
#property indicator_label2  "Heiken Ashi Bullish"
#property indicator_type2   DRAW_NONE

//--- ====================== PLOT 3 ======================
#property indicator_label3  "Heiken Ashi Body"
#property indicator_type3   DRAW_NONE

//--- ====================== PLOT 4 ======================
#property indicator_label4  "Heiken Ashi Upper Wick"
#property indicator_type4   DRAW_NONE

//--- ====================== PLOT 5 ======================
#property indicator_label5  "Heiken Ashi Lower Wick"
#property indicator_type5   DRAW_NONE

//--- indicator buffers
double ExtOBuffer[];       // Heiken Ashi Open
double ExtHBuffer[];       // Heiken Ashi High
double ExtLBuffer[];       // Heiken Ashi Low
double ExtCBuffer[];       // Heiken Ashi Close
double ExtColorBuffer[];   // Heiken Ashi Candle Color (Blue/Red)
double ExtBullishBuffer[]; // Haussier (booléen)
double ExtBodyBuffer[];    // Corps
double ExtUpperWick[];     // MecheSup
double ExtLowerWick[];     // MecheInf

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
   //--- indicator buffers mapping
   SetIndexBuffer(0, ExtOBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtHBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, ExtLBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, ExtCBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, ExtColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(5, ExtBullishBuffer, INDICATOR_DATA);
   SetIndexBuffer(6, ExtBodyBuffer, INDICATOR_DATA);
   SetIndexBuffer(7, ExtUpperWick, INDICATOR_DATA);
   SetIndexBuffer(8, ExtLowerWick, INDICATOR_DATA);

   //--- Optionnel: préciser qu'on ne veut pas de tracé pour les plots 1..4
   //    (On l'a déjà fait via #property indicator_typeX = DRAW_NONE.)
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_NONE);

   //--- Digits, nom de l'indicateur, etc.
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   IndicatorSetString(INDICATOR_SHORTNAME, "Heiken Ashi Amélioré");
   //--- Valeur vide pour le plot 0 (c'est important pour éviter les tracés parasites)
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
  }

//+------------------------------------------------------------------+
//| Heiken Ashi Amélioré                                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &Time[],
                const double &Open[], const double &High[], const double &Low[],
                const double &Close[], const long &TickVolume[],
                const long &Volume[], const int &Spread[])
  {
   int i, limit;

   //--- preliminary calculations
   if (prev_calculated == 0)
     {
      //--- set first candle
      ExtLBuffer[0] = Low[0];
      ExtHBuffer[0] = High[0];
      ExtOBuffer[0] = Open[0];
      ExtCBuffer[0] = Close[0];
      limit = 1;
     }
   else limit = prev_calculated - 1;

   //--- the main loop of calculations
   for (i = limit; i < rates_total && !IsStopped(); i++)
     {
      //--- Calculate Heiken Ashi values
      double haOpen = (ExtOBuffer[i - 1] + ExtCBuffer[i - 1]) / 2;
      double haClose = (Open[i] + High[i] + Low[i] + Close[i]) / 4;
      double haHigh = MathMax(High[i], MathMax(haOpen, haClose));
      double haLow = MathMin(Low[i], MathMin(haOpen, haClose));

      ExtLBuffer[i] = haLow;
      ExtHBuffer[i] = haHigh;
      ExtOBuffer[i] = haOpen;
      ExtCBuffer[i] = haClose;

      //--- Determine candle color and bullish status
      bool isBullish = (haOpen < haClose);
      ExtColorBuffer[i] = isBullish ? 0.0 : 1.0; // DodgerBlue for bullish, Red for bearish
      ExtBullishBuffer[i] = isBullish ? 1.0 : 0.0;

      //--- Calculate additional properties
      ExtBodyBuffer[i] = isBullish ? (haClose - haOpen) : (haOpen - haClose);
      ExtUpperWick[i] = isBullish ? (haHigh - haClose) : (haHigh - haOpen);
      ExtLowerWick[i] = isBullish ? (haOpen - haLow) : (haClose - haLow);
     }

   //--- done
   return (rates_total);
  }
//+------------------------------------------------------------------+
