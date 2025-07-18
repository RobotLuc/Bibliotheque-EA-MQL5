//+------------------------------------------------------------------+
//|                                 BlackCrows WhiteSoldiers RSI.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Lucas Troncy - David Lhoyer"
//#property link      "https://www.mql5.com"
#property version   "1.01"

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
input int InpHeureDebut=9;                 // Ici, il faut mettre l'heure de début de trading en GMT
input int InpHeureFin=16;                  // Ici, on met l'heure de fin de trading en GMT
//input string SymboleATrader = "USDEUR"   // Ici on pourra mettre le symbole à trader

//--- Paramètres
input int  InpAverBodyPeriod=12;    // period for calculating average candlestick size

//--- Input parameters RSI
input int  InpPeriodRSI     =14;                      // Prise de moyenne du RSI
input ENUM_APPLIED_PRICE InpPriceRSI=PRICE_WEIGHTED;  // RSI est appliqué sur valeur pondérée
input ENUM_TIMEFRAMES InpUT_RSI = PERIOD_M15;         // Période du RSI, avec fixation sur UT15 par défaut

//--- Input parameters DMI
input int  InpPeriodDMI     =14;                      // Prise de moyenne du DMI
input ENUM_TIMEFRAMES InpUT_DMI = PERIOD_M2;          // Période du DMI, avec fixation sur UT2 par défaut

//--- Input parameters Heiken Ashi
input ENUM_TIMEFRAMES InpUT_HA4h = PERIOD_H4;  // Les périodes sont définies par des variables pour pouvoir
input ENUM_TIMEFRAMES InpUT_HA15m = PERIOD_M15;// être modifiées
input ENUM_TIMEFRAMES InpUT_HA2m = PERIOD_M2;  // plus facilement
input uint InpTailleHA2m;  // Taille du corps de bougie sur UT 4h
input uint InpTailleHA15m; // Taille du corps de bougie sur UT 15min


//--- Paramètres de trade
//input uint InpDuration=10;          // position holding time in bars
input uint InpSL      =200;         // Stop Loss en points
input uint InpTP      =200;         // Take Profit en points
input uint InpSlippage=10;          // slippage en points

//--- money management parameters
input double InpLot   =0.1;         // lot

//--- Expert ID
input long InpMagicNumber=100100;   // Magic Number, fixé à 100100 arbitrairement

//--- global variables
int    ExtAvgBodyPeriod;            // average candlestick calculation period
int    ExtSignalOpen     =0;        // Buy/Sell signal
int    ExtSignalClose    =0;        // signal to close a position
string ExtPatternInfo    ="";       // current pattern information
string ExtDirection      ="";       // position opening direction
bool   ExtPatternDetected=false;    // pattern detected
bool   ExtConfirmed      =false;    // pattern confirmed
bool   ExtCloseByTime    =true;     // requires closing by time
bool   ExtCheckPassed    =true;     // status checking error

//---  Initialisation des pointeurs d'indicateurs
int    ExtIndicatorHandleRSI=INVALID_HANDLE;  // Pointeur indicateur RSI
int    ExtIndicatorHandleDMI=INVALID_HANDLE;  // Pointeur indicateur DMI
int    ExtHandHeikenAshiUT4=INVALID_HANDLE;  // Pointeur indicateur H_A UT4h
int    ExtHandHeikenAshiUT2=INVALID_HANDLE;  // Pointeur indicateur H_A UT2min
int    ExtHandHeikenAshiUT15=INVALID_HANDLE;  // Pointeur indicateur H_A UT15min

//--- service objects
CTrade      ExtTrade;
CSymbolInfo ExtSymbolInfo;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
// Affichage dans le journal des valeurs de SL et TP
   Print("InpSL=", InpSL);
   Print("InpTP=", InpTP);
//--- Définition des paramètres pour l'objet de classe CTrade appelé
   ExtTrade.SetDeviationInPoints(InpSlippage);    // slippage
   ExtTrade.SetExpertMagicNumber(InpMagicNumber); // Expert Advisor ID
   ExtTrade.LogLevel(LOG_LEVEL_ERRORS);           // logging level
   ExtAvgBodyPeriod=InpAverBodyPeriod;            // Taille de la bougie
//+------------------------------------------------------------------+
//| Initialisation des Indicateurs, DMI, RSI et Heiken Ahis          |
//+------------------------------------------------------------------+
//--- Initialisation du RSI
   ExtIndicatorHandleRSI=iRSI(_Symbol, InpUT_RSI, InpPeriodRSI, InpPriceRSI);
   if(ExtIndicatorHandleRSI==INVALID_HANDLE)
     {
      Print("Erreur à la création de l'indicateur RSI");
      return(INIT_FAILED);
     }
//--- Initialisation du DMI
   ExtIndicatorHandleDMI=iADX(_Symbol, InpUT_DMI, InpPeriodDMI);
   if(ExtIndicatorHandleDMI==INVALID_HANDLE)
  {
   Print("Erreur à la création de l'indicateur DMI");
      return(INIT_FAILED);
     }
//--- Initialisation des Heiken Ashi
   ExtHandHeikenAshiUT4=iCustom(_Symbol,InpUT_HA4h,"\\Indicators\\Examples\\Heiken_Ashi");
   ExtHandHeikenAshiUT15=iCustom(_Symbol,InpUT_HA15m,"\\Indicators\\Examples\\Heiken_Ashi");
   ExtHandHeikenAshiUT2=iCustom(_Symbol,InpUT_HA2m,"\\Indicators\\Examples\\Heiken_Ashi");
   if(ExtHandHeikenAshiUT4==INVALID_HANDLE || ExtHandHeikenAshiUT15==INVALID_HANDLE || ExtHandHeikenAshiUT2==INVALID_HANDLE)
   {
    Print("Erreur à la création de l'indicateur Heiken Ashi");
      return(INIT_FAILED);
      }
//--- OK
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
   IndicatorRelease(ExtHandHeikenAshiUT4);
   IndicatorRelease(ExtHandHeikenAshiUT2);
   IndicatorRelease(ExtHandHeikenAshiUT15);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- save the next bar start time; all checks at bar opening only
   static datetime next_bar_open=0;

//--- Phase 1 - check the emergence of a new bar and update the status

//--- get the current state of environment on the new bar
// namely, set the values of global variables:
// ExtPatternDetected - pattern detection
// ExtConfirmed - pattern confirmation
// ExtSignalOpen - signal to open
// ExtSignalClose - signal to close
// ExtPatternInfo - current pattern information
// Cette initialisation est faite par l'appel de CheckState()

   if(TimeCurrent()>=next_bar_open) 
     {
      if(CheckState())
        {
         //--- set the new bar opening time de la barre de plus grande période (UT 4h dans la version de base)
         next_bar_open=TimeCurrent();
         next_bar_open-=next_bar_open%PeriodSeconds(InpUT_HA4h);
         next_bar_open+=PeriodSeconds(InpUT_HA4h);

         //--- report the emergence of a new bar only once within a bar
         if(ExtPatternDetected && ExtConfirmed)
            Print(ExtPatternInfo);
        }
      else
        {
         //--- error getting the status, retry on the next tick
         return;
        }
     }

//--- Phase 2 - S'il y a un signal d'achat et pas de position ouverte, ouvrir une position
   if(ExtSignalOpen && !PositionExist(ExtSignalOpen))
     {
      Print("\r\nSignal d'ouverture de position ", ExtDirection);
      PositionOpen();
      if(PositionExist(ExtSignalOpen))
         ExtSignalOpen=SIGNAL_NOT;
     }

//--- Phase 3 - S'il y a une position ouverte et un signal de fermeture, clore la position
   if(ExtSignalClose && PositionExist(ExtSignalClose))
     {
      Print("\r\nSignal de fermeture de position ", ExtDirection);
      CloseBySignal(ExtSignalClose);
      if(!PositionExist(ExtSignalClose))
         ExtSignalClose=SIGNAL_NOT;
     }
 }
//+------------------------------------------------------------------+
//|  Vérifie les conditions de marché dans l'ordre                   |
//+------------------------------------------------------------------+
   bool CheckState()
     {
      //--- vérifie si le marché est ouvert
      if(!CheckDate())
        {
         Print("Erreur, le marché est fermé");
         return(false);
        }       
  
      //--- puis vérfie si un motif est détecté
      if(!CheckPattern())
        {
         Print("Erreur, impossible de vérifier le motif");
         return(false);
        }

      //--- ensuite, vérifie si le motif est confirmé
      if(!CheckConfirmation())
        {
         Print("Erreur, impossible de confirmer le motif");
         return(false);
        }
        
      //--- if there is no confirmation, cancel the signal
      if(!ExtConfirmed)
         ExtSignalOpen=SIGNAL_NOT;

      //--- check if there is a signal to close a position
      if(!CheckCloseSignal())
        {
         Print("Error, failed to check the closing signal");
         return(false);
        }
        
      //--- Si tous les tests sont positifs, alors confirme le motif
      return(true);
     }
 
//+------------------------------------------------------------------+
//|  Vérifie le jour et l'heure actuelle                             |
//+------------------------------------------------------------------+
// Si le marché est fermé, il n'est pas nécessaire de trader
   bool CheckDate()
      {
       MqlDateTime tm={}; // Déclaration d'un objet de type MqlDateTime
       datetime    time2=TimeGMT(tm); //Récupération de l'heure GMT

       if((tm.day_of_week<6 && tm.day_of_week>0) && (tm.hour>=InpHeureDebut && tm.hour<InpHeureFin)) 
          {
           // Si le jour de la semaine est du lundi au vendredi, donc 1 à 5 et que l'heure GMT est comprise dans les
           // heures autorisées de trading, alors la vérification est positive
           return(true); 
          }
       return(false); // Sinon, retourner la valeur fausse   
      }  
//+------------------------------------------------------------------+
//| Vérifie l'existence d'un motif. Renvoie "faux" si pas de motif   |
//+------------------------------------------------------------------+
   bool CheckPattern()
     {
      ExtPatternDetected=false;
      ExtSignalOpen=SIGNAL_NOT;
      ExtPatternInfo="\r\nMotif non detecté";
      ExtDirection="";
/*
      //--- Motif de vente
      if()
        {
         ExtPatternDetected=true;
         ExtSignalOpen=SIGNAL_SELL;
         ExtPatternInfo="\r\nMotif de vente détecté";
         ExtDirection="Vendre";
         return(true);
        }
*/

      //--- Motif d'Achat
      if(HA_composite(ExtHandHeikenAshiUT4,0)>0 &&
        HA_composite(ExtHandHeikenAshiUT15,InpTailleHA15m)>=7 &&
        RSI(0)>50)
         {
         ExtPatternDetected=true;
         ExtSignalOpen=SIGNAL_BUY;
         ExtPatternInfo="\r\nMotif d'achat détecté";
         ExtDirection="Acheter";
         return(true);
        }

      //--- result of checking
      return(ExtCheckPassed);
     }
//+---------------------------------------------------------------------------------------+
//| Confirmation check : returns true in case of successful confirmation check            |
//+---------------------------------------------------------------------------------------+
   bool CheckConfirmation()
     {
      ExtConfirmed=false;
      //--- if there is no pattern, do not search for confirmation
      if(!ExtPatternDetected)
         return(true);

      //--- get the value of the stochastic indicator to confirm the signal
      double checkDMI=DMI();
      double checkHA=HA_composite(ExtHandHeikenAshiUT2,InpTailleHA2m);
      if(checkDMI==-EMPTY_VALUE || checkHA==-EMPTY_VALUE)
        {
         //--- failed to get indicator value, check failed
         return(false);
        }

      //--- check the Buy signal
      if(ExtSignalOpen==SIGNAL_BUY && (checkDMI+checkHA==8))
        {
         ExtConfirmed=true;
         ExtPatternInfo+="\r\n   Confirmé : bougie HA sur UT2 et DMI UT2 validés";
        }

      //--- check the Sell signal
      /*if(ExtSignalOpen==SIGNAL_SELL && (signal>60))
        {
         ExtConfirmed=true;
         ExtPatternInfo+="\r\n   Confirmed: RSI>60";
        }
*/
      //--- successful completion of the check
      return(true);
     }

//+------------------------------------------------------------------+
//| Open a position in the direction of the signal                   |
//+------------------------------------------------------------------+
   bool PositionOpen()
     {
      ExtSymbolInfo.Refresh();
      ExtSymbolInfo.RefreshRates();

      double price=0;
      //--- Stop Loss and Take Profit are not set by default
      double stoploss=0.0;
      double takeprofit=0.0;

      int    digits=ExtSymbolInfo.Digits();
      double point=ExtSymbolInfo.Point();
      double spread=ExtSymbolInfo.Ask()-ExtSymbolInfo.Bid();

      //--- uptrend
      if(ExtSignalOpen==SIGNAL_BUY)
        {
         price=NormalizeDouble(ExtSymbolInfo.Ask(), digits);
         //--- if Stop Loss is set
         if(InpSL>0)
           {
            if(spread>=InpSL*point)
              {
               PrintFormat("StopLoss (%d points) <= current spread = %.0f points. Spread value will be used", InpSL, spread/point);
               stoploss = NormalizeDouble(price-spread, digits);
              }
            else
               stoploss = NormalizeDouble(price-InpSL*point, digits);
           }
         //--- if Take Profit is set
         if(InpTP>0)
           {
            if(spread>=InpTP*point)
              {
               PrintFormat("TakeProfit (%d points) < current spread = %.0f points. Spread value will be used", InpTP, spread/point);
               takeprofit = NormalizeDouble(price+spread, digits);
              }
            else
               takeprofit = NormalizeDouble(price+InpTP*point, digits);
           }

         if(!ExtTrade.Buy(InpLot, Symbol(), price, stoploss, takeprofit))
           {
            PrintFormat("Failed %s buy %G at %G (sl=%G tp=%G) failed. Ask=%G error=%d",
                        Symbol(), InpLot, price, stoploss, takeprofit, ExtSymbolInfo.Ask(), GetLastError());
            return(false);
           }
        }

      //--- downtrend
      if(ExtSignalOpen==SIGNAL_SELL)
        {
         price=NormalizeDouble(ExtSymbolInfo.Bid(), digits);
         //--- if Stop Loss is set
         if(InpSL>0)
           {
            if(spread>=InpSL*point)
              {
               PrintFormat("StopLoss (%d points) <= current spread = %.0f points. Spread value will be used", InpSL, spread/point);
               stoploss = NormalizeDouble(price+spread, digits);
              }
            else
               stoploss = NormalizeDouble(price+InpSL*point, digits);
           }
         //--- if Take Profit is set
         if(InpTP>0)
           {
            if(spread>=InpTP*point)
              {
               PrintFormat("TakeProfit (%d points) < current spread = %.0f points. Spread value will be used", InpTP, spread/point);
               takeprofit = NormalizeDouble(price-spread, digits);
              }
            else
               takeprofit = NormalizeDouble(price-InpTP*point, digits);
           }

         if(!ExtTrade.Sell(InpLot, Symbol(), price,  stoploss, takeprofit))
           {
            PrintFormat("Failed %s sell at %G (sl=%G tp=%G) failed. Bid=%G error=%d",
                        Symbol(), price, stoploss, takeprofit, ExtSymbolInfo.Bid(), GetLastError());
            ExtTrade.PrintResult();
            Print("   ");
            return(false);
           }
        }

      return(true);
     }
//+------------------------------------------------------------------+
//|  Close a position based on the specified signal                  |
//+------------------------------------------------------------------+
   void CloseBySignal(int type_close)
     {
      //--- if there is no signal to close, return successful completion
      if(type_close==SIGNAL_NOT)
         return;
      //--- if there are no positions opened by our EA
      if(PositionExist(ExtSignalClose)==0)
         return;

      //--- closing direction
      long type;
      switch(type_close)
        {
         case CLOSE_SHORT:
            type=POSITION_TYPE_SELL;
            break;
         case CLOSE_LONG:
            type=POSITION_TYPE_BUY;
            break;
         default:
            Print("Error! Signal to close not detected");
            return;
        }

      //--- check all positions and close ours based on the signal
      int positions=PositionsTotal();
      for(int i=positions-1; i>=0; i--)
        {
         ulong ticket=PositionGetTicket(i);
         if(ticket!=0)
           {
            //--- get the name of the symbol and the position id (magic)
            string symbol=PositionGetString(POSITION_SYMBOL);
            long   magic =PositionGetInteger(POSITION_MAGIC);
            //--- if they correspond to our values
            if(symbol==Symbol() && magic==InpMagicNumber)
              {
               if(PositionGetInteger(POSITION_TYPE)==type)
                 {
                  ExtTrade.PositionClose(ticket, InpSlippage);
                  ExtTrade.PrintResult();
                  Print("   ");
                 }
              }
           }
        }
     }

//+------------------------------------------------------------------+
//| Returns true if there are open positions                         |
//+------------------------------------------------------------------+
   bool PositionExist(int signal_direction)
     {
      bool check_type=(signal_direction!=SIGNAL_NOT);

      //--- what positions to search
      ENUM_POSITION_TYPE search_type=WRONG_VALUE;
      if(check_type)
         switch(signal_direction)
           {
            case SIGNAL_BUY:
               search_type=POSITION_TYPE_BUY;
               break;
            case SIGNAL_SELL:
               search_type=POSITION_TYPE_SELL;
               break;
            case CLOSE_LONG:
               search_type=POSITION_TYPE_BUY;
               break;
            case CLOSE_SHORT:
               search_type=POSITION_TYPE_SELL;
               break;
            default:
               //--- entry direction is not specified; nothing to search
               return(false);
           }

      //--- go through the list of all positions
      int positions=PositionsTotal();
      for(int i=0; i<positions; i++)
        {
         if(PositionGetTicket(i)!=0)
           {
            //--- if the position type does not match, move on to the next one
            ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if(check_type && (type!=search_type))
               continue;
            //--- get the name of the symbol and the expert id (magic number)
            string symbol =PositionGetString(POSITION_SYMBOL);
            long   magic  =PositionGetInteger(POSITION_MAGIC);
            //--- if they correspond to our values
            if(symbol==Symbol() && magic==InpMagicNumber)
              {
               //--- yes, this is the right position, stop the search
               return(true);
              }
           }
        }

      //--- open position not found
      return(false);
     }

//+------------------------------------------------------------------+
//| Check if there is a signal to close                              |
//+------------------------------------------------------------------+
   bool CheckCloseSignal()
     {
      ExtSignalClose=false;
      //--- if there is a signal to enter the market, do not check the signal to close
      if(ExtSignalOpen!=SIGNAL_NOT)
         return(true);

      //--- check if there is a signal to close a long position
      if(((RSI(1)<70) && (RSI(2)>70)) || ((RSI(1)<30) && (RSI(2)>30)))
        {
         //--- there is a signal to close a long position
         ExtSignalClose=CLOSE_LONG;
         ExtDirection="Long";
        }

      //--- check if there is a signal to close a short position
      if(((RSI(1)>30) && (RSI(2)<30)) || ((RSI(1)>70) && (RSI(2)<70)))
        {
         //--- there is a signal to close a short position
         ExtSignalClose=CLOSE_SHORT;
         ExtDirection="Short";
        }

      //--- successful completion of the check
      return(true);
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

//+------------------------------------------------------------------+
//| Indicateur DMI sur les 4 dernières bougies                       |
//+------------------------------------------------------------------+
/* L'indicateur est calculé sur les 4 dernières bougies
   Cette valeur de 4 est codée en dur : lecture du tampon à partir de la valeur en cours, 0
   et récupération de 4 valeurs    
*/
double DMI()
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

//+------------------------------------------------------------------+
//| Indicateur composite de la bougie HA en cours                      |
//+------------------------------------------------------------------+
 double HA_composite(int handleHA, uint parametreTaille)
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
        return -1;  // Or any appropriate error code or value
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
