//+------------------------------------------------------------------+
// Squelette de Robot de trading générique                           | 
// Version : 1.0                                                     |
//Notes de version :                                                 |
// * Basé sur DavidLucas-v1.0                                        |
// * v0.0 - 13/09/2024 - reprise du travail sur le robot             |
// * v1.0 - 29/09/24 mise en place du squelette d'algorithme complet |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Lucas Troncy - David Lhoyer"
#property version   "1.0"

//--- Appel aux fonctions exterieures
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

//--- Objets. ExtTrade sera utilisé pour passer les ordres d'achat et de vente
CTrade      ExtTrade;
CSymbolInfo ExtSymbolInfo;

//--- Expert ID
input long InpMagicNumber=100100;   // Numéro magique de l'Expert Advisor, fixé à 100100 arbitrairement


//--- Paramètres d'heures de marché et de marché
input int InpHeureDebut=8;                 // Heure de début de trading en GMT
input int InpHeureFin=16;                  // Heure de fin de trading en GMT
//input string SymboleATrader = "USDEUR"   // Symbole à trader


//--- Variables globales

enum IND_POSITION
{
  P_SHORT = -1,
  P_NOT = 0,
  P_LONG = 1
};

enum IND_ENTREE
{
  E_SHORT = -1,
  E_NOT = 0,
  E_LONG = 1
};

int g_IND_POSITION =IND_POSITION::P_NOT;  // Initialisation : pas de position pour démarrer
int g_IND_ENTREE =IND_ENTREE::E_NOT;    // Initialisation : pas de signal d'entrée
datetime g_next_check_time = 0; // Variable statique locale qui définit la prochaine heure d'exécution des détections de motif

//--- Paramètres de trading
input uint InpSL      =100;         // Stop Loss en points
input uint InpTP      =100;         // Take Profit en points - laisser à zéro sinon plantage garanti !
input uint InpSlippage=10;          // Slippage en points
input double InpLot   =0.1;         // Taille de lot



// Création des paramètres du Motif d'Entrée

   //--- Paramètres d'entrée RSI
   input int  InpPeriodRSI     =14;                      // Période moyenne du RSI
   input ENUM_APPLIED_PRICE InpPriceRSI=PRICE_WEIGHTED;  // RSI appliqué au prix pondéré
   input ENUM_TIMEFRAMES InpUT_RSI = PERIOD_M15;         // Période du RSI, réglée sur M15 par défaut

   //--- Paramètres d'entrée DMI
   input int  InpPeriodDMI     =14;                      // Période moyenne du DMI
   input ENUM_TIMEFRAMES InpUT_DMI = PERIOD_M2;          // Période du DMI, réglée sur M2 par défaut

   //--- Paramètres d'entrée Heiken Ashi
   input ENUM_TIMEFRAMES InpUT_HA_Long = PERIOD_H4;   // Période Heiken Ashi la plus longue
   input ENUM_TIMEFRAMES InpUT_HA_Moyen = PERIOD_M15; // Période Heiken Ashi intermédiaire
   input ENUM_TIMEFRAMES InpUT_HA_Court = PERIOD_M2;  // Période Heiken Ashi la plus courte

   input double   InpTaille_HAlong = 0.004; // Taille du corps de bougie sur UT long
   input double   InpTaille_HAmoyen = 0.003; // Taille du corps de bougie sur UT moyen
   input double   InpTaille_HAcourt = 0.003;  // Taille du corps de bougie sur UT court



//--- Initialisation des pointeurs d'indicateurs
   int    ExtIndicatorHandleRSI=INVALID_HANDLE;  // Pointeur de l'indicateur RSI
   int    ExtIndicatorHandleDMI=INVALID_HANDLE;  // Pointeur de l'indicateur DMI
   int    ExtHandHeikenAshiUTL=INVALID_HANDLE;  // Pointeur de l'indicateur Heiken Ashi UT Long
   int    ExtHandHeikenAshiUTC=INVALID_HANDLE;  // Pointeur de l'indicateur Heiken Ashi UT court
   int    ExtHandHeikenAshiUTM=INVALID_HANDLE;  // Pointeur de l'indicateur Heiken Ashi UT moyen

//+------------------------------------------------------------------+
//| Fonction d'initialisation de l'Expert Advisor                     |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Définition des paramètres pour l'objet CTrade
    ExtTrade.SetDeviationInPoints(InpSlippage);    // Slippage
    ExtTrade.SetExpertMagicNumber(InpMagicNumber); // Numéro magique de l'Expert Advisor
    ExtTrade.LogLevel(LOG_LEVEL_ERRORS);           // Niveau de logging

    //--- Initialisation des indicateurs : DMI, RSI et Heiken Ashi
    ExtIndicatorHandleRSI=iRSI(_Symbol, InpUT_RSI, InpPeriodRSI, InpPriceRSI);
    ExtIndicatorHandleDMI=iADX(_Symbol, InpUT_DMI, InpPeriodDMI);
    ExtHandHeikenAshiUTL=iCustom(_Symbol,InpUT_HA_Long,"\\Indicators\\Examples\\Heiken_Ashi");
    ExtHandHeikenAshiUTM=iCustom(_Symbol,InpUT_HA_Moyen,"\\Indicators\\Examples\\Heiken_Ashi");
    ExtHandHeikenAshiUTC=iCustom(_Symbol,InpUT_HA_Court,"\\Indicators\\Examples\\Heiken_Ashi");

    // Vérifier toutes les initialisations dans un bloc conditionnel unique
    if (!(InpUT_HA_Long > InpUT_HA_Moyen && InpUT_HA_Moyen > InpUT_HA_Court) ||
       ExtIndicatorHandleRSI == INVALID_HANDLE ||
       ExtIndicatorHandleDMI == INVALID_HANDLE ||
       ExtHandHeikenAshiUTL == INVALID_HANDLE ||
       ExtHandHeikenAshiUTM == INVALID_HANDLE ||
       ExtHandHeikenAshiUTC == INVALID_HANDLE)
    {
        // Afficher un message d'erreur spécifique pour chaque initialisation échouée
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
        
        ExpertRemove(); // Supprimer l'Expert Advisor
        return INIT_FAILED; // Retourner un statut d'échec
    }

    // Affichage dans le journal des valeurs de SL et TP
    Print("InpSL=", InpSL);
    Print("InpTP=", InpTP);

    // Fin de l'initialisation
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Fonction de désinitialisation de l'Expert Advisor                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Libérer les pointeurs des indicateurs
    IndicatorRelease(ExtIndicatorHandleRSI);
    IndicatorRelease(ExtIndicatorHandleDMI);
    IndicatorRelease(ExtHandHeikenAshiUTL);
    IndicatorRelease(ExtHandHeikenAshiUTM);
    IndicatorRelease(ExtHandHeikenAshiUTC);
}

//+------------------------------------------------------------------+
//| Fonction de tick de l'Expert Advisor                               |
//+------------------------------------------------------------------+
void OnTick()
  {
     
   if (!IsMarketOpen()) {return;}
   if (TimeCurrent() < g_next_check_time) {return;}
   if (g_IND_POSITION == P_NOT) // S'il n'y a pas de position ouverte, on teste si on a le signal pour entrer sur le marché
     {
       if (!testEntree() || !validationEntree()) {return;}          // S'il n'y a pas de signal ou bien qu'il n'y a pas de confirmation, on arrête
       else PlacerOrdre();                                          // Si toutes les conditions sont remplies, placer l'ordre qui va bien
      }            
   else // S'il y a au moins une position ouverte, on teste pour savoir si on a une configuration de dénouement
      {
   // Faire une boucle pour chaque lot encore possédé
   // si un lot a une condition de sortie, continuer la boucle sans mettre à jour g_next_check_time
   // si aucun lot n'a de condition de sortie, mettre à jour g_next_check_time puis sortir
      }
     
  }

//---------------------------------------------------------------------
// FONCTIONS ANNEXES
//---------------------------------------------------------------------

//+------------------------------------------------------------------+
//| Fonction pour vérifier la condition "Marché Ouvert"              |
//+------------------------------------------------------------------+
/* Si le jour de la semaine est du lundi au vendredi, donc 1 à 5 et que l'heure GMT 
est comprise dans les heures autorisées de trading, alors la vérification est positive
*/
bool IsMarketOpen()
{
   MqlDateTime tm={}; // Déclaration d'un objet de type MqlDateTime
   datetime    time2=TimeGMT(tm); //Récupération de l'heure GMT en remplissant la structure tm

   if((tm.day_of_week<6 && tm.day_of_week>0) && (tm.hour>=InpHeureDebut && tm.hour<InpHeureFin)) 
    {
           return(true); 
    }
   return(false);
}

//+------------------------------------------------------------------+
//| Fonction test entrée                                             |
//+------------------------------------------------------------------+

bool testEntree()
{
   if (HAcouleur(ExtHandHeikenAshiUTL)==0) // c'est que la bougie Long Terme est bleue
        {
          if (!(HAComposite(ExtHandHeikenAshiUTM, InpTaille_HAmoyen)==1 && RSI(0)>50))
             {
              CalculateNextBarTime(g_next_check_time, InpUT_HA_Moyen);
              g_IND_ENTREE = E_NOT;
              return false;
             }

          if (!(HAComposite(ExtHandHeikenAshiUTC, InpTaille_HAcourt)==1 && DMI()))
             {
              CalculateNextBarTime(g_next_check_time, InpUT_HA_Court);
              g_IND_ENTREE = E_NOT;
              return false;
             } 
          else // toutes les conditions sont remplies et la bougie Long Terme est bleue donc on a une position longue possible 
             {
              g_IND_ENTREE = E_LONG;
              return true;
             }
          }

   if (HAcouleur(ExtHandHeikenAshiUTL)==1) // c'est que la bougie Long Terme est rouge
        {
          if (!(HAComposite(ExtHandHeikenAshiUTM, InpTaille_HAmoyen)==-1 && RSI(0)<50))
             {
              CalculateNextBarTime(g_next_check_time, InpUT_HA_Moyen);
              g_IND_ENTREE = E_NOT;
              return false;
             }

          if (!(HAComposite(ExtHandHeikenAshiUTC, InpTaille_HAcourt)==-1 && DMI()))
             {
              CalculateNextBarTime(g_next_check_time, InpUT_HA_Court);
              g_IND_ENTREE = E_NOT;
              return false;
             } 
          else // toutes les conditions sont remplies et la bougie Long Terme est rouge donc on a une position short possible 
             {
              g_IND_ENTREE = E_SHORT;
              return true;
             }
          }
return false;
}
//+------------------------------------------------------------------+
//| Fonction validation entrée                                       |
//+------------------------------------------------------------------+

bool validationEntree()
{
// Mettre ici toutes les conditions de validation d'entrée qu'on veut
return true;
}

//+------------------------------------------------------------------+
//| Fonction à exécuter lorsque toutes les conditions sont remplies   |
//+------------------------------------------------------------------+
bool PlacerOrdre()
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

//--- Entrée sur une position LONGUE

   if (g_IND_ENTREE==E_LONG)
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
      if (InpTP>0)
        {
         if(spread>=InpTP*point)
           {
            PrintFormat("TakeProfit (%d points) < current spread = %.0f points. Spread value will be used", InpTP, spread/point);
            takeprofit = NormalizeDouble(price+spread, digits);
           }
         else
            takeprofit = NormalizeDouble(price+InpTP*point, digits);
        }
      if (!ExtTrade.Buy(InpLot, Symbol(), price, stoploss, takeprofit))
        {
         PrintFormat("Failed %s buy %G at %G (sl=%G tp=%G) failed. Ask=%G error=%d",
                     Symbol(), InpLot, price, stoploss, takeprofit, ExtSymbolInfo.Ask(), GetLastError());
         return(false);
        }
        g_IND_POSITION = P_LONG;
        g_IND_ENTREE = E_NOT;
     }

//--- Entrée sur une position SHORT
   if (g_IND_ENTREE==E_SHORT)
     {
      price=NormalizeDouble(ExtSymbolInfo.Bid(), digits);
      //--- if Stop Loss is set
      if (InpSL>0)
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
      if (InpTP>0)
        {
         if(spread>=InpTP*point)
           {
            PrintFormat("TakeProfit (%d points) < current spread = %.0f points. Spread value will be used", InpTP, spread/point);
            takeprofit = NormalizeDouble(price-spread, digits);
           }
         else
            takeprofit = NormalizeDouble(price-InpTP*point, digits);
        }
      if (!ExtTrade.Sell(InpLot, Symbol(), price,  stoploss, takeprofit))
        {
         PrintFormat("Failed %s sell at %G (sl=%G tp=%G) failed. Bid=%G error=%d",
                     Symbol(), price, stoploss, takeprofit, ExtSymbolInfo.Bid(), GetLastError());
         ExtTrade.PrintResult();
         Print("   ");
         return(false);
        }
        g_IND_POSITION = P_SHORT;
        g_IND_ENTREE = E_NOT;
     }

    Print("Indice long : ",HAComposite(ExtHandHeikenAshiUTL,InpTaille_HAlong));
    Print("Indice moyen : ",HAComposite(ExtHandHeikenAshiUTM,InpTaille_HAmoyen));
    Print("RSI : ",RSI(0));
    Print("Indice court : ",HAComposite(ExtHandHeikenAshiUTC,InpTaille_HAcourt));
    Print("DMI : ",DMI());
    return(true);
  }

//+------------------------------------------------------------------+
//| Fonction pour calculer le temps d'ouverture de la prochaine barre |
//+------------------------------------------------------------------+
void CalculateNextBarTime(datetime &next_check_time, ENUM_TIMEFRAMES timeframe)
{
    datetime next_bar_open = TimeCurrent();
    next_bar_open -= next_bar_open % PeriodSeconds(timeframe);
    next_bar_open += PeriodSeconds(timeframe);
    next_check_time = next_bar_open;
}

//---------------------------------------------------------------------
// INDICATEURS
//---------------------------------------------------------------------

//+------------------------------------------------------------------+
//| Couleur de la bougie HA en cours                                 |
//+------------------------------------------------------------------+

double HAcouleur(int handleHA) 
{
    // Déclaration des tableaux pour stocker les propriétés des bougies Heiken Ashi
    double HA_couleur[1];
    
    // Récupération des propriétés des bougies Heiken Ashi
    if (CopyBuffer(handleHA, 4, 0, 1, HA_couleur) < 0)
    {
        // Gérer l'erreur lors de la récupération des données de l'indicateur
        PrintFormat("Erreur lors de la récupération des valeurs de l'indicateur HA, code %d", GetLastError());
        return -1; 
    }
    else return HA_couleur[0];
}

//+------------------------------------------------------------------+
//| Indicateur composite de la bougie HA en cours                    |
//+------------------------------------------------------------------+
 int HAComposite(int handleHA, double parametreTaille)
{
    // Déclaration des tableaux pour stocker les propriétés des bougies Heiken Ashi
    double HA_couleur[1], HA_haut[1], HA_bas[1], HA_ouverture[1], HA_fermeture[1];
    
    // Récupération des propriétés des bougies Heiken Ashi
    if (CopyBuffer(handleHA, 0, 0, 1, HA_ouverture) < 0 ||
        CopyBuffer(handleHA, 1, 0, 1, HA_haut) < 0 ||
        CopyBuffer(handleHA, 2, 0, 1, HA_bas) < 0 ||
        CopyBuffer(handleHA, 3, 0, 1, HA_fermeture) < 0 ||
        CopyBuffer(handleHA, 4, 0, 1, HA_couleur) < 0)
    {
        // Gérer l'erreur lors de la récupération des données de l'indicateur
        PrintFormat("Erreur lors de la récupération des valeurs de l'indicateur HA, code %d", GetLastError());
        return -2; 
    }
    
    // Déterminer la valeur de l'indicateur composite en fonction des propriétés de la bougie
    if (HA_couleur[0] == 0 && HA_ouverture[0] == HA_bas[0] && HA_fermeture[0] - HA_ouverture[0] >= parametreTaille)
       {
       return 1;
       // Bougie bleue, grand corps, cul plat
       }
    else if (HA_couleur[0] == 1 && HA_ouverture[0] == HA_haut[0] && HA_ouverture[0] - HA_fermeture[0] >= parametreTaille)
       {
       return -1;
       // Bougie rouge, grand corps, cul plat
       }
     else return 0; // Pas de motif ni long ni short
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
         PrintFormat("Erreur lors de la récupération des valeurs de l'indicateur RSI, code %d", GetLastError());
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
    
    // Récupérer les valeurs de l'indicateur DMI pour les 4 dernières bougies
    if (CopyBuffer(ExtIndicatorHandleDMI, 1, 0, 4, indicator_DMI_values_plus) < 0 ||
        CopyBuffer(ExtIndicatorHandleDMI, 2, 0, 4, indicator_DMI_values_moins) < 0)
    {
        // Gérer l'erreur lors de la récupération des données de l'indicateur
        PrintFormat("Erreur lors de la récupération des valeurs de l'indicateur DMI, code %d", GetLastError());
        return -1;  // Ou toute autre valeur d'erreur appropriée
    }

    // Vérifier si les 3 dernières bougies montrent une tendance du rouge vers le vert sur le DMI
    if (indicator_DMI_values_plus[3] < indicator_DMI_values_moins[3] &&
        indicator_DMI_values_plus[2] < indicator_DMI_values_moins[2] &&
        indicator_DMI_values_plus[1] < indicator_DMI_values_moins[1])
    {
        // Vérifier si la bougie actuelle confirme le changement de tendance vers le vert
        if (indicator_DMI_values_plus[0] > indicator_DMI_values_moins[0])
        {
            return 1;  // Changement de tendance confirmé
        }
    }
    // Aucun changement de tendance détecté
    return 0;
}