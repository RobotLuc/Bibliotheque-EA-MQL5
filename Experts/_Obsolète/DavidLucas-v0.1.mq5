//+------------------------------------------------------------------+
//|                                              DavidLucas-v0.0.mq5 |
//|                      Copyright 2024, David Lhoyer - Lucas Troncy |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Lucas Troncy - David Lhoyer"
#property version   "1.00"

//--- Appel aux fonctions exterieures
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

//--- Initialisation des signaux
#define SIGNAL_BUY    1             // Buy signal
#define SIGNAL_NOT    0             // no trading signal
#define SIGNAL_SELL  -1             // Sell signal

#define CLOSE_LONG    2             // signal to close Long
#define CLOSE_SHORT  -2             // signal to close Short

//--- Paramètres d'heures de marché et de marché
input int InpHeureDebut=8;                 // Ici, il faut mettre l'heure de début de trading en GMT
input int InpHeureFin=16;                  // Ici, on met l'heure de fin de trading en GMT
//input string SymboleATrader = "USDEUR"   // Ici on pourra mettre le symbole à trader

//--- Input parameters RSI
input int  InpPeriodRSI     =14;                      // Prise de moyenne du RSI
input ENUM_APPLIED_PRICE InpPriceRSI=PRICE_WEIGHTED;  // RSI est appliqué sur valeur pondérée
input ENUM_TIMEFRAMES InpUT_RSI = PERIOD_M15;         // Période du RSI, avec fixation sur UT15 par défaut

//--- Input parameters DMI
input int  InpPeriodDMI     =14;                      // Prise de moyenne du DMI
input ENUM_TIMEFRAMES InpUT_DMI = PERIOD_M2;          // Période du DMI, avec fixation sur UT2 par défaut

//--- Input parameters Heiken Ashi
input ENUM_TIMEFRAMES InpUT_HA_Long = PERIOD_H4;   // Période Heiken Ashi la plus longue
input ENUM_TIMEFRAMES InpUT_HA_Moyen = PERIOD_M15; // Période Heiken Ashi Intermédiaire
input ENUM_TIMEFRAMES InpUT_HA_Court = PERIOD_M2;  // Période Heiken Ashi la plus courte

input double   InpTaille_HAlong = 0.1; // Taille du corps de bougie sur UT long
input double   InpTaille_HAmoyen = 0.1; // Taille du corps de bougie sur UT moyen
input double   InpTaille_HAcourt = 0.1;  // Taille du corps de bougie sur UT court

//--- Paramètres de trade
input uint InpSL      =100;         // Stop Loss en points
input uint InpTP      =100;         // Take Profit en points
input uint InpSlippage=10;          // slippage en points

//--- money management parameters
input double InpLot   =0.1;         // Taille de lot

//--- Expert ID
input long InpMagicNumber=100100;   // Magic Number, fixé à 100100 arbitrairement
//--- Paramètres
//input int  InpAverBodyPeriod=12;    // period for calculating average candlestick size
//int    ExtAvgBodyPeriod;            // average candlestick calculation period

//---  Initialisation des pointeurs d'indicateurs
int    ExtIndicatorHandleRSI=INVALID_HANDLE;  // Pointeur indicateur RSI
int    ExtIndicatorHandleDMI=INVALID_HANDLE;  // Pointeur indicateur DMI
int    ExtHandHeikenAshiUTL=INVALID_HANDLE;  // Pointeur indicateur H_A UT Long
int    ExtHandHeikenAshiUTC=INVALID_HANDLE;  // Pointeur indicateur H_A UT court
int    ExtHandHeikenAshiUTM=INVALID_HANDLE;  // Pointeur indicateur H_A UT moyen

//--- Objets. ExtTrade permettra de passer les ordres d'achat et de vente
CTrade      ExtTrade;
CSymbolInfo ExtSymbolInfo;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {

//--- Définition des paramètres pour l'objet de classe CTrade appelé
   ExtTrade.SetDeviationInPoints(InpSlippage);    // slippage
   ExtTrade.SetExpertMagicNumber(InpMagicNumber); // Expert Advisor ID
   ExtTrade.LogLevel(LOG_LEVEL_ERRORS);           // logging level
// ExtAvgBodyPeriod=InpAverBodyPeriod;            // Taille de la bougie

//+------------------------------------------------------------------+
//| Initialisation des Indicateurs, DMI, RSI et Heiken Ahis          |
//+------------------------------------------------------------------+
   ExtIndicatorHandleRSI=iRSI(_Symbol, InpUT_RSI, InpPeriodRSI, InpPriceRSI);
   ExtIndicatorHandleDMI=iADX(_Symbol, InpUT_DMI, InpPeriodDMI);
   ExtHandHeikenAshiUTL=iCustom(_Symbol,InpUT_HA_Long,"\\Indicators\\Examples\\Heiken_Ashi");
   ExtHandHeikenAshiUTM=iCustom(_Symbol,InpUT_HA_Moyen,"\\Indicators\\Examples\\Heiken_Ashi");
   ExtHandHeikenAshiUTC=iCustom(_Symbol,InpUT_HA_Court,"\\Indicators\\Examples\\Heiken_Ashi");
   
// Perform all initialization checks in one conditional block
   if (!(InpUT_HA_Long > InpUT_HA_Moyen && InpUT_HA_Moyen > InpUT_HA_Court) ||
       ExtIndicatorHandleRSI == INVALID_HANDLE ||
       ExtIndicatorHandleDMI == INVALID_HANDLE ||
       ExtHandHeikenAshiUTL == INVALID_HANDLE ||
       ExtHandHeikenAshiUTM == INVALID_HANDLE ||
       ExtHandHeikenAshiUTC == INVALID_HANDLE)
    {
     // Print specific error messages for each failed initialization
     if (!(InpUT_HA_Long > InpUT_HA_Moyen && InpUT_HA_Moyen > InpUT_HA_Court))
      {
         Print("Erreur: Input_HA_Long, Moyen et Court doivent être cohérents. Arrêt de l'EA.");
      }
     if (ExtIndicatorHandleRSI == INVALID_HANDLE)
      {
        Print("Erreur à la création de l'indicateur RSI");
      }
     if (ExtIndicatorHandleDMI == INVALID_HANDLE)
      {
        Print("Erreur à la création de l'indicateur DMI");
      }
     if (ExtHandHeikenAshiUTL == INVALID_HANDLE || ExtHandHeikenAshiUTM == INVALID_HANDLE || ExtHandHeikenAshiUTC == INVALID_HANDLE)
      {
        Print("Erreur à la création de l'indicateur Heiken Ashi");
      }
    ExpertRemove(); // Remove the expert advisor
    return INIT_FAILED; // Return failure status
   }
   
   
// Affichage dans le journal des valeurs de SL et TP
   Print("InpSL=", InpSL);
   Print("InpTP=", InpTP);
   
//---Puis fin de l'initialisation
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- release indicator handle
   IndicatorRelease(ExtIndicatorHandleRSI);
   IndicatorRelease(ExtIndicatorHandleDMI);
   IndicatorRelease(ExtHandHeikenAshiUTL);
   IndicatorRelease(ExtHandHeikenAshiUTM);
   IndicatorRelease(ExtHandHeikenAshiUTC);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Global variables for next check times
    static datetime next_check_time_utlong = 0;
    static datetime next_check_time_utmoyen = 0;
    static datetime next_check_time_utcourt = 0;

    // Phase 1 - Check "Market Open" condition
    if (!MarketOpen())
        return;

    // Phase 2 - Check HA_composite with UT long and Taille Long
    if (TimeCurrent() >= next_check_time_utlong)
    {
        if (!CheckHAComposite(ExtHandHeikenAshiUTL, InpTaille_HAlong, 1.0))
        {
            CalculateNextBarTime(next_check_time_utlong, InpUT_HA_Long);
            return;
        }
    }

    // Phase 3 - Check HA_composite with UT moyen and Taille moyen
    if (TimeCurrent() >= next_check_time_utmoyen)
    {
        if (!CheckHAComposite(ExtHandHeikenAshiUTM, InpTaille_HAmoyen, 7.0) || RSI(0)<50)
        {
            CalculateNextBarTime(next_check_time_utmoyen, InpUT_HA_Moyen);
            return;
        }
    }

    // Phase 4 - Check HA_composite with UT court and Taille court
    if (TimeCurrent() >= next_check_time_utcourt)
    {
        if (!CheckHAComposite(ExtHandHeikenAshiUTC, InpTaille_HAcourt, 7.0) || DMI())
        {
            CalculateNextBarTime(next_check_time_utcourt, InpUT_HA_Court);
            return;
        }
    // If all conditions are met, execute FooBar function
    FooBar();
    }
}
//+------------------------------------------------------------------+
//| Function to calculate the next bar open time for a given period  |
//+------------------------------------------------------------------+
// 
void CalculateNextBarTime(datetime &next_check_time, ENUM_TIMEFRAMES timeframe)
{
    datetime next_bar_open = TimeCurrent();
    next_bar_open -= next_bar_open % PeriodSeconds(timeframe);
    next_bar_open += PeriodSeconds(timeframe);
    next_check_time = next_bar_open;
}

//+-----------------------------------------------------------------------------------------+
//| Function to check HA_composite value and return true if condition is met                |
//+-----------------------------------------------------------------------------------------+
// Function to check HA_composite value and return true if condition is met
bool CheckHAComposite(int handleHA, double parametreTaille, double threshold)
{
    double ha_composite_value = HA_composite(handleHA, parametreTaille);
    return ha_composite_value >= threshold;
}

//+------------------------------------------------------------------+
//| Fonction pour vérifier la condition "Market Open"                 |
//+------------------------------------------------------------------+
/* Si le jour de la semaine est du lundi au vendredi, donc 1 à 5 et que l'heure GMT 
est comprise dans les heures autorisées de trading, alors la vérification est positive
*/
bool MarketOpen()
{
   MqlDateTime tm={}; // Déclaration d'un objet de type MqlDateTime
   datetime    time2=TimeGMT(tm); //Récupération de l'heure GMT

   if((tm.day_of_week<6 && tm.day_of_week>0) && (tm.hour>=InpHeureDebut && tm.hour<InpHeureFin)) 
    {
           return(true); 
    }
   return(false);
}

//+------------------------------------------------------------------+
//| Indicateur composite de la bougie HA en cours                      |
//+------------------------------------------------------------------+
 double HA_composite(int handleHA, double parametreTaille)
{
    // Declare arrays to store Heiken Ashi candle properties
    double HA_couleur[1], HA_haut[1], HA_bas[1], HA_ouverture[1], HA_fermeture[1];
    
    // Retrieve Heiken Ashi candle properties
    if (CopyBuffer(handleHA, 0, 0, 1, HA_ouverture) < 0 ||
        CopyBuffer(handleHA, 1, 0, 1, HA_haut) < 0 ||
        CopyBuffer(handleHA, 2, 0, 1, HA_bas) < 0 ||
        CopyBuffer(handleHA, 3, 0, 1, HA_fermeture) < 0 ||
        CopyBuffer(handleHA, 4, 0, 1, HA_couleur) < 0)
    {
        // Handle error in retrieving indicator data
        PrintFormat("Error retrieving HA indicator values, code %d", GetLastError());
        return -1; 
    }
    
    // Determine the composite indicator value based on candle properties
    if (HA_couleur[0] == 1)
    {
        // Red candle
        return 0;
    }
    else
    {
        // Blue candle
        if (HA_ouverture[0] != HA_bas[0])
        {
            // Blue candle with no flat bottom
            return 1;
        }
        else
        {
            // Blue candle with flat bottom
            if (HA_fermeture[0] - HA_ouverture[0] < parametreTaille)
            {
                // Small body
                return 3;
            }
            else
            {
                // Large body
                return 7;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Indicateur RSI sur la barre spécifiée en index                   |
//+------------------------------------------------------------------+
   double RSI(int index)
     {
      double indicator_RSI_values[];
      if(CopyBuffer(ExtIndicatorHandleRSI, 0, index, 1, indicator_RSI_values)<0)
        {
         //--- En cas d'erreur de récuperation des données de l'indicateur
         PrintFormat("Erreur au moment de récupérer les valeurs de l'indicateur RSI, code %d", GetLastError());
         return(EMPTY_VALUE);
        }
      return(indicator_RSI_values[0]);
     }

//+------------------------------------------------------------------+
//| Indicateur DMI sur les 4 dernières bougies                       |
//+------------------------------------------------------------------+
/* L'indicateur est calculé sur les 4 dernières bougies
   Cette valeur de 4 est codée en dur : lecture du tampon à partir de la valeur en cours, 0
   et récupération de 4 valeurs    
*/
char DMI()
{
    double indicator_DMI_values_plus[4];
    double indicator_DMI_values_moins[4];
    
    // Retrieve DMI indicator values for the last 4 candles
    if (CopyBuffer(ExtIndicatorHandleDMI, 1, 0, 4, indicator_DMI_values_plus) < 0 ||
        CopyBuffer(ExtIndicatorHandleDMI, 2, 0, 4, indicator_DMI_values_moins) < 0)
    {
        // Handle error in retrieving indicator data
        PrintFormat("Error retrieving DMI indicator values, code %d", GetLastError());
        return -1;  // Or any appropriate error value
    }

    // Check if the last 3 candles show a trend from red to green on the DMI
    if (indicator_DMI_values_plus[3] < indicator_DMI_values_moins[3] &&
        indicator_DMI_values_plus[2] < indicator_DMI_values_moins[2] &&
        indicator_DMI_values_plus[1] < indicator_DMI_values_moins[1])
    {
        // Check if the current candle confirms the trend change to green
        if (indicator_DMI_values_plus[0] > indicator_DMI_values_moins[0])
        {
            return 1;  // Trend change confirmed
        }
    }
    // No trend change detected
    return 0;
}

//+------------------------------------------------------------------+
//| Function to execute when all conditions are met                  |
//+------------------------------------------------------------------+
void FooBar()
{
    // Add your logic to execute when all conditions are met
    Print("FooBar executed");
}