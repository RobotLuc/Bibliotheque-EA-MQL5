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

    // Phase 2 - Vérifie HA_composite avec UT long and Taille Long
    if (TimeCurrent() >= next_check_time_utlong)
    {
        double ha_composite_utlong = HA_composite(ExtHandHeikenAshiUTL, InpTaille_HAlong);
        if (ha_composite_utlong < 1.0)
        {
            // Calculate the next bar open time for InpUT_HA_Long
            datetime next_bar_open = TimeCurrent();
            next_bar_open -= next_bar_open % PeriodSeconds(InpUT_HA_Long);
            next_bar_open += PeriodSeconds(InpUT_HA_Long);
            next_check_time_utlong = next_bar_open;
            return;
        }
        else
        {
            // Phase 3 - Vérifie HA_composite avec UT moyen and Taille moyen
            if (TimeCurrent() >= next_check_time_utmoyen)
            {
                double ha_composite_utmoyen = HA_composite(ExtHandHeikenAshiUTM, InpTaille_HAmoyen);
                if (ha_composite_utmoyen < 7.0)
                {
                    // Calculate the next bar open time for InpUT_HA_moyen
                    datetime next_bar_open = TimeCurrent();
                    next_bar_open -= next_bar_open % PeriodSeconds(InpUT_HA_Moyen);
                    next_bar_open += PeriodSeconds(InpUT_HA_Moyen);
                    next_check_time_utmoyen = next_bar_open;
                    return;
                }
                else
                {
                    // Phase 4 - Vérifie HA_composite avec UT court and Taille court
                    if (TimeCurrent() >= next_check_time_utcourt)
                    {
                        double ha_composite_utcourt = HA_composite(ExtHandHeikenAshiUTC, InpTaille_HAcourt);
                        if (ha_composite_utcourt < 7.0)
                        {
                            // Calculate the next bar open time for UT court
                            datetime next_bar_open = TimeCurrent();
                            next_bar_open -= next_bar_open % PeriodSeconds(InpUT_HA_Court);
                            next_bar_open += PeriodSeconds(InpUT_HA_Court);
                            next_check_time_utcourt = next_bar_open;
                            return;
                        }
                        else
                        {
                            // Execute FooBar function if all conditions are met
                            FooBar();
                            return;
                        }
                    }
                }
            }
        }
    }
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
//| Function to execute when all conditions are met                  |
//+------------------------------------------------------------------+
void FooBar()
{
    // Add your logic to execute when all conditions are met
    Print("FooBar executed");
}