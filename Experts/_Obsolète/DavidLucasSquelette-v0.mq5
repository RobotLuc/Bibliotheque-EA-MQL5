//+------------------------------------------------------------------+
// Squelette de Robot de trading générique                           | 
// Version : 0.0                                                     |
//Notes de version :                                                 |
// * Basé sur DavidLucas-v1.0                                        |
// *13/09/2024 - reprise du travail sur le robot                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Lucas Troncy - David Lhoyer"
#property version   "0.0"

//--- Appel aux fonctions exterieures
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

//--- Objets. ExtTrade sera utilisé pour passer les ordres d'achat et de vente
CTrade      ExtTrade;
CSymbolInfo ExtSymbolInfo;

//--- Expert ID
input long InpMagicNumber=100100;   // Numéro magique de l'Expert Advisor, fixé à 100100 arbitrairement

//--- Initialisation des signaux
#define SIGNAL_BUY    1             // Signal d'achat
#define SIGNAL_NOT    0             // Aucun signal de trading
#define SIGNAL_SELL  -1             // Signal de vente
#define CLOSE_LONG    2             // Signal de clôture de position Long
#define CLOSE_SHORT  -2             // Signal de clôture de position Short

//--- Paramètres d'heures de marché et de marché
input int InpHeureDebut=8;                 // Heure de début de trading en GMT
input int InpHeureFin=16;                  // Heure de fin de trading en GMT
//input string SymboleATrader = "USDEUR"   // Symbole à trader
datetime g_next_check_time = 0; // Variable globale qui définit la prochaine heure d'exécution des détections de motif



//--- Paramètres de trading
input uint InpSL      =100;         // Stop Loss en points
input uint InpTP      =100;         // Take Profit en points
input uint InpSlippage=10;          // Slippage en points
input double InpLot   =0.1;         // Taille de lot

// Création des paramètres du Motif

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
   if (!IsTimeToTest()) {return;}
   if (!IsPatternDetected()) {return;} // IsPatternDetected() doit mettre à jour l'indicateur d'ordre et l'heure de prochain test
   if (!IsPatternConfirmed()) {return;} // Check final pour s'assurer que des variables exogènes ne sont pas présentes (FED,déjeuner....)
   FooBar(); // Si toutes les conditions sont remplies, exécute l'ordre
     
  }

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
//| Fonction pour vérifier la condition "Il est l'heure de tester"   |
//+------------------------------------------------------------------+

// Simple test pour savoir si l'heure actuelle est supérieure à l'heure du prochain test
// défini par la variable globale g_next_check_time

bool IsTimeToTest()
{
    if (TimeCurrent() >= g_next_check_time)
   {
           return(true); 
    }
   return(false); 
}

//+------------------------------------------------------------------+
//| Fonction pour vérifier la condition "Il est l'heure de tester"   |
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| Fonction à exécuter lorsque toutes les conditions sont remplies   |
//+------------------------------------------------------------------+
void FooBar()
{
    // Ajouter votre logique à exécuter lorsque toutes les conditions sont remplies
    Print("Indice long : ",HA_composite(ExtHandHeikenAshiUTL,InpTaille_HAlong));
    Print("Indice moyen : ",HA_composite(ExtHandHeikenAshiUTM,InpTaille_HAmoyen));
    Print("RSI : ",RSI(0));
    Print("Indice court : ",HA_composite(ExtHandHeikenAshiUTC,InpTaille_HAcourt));
    Print("DMI : ",DMI());
}
//---------------------------------------------------------------------
// FONCTIONS ANNEXES
//---------------------------------------------------------------------

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

//+-----------------------------------------------------------------------------------------+
//| Fonction pour vérifier la valeur de HA_composite et retourner true si la condition est remplie |
//+-----------------------------------------------------------------------------------------+
bool CheckHAComposite(int handleHA, double parametreTaille, double seuil)
{
    double ha_composite_value = HA_composite(handleHA, parametreTaille);
    return ha_composite_value >= seuil;
}

//---------------------------------------------------------------------
// INDICATEURS
//---------------------------------------------------------------------


//+------------------------------------------------------------------+
//| Indicateur composite de la bougie HA en cours                    |
//+------------------------------------------------------------------+
 double HA_composite(int handleHA, double parametreTaille)
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
        return -1; 
    }
    
    // Déterminer la valeur de l'indicateur composite en fonction des propriétés de la bougie
    if (HA_couleur[0] == 1)
    {
        // Bougie rouge
        return 0;
    }
    else
    {
        // Bougie bleue
        if (HA_ouverture[0] != HA_bas[0])
        {
            // Bougie bleue sans bas plat
            return 1;
        }
        else
        {
            // Bougie bleue avec bas plat
            if (HA_fermeture[0] - HA_ouverture[0] < parametreTaille)
            {
                // Petit corps
                return 3;
            }
            else
            {
                // Grand corps
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