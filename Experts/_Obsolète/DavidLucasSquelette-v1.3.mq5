//+------------------------------------------------------------------+
// Squelette de Robot de trading générique                           | 
// Version : 1.0                                                     |
//Notes de version :                                                 |
// * Basé sur DavidLucas-v1.0                                        |
// * v0.0 - 13/09/2024 - reprise du travail sur le robot             |
// * v1.0 - 29/09/24 mise en place du squelette d'algorithme complet
// * v1.1 - 09/10/2024 modifications sur la logique d'entrée et le calcul de la prochaine heure de test 
// * v1.2 - 23/10/2024 ajout de la logique de sortie de marché  
// * v1.3 - 28/10/2024 relecture avec David logique TP et SL         
// * v1.4 - 23/11/2024 ajout de la logique d'achat                  
// * v1.4.1 - 27/11/2024 journalisation pour tests                 | |
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Lucas Troncy - David Lhoyer"
#property version   "1.4"

//--- Appel aux fonctions exterieures
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

//--- Objets. ExtTrade sera utilisé pour passer les ordres d'achat et de vente
CTrade      ExtTrade;
CSymbolInfo ExtSymbolInfo;

//--- Expert ID
input long InpMagicNumber=100100;   // Numéro magique de l'Expert Advisor, fixé à 100100 arbitrairement
int fileHandle = INVALID_HANDLE; // Handle global du fichier
string fileName = "journal_personnalise.txt"; // Nom du fichier


//--- Paramètres d'heures de marché et de marché
input int InpHeureDebut=8;                 // Heure de début de trading en GMT
input int InpHeureFin=16;                  // Heure de fin de trading en GMT
//input string SymboleATrader = "USDEUR";   // Symbole à trader

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
input uint InpSL      =100;         // Stop Loss en points - doit être non nul !
input uint InpTP      =100;         // Take Profit en points
input uint InpSlippage=10;          // Slippage en points
input double InpLot   =0.1;         // Taille de lot

// Création des paramètres du Motif d'Entrée

   //--- Paramètres d'entrée RSI
   input int  InpPeriodRSI     =14;                      // Période moyenne du RSI
   input ENUM_APPLIED_PRICE InpPriceRSI=PRICE_WEIGHTED;  // RSI appliqué au prix pondéré
   input ENUM_TIMEFRAMES InpUT_RSI = PERIOD_M15;         // Période du RSI, réglée sur M15 par défaut
   input double RSIvaleur = 50;        // Valeur du RSI seuil pour exécuter l'entrée

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
    // Tester si InpSL <=0 => arrêter le robot

//+------------------------------------------------------------------+
//| Journalisation                                                   |
//+------------------------------------------------------------------+
// Supprimer et recréer le fichier en écrasant le contenu existant
   fileHandle = FileOpen(fileName, FILE_WRITE | FILE_TXT);
   if(fileHandle == INVALID_HANDLE)
     {
      PrintFormat("Erreur : Impossible d'ouvrir ou de créer le fichier '%s'. Code d'erreur : %d", fileName, GetLastError());
      return INIT_FAILED;
     }
   else
     {
      Print("Fichier de log recréé avec succès.");
     }

// Fermer immédiatement pour permettre un mode append dans les autres fonctions si nécessaire
   FileClose(fileHandle);

// Réouvrir le fichier en mode append (ajout de texte) si vous souhaitez continuer à écrire
   fileHandle = FileOpen(fileName, FILE_WRITE | FILE_TXT | FILE_READ);
   if(fileHandle == INVALID_HANDLE)
     {
      PrintFormat("Erreur : Impossible de réouvrir le fichier '%s' pour l'écriture en mode append. Code d'erreur : %d", fileName, GetLastError());
      return INIT_FAILED;
     }
   else
     {
      Print("Fichier de log prêt pour ajout de données.");
     }

   // Récupération du symbole négocié
   string symbol = Symbol();

   // Log du symbole
   LogToDesktop(StringFormat("L'expert est attaché au symbole : %s", symbol));







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
   MqlDateTime tm = {}; // Déclaration d'un objet de type MqlDateTime
   TimeToStruct(TimeCurrent(), tm); // Récupération de l'heure actuelle et remplissage de la structure tm

   // Vérifier si c'est un jour de la semaine et si l'heure est dans les heures d'ouverture
   if ((tm.day_of_week < 6 && tm.day_of_week > 0) && (tm.hour >= InpHeureDebut && tm.hour < InpHeureFin)) 
   {
       return true; 
   }
   return false;
}


//+------------------------------------------------------------------+
//| Fonction test entrée                                             |
//+------------------------------------------------------------------+

// Fonction pour tester les conditions d'entrée pour le trading basées sur les indicateurs Heiken Ashi et RSI
bool testEntree() {
    // Récupérer la couleur de la bougie Heiken Ashi long terme
    int couleurLongTerme = HAcouleur(ExtHandHeikenAshiUTL);
    if (couleurLongTerme < 0) {  // Gérer l'erreur potentielle de HAcouleur
        Print("Erreur lors de la récupération de la couleur Heiken Ashi");
        return false;
    }

    // Vérifier la condition RSI : bougie bleue (0) signifie RSI >= 50 ; bougie rouge (1) signifie RSI <= 50
    bool rsiCondition = (couleurLongTerme == 0) ? (RSI(0) >= 50) : (RSI(0) <= 50);
    
    // Récupérer les valeurs Heiken Ashi moyen terme et court terme
    int haConditionMedium = HAComposite(ExtHandHeikenAshiUTM, InpTaille_HAmoyen);
    int haConditionShort = HAComposite(ExtHandHeikenAshiUTC, InpTaille_HAcourt);

    // Définir la valeur requise basée sur la couleur de la bougie
    bool haRequired = (couleurLongTerme == 0);  // vrai pour long, faux pour court

    // Vérifier les conditions pour la bougie moyen terme et le RSI
    if (!(haConditionMedium == (haRequired ? 1 : -1) && rsiCondition)) {
        CalculateNextBarTime(g_next_check_time, InpUT_HA_Moyen);
        g_IND_ENTREE = E_NOT;
        return false;  // Conditions non remplies pour l'entrée
    }
    
    // Vérifier les conditions pour la bougie court terme et le DMI
    if (!(haConditionShort == (haRequired ? 1 : -1) && DMI() == 1)) {  // DMI devrait retourner 1 pour la confirmation de tendance
        CalculateNextBarTime(g_next_check_time, InpUT_HA_Court);
        g_IND_ENTREE = E_NOT;
        return false;  // Conditions non remplies pour l'entrée
    }

    // Mettre à jour l'indicateur d'entrée basé sur la couleur Heiken Ashi
    g_IND_ENTREE = haRequired ? E_LONG : E_SHORT;  // E_LONG si bleu, E_SHORT si rouge
    return true;  // Autoriser l'entrée en position
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
    ExtSymbolInfo.Refresh(); // Rafraîchir les informations du symbole
    ExtSymbolInfo.RefreshRates(); // Rafraîchir les taux de marché

    double price = 0; // Variable pour le prix d'achat ou de vente
    double stoploss = 0.0; // Variable pour le stop loss
    double takeprofit = 0.0; // Variable pour le take profit

    int digits = ExtSymbolInfo.Digits(); // Récupérer le nombre de décimales pour le symbole
    double point = ExtSymbolInfo.Point(); // Récupérer la valeur du point
    double spread = ExtSymbolInfo.Ask() - ExtSymbolInfo.Bid(); // Calculer l'écart entre le prix d'achat et le prix de vente

    // Déterminer si nous plaçons un ordre LONG ou SHORT
    for (int i = 0; i < 3; i++) // Boucle pour placer 3 lots identiques
    {
        if (g_IND_ENTREE == E_LONG) // Vérifier si l'indicateur d'entrée est LONG
        {
            price = NormalizeDouble(ExtSymbolInfo.Ask(), digits); // Normaliser le prix d'achat
            stoploss = CalculateStopLoss(price, spread, digits, InpSL, point); // Calculer le stop loss
            takeprofit = CalculateTakeProfit(price, spread, digits, InpTP, point); // Calculer le take profit

            if (!ExtTrade.Buy(InpLot, Symbol(), price, stoploss, takeprofit)) // Tenter d'acheter
            {
                LogTradeError("buy", price, stoploss, takeprofit); // Enregistrer l'erreur si l'achat échoue
                return false; // Retourner false si l'achat échoue
            }
            g_IND_POSITION = P_LONG; // Mettre à jour l'indicateur de position
        }
        else if (g_IND_ENTREE == E_SHORT) // Vérifier si l'indicateur d'entrée est SHORT
        {
            price = NormalizeDouble(ExtSymbolInfo.Bid(), digits); // Normaliser le prix de vente
            stoploss = CalculateStopLoss(price, spread, digits, InpSL, point, false); // Calculer le stop loss
            takeprofit = CalculateTakeProfit(price, spread, digits, InpTP, point, false); // Calculer le take profit

            if (!ExtTrade.Sell(InpLot, Symbol(), price, stoploss, takeprofit)) // Tenter de vendre
            {
                LogTradeError("sell", price, stoploss, takeprofit); // Enregistrer l'erreur si la vente échoue
                return false; // Retourner false si la vente échoue
            }
            g_IND_POSITION = P_SHORT; // Mettre à jour l'indicateur de position
        }
    }

    g_IND_ENTREE = E_NOT; // Réinitialiser l'indicateur d'entrée

    // Imprimer les valeurs des indicateurs
    PrintIndicators(); // Appeler la fonction pour imprimer les indicateurs
    return true; // Retourner true si l'ordre a été placé avec succès
}

//+------------------------------------------------------------------+
//| Fonction pour calculer le Stop Loss en fonction de la direction   |
//+------------------------------------------------------------------+
double CalculateStopLoss(double price, double spread, int digits, uint stopLossPoints, double point, bool isLong = true)
{
   double stoploss = 0;
   if (stopLossPoints > 0)
   {
      if (spread >= stopLossPoints * point)
      {
         PrintFormat("StopLoss (%d points) <= spread actuel = %.0f points. Utilisation de la valeur du spread", stopLossPoints, spread / point);
         stoploss = NormalizeDouble(isLong ? price - spread : price + spread, digits);
      }
      else
      {
         stoploss = NormalizeDouble(isLong ? price - stopLossPoints * point : price + stopLossPoints * point, digits);
      }
   }
   return stoploss;
}

//+------------------------------------------------------------------+
//| Fonction pour calculer le Take Profit en fonction de la direction |
//+------------------------------------------------------------------+
double CalculateTakeProfit(double price, double spread, int digits, uint takeProfitPoints, double point, bool isLong = true)
{
   double takeprofit = 0;
   if (takeProfitPoints > 0)
   {
      if (spread >= takeProfitPoints * point)
      {
         PrintFormat("TakeProfit (%d points) < spread actuel = %.0f points. Utilisation de la valeur du spread", takeProfitPoints, spread / point);
         takeprofit = NormalizeDouble(isLong ? price + spread : price - spread, digits);
      }
      else
      {
         takeprofit = NormalizeDouble(isLong ? price + takeProfitPoints * point : price - takeProfitPoints * point, digits);
      }
   }
   return takeprofit;
}

//+------------------------------------------------------------------+
//| Fonction pour enregistrer une erreur de trade                     |
//+------------------------------------------------------------------+
void LogTradeError(string type, double price, double stoploss, double takeprofit)
{
   PrintFormat("Échec de %s %s à %G (SL=%G TP=%G) échec. Prix actuel=%G erreur=%d", 
               type, Symbol(), price, stoploss, takeprofit, (type == "buy" ? ExtSymbolInfo.Ask() : ExtSymbolInfo.Bid()), GetLastError());
}

//+------------------------------------------------------------------+
//| Fonction pour imprimer les indicateurs                           |
//+------------------------------------------------------------------+
void PrintIndicators()
{
    Print("Indice long : ", HAComposite(ExtHandHeikenAshiUTL, InpTaille_HAlong));
    Print("Indice moyen : ", HAComposite(ExtHandHeikenAshiUTM, InpTaille_HAmoyen));
    Print("RSI : ", RSI(0));
    Print("Indice court : ", HAComposite(ExtHandHeikenAshiUTC, InpTaille_HAcourt));
    Print("DMI : ", DMI());
}
//+------------------------------------------------------------------+
//| Fonction pour calculer le temps d'ouverture de la prochaine barre |
//+------------------------------------------------------------------+
void CalculateNextBarTime(datetime &next_check_time, ENUM_TIMEFRAMES timeframe)
{
    // Valider le timeframe (en supposant que PeriodSeconds retourne 0 pour des timeframes invalides)
    int period_seconds = PeriodSeconds(timeframe);
    if (period_seconds <= 0)
    {
        Print("Timeframe invalide passé à CalculateNextBarTime");
        return;
    }

    // Utiliser TimeTradeServer pour une meilleure précision en cas de délai entre les ticks
    datetime current_time = TimeTradeServer();
    
    // Aligner le temps actuel au début de la bougie actuelle
    datetime next_bar_open = current_time - (current_time % period_seconds);
    
    // Calculer le temps d'ouverture de la prochaine bougie
    next_bar_open += period_seconds;

    // Mettre à jour le temps de vérification suivant
    next_check_time = next_bar_open;
}


//---------------------------------------------------------------------
// INDICATEURS
//---------------------------------------------------------------------


// Fonction pour récupérer la couleur de la bougie Heiken Ashi
int HAcouleur(int handleHA) {
    // Tableau pour stocker la propriété de couleur Heiken Ashi
    double HA_couleur[1];
    
    // Récupérer la propriété de couleur Heiken Ashi
    if (CopyBuffer(handleHA, 4, 0, 1, HA_couleur) < 0) {
        PrintFormat("Erreur lors de la récupération des valeurs de couleur Heiken Ashi, code %d", GetLastError());
        return -1;  // Indiquer une erreur
    }
    return (int)HA_couleur[0];  // Retourner la couleur comme int (0 ou 1)
}

// Fonction pour déterminer la valeur composite Heiken Ashi basée sur certaines propriétés
int HAComposite(int handleHA, double parametreTaille) {
    // Tableaux pour stocker les propriétés Heiken Ashi
    double HA_couleur[1], HA_haut[1], HA_bas[1], HA_ouverture[1], HA_fermeture[1];

    // Récupérer les propriétés Heiken Ashi
    if (CopyBuffer(handleHA, 0, 0, 1, HA_ouverture) < 0 ||
        CopyBuffer(handleHA, 1, 0, 1, HA_haut) < 0 ||
        CopyBuffer(handleHA, 2, 0, 1, HA_bas) < 0 ||
        CopyBuffer(handleHA, 3, 0, 1, HA_fermeture) < 0 ||
        CopyBuffer(handleHA, 4, 0, 1, HA_couleur) < 0) {
        PrintFormat("Erreur lors de la récupération des propriétés Heiken Ashi, code %d", GetLastError());
        return -2;  // Indiquer une erreur
    }
    
       LogToDesktop(StringFormat("HA_ouverture: %f, HA_haut: %f, HA_bas: %f, HA_fermeture: %f, HA_couleur: %f",
               HA_ouverture[0], HA_haut[0], HA_bas[0], HA_fermeture[0], HA_couleur[0]));
    
    
    // Déterminer la valeur de l'indicateur composite basée sur les propriétés de la bougie
    if (HA_couleur[0] == 0 && HA_ouverture[0] == HA_bas[0] && (HA_fermeture[0] - HA_ouverture[0]) >= parametreTaille) {
        return 1;  // Bougie bleue, grand corps, cul plat
    } else if (HA_couleur[0] == 1 && HA_ouverture[0] == HA_haut[0] && (HA_ouverture[0] - HA_fermeture[0]) >= parametreTaille) {
        return -1;  // Bougie rouge, grand corps, cul plat
    }
    return 0;  // Aucun motif valide trouvé
}

// Fonction pour récupérer la valeur RSI à un index spécifié
double RSI(int index) {
    double indicator_RSI_values[1];
    if (CopyBuffer(ExtIndicatorHandleRSI, 0, index, 1, indicator_RSI_values) < 0) {
        PrintFormat("Erreur lors de la récupération des valeurs RSI, code %d", GetLastError());
        return EMPTY_VALUE;  // Retourner EMPTY_VALUE en cas d'erreur
    }
    return indicator_RSI_values[0];  // Retourner la valeur RSI
}

// Fonction pour vérifier la tendance de l'indicateur Directional Movement Index (DMI)
int DMI() {
    double indicator_DMI_values_plus[4];
    double indicator_DMI_values_moins[4];
    
    // Récupérer les valeurs DMI pour les 4 dernières bougies
    if (CopyBuffer(ExtIndicatorHandleDMI, 1, 0, 4, indicator_DMI_values_plus) < 0 ||
        CopyBuffer(ExtIndicatorHandleDMI, 2, 0, 4, indicator_DMI_values_moins) < 0) {
        PrintFormat("Erreur lors de la récupération des valeurs DMI, code %d", GetLastError());
        return -1;  // Indiquer une erreur
    }

    // Vérifier si les 3 dernières bougies indiquent un changement de tendance du rouge vers le vert dans le DMI
    if (indicator_DMI_values_plus[3] < indicator_DMI_values_moins[3] &&
        indicator_DMI_values_plus[2] < indicator_DMI_values_moins[2] &&
        indicator_DMI_values_plus[1] < indicator_DMI_values_moins[1]) {
        // Vérifier si la bougie actuelle confirme le changement de tendance vers le vert
        if (indicator_DMI_values_plus[0] > indicator_DMI_values_moins[0]) {
            return 1;  // Changement de tendance confirmé
        }
    }
    return 0;  // Aucun changement de tendance détecté
}
  
//+------------------------------------------------------------------+
//| Journalisation                                                   |
//+------------------------------------------------------------------+
void LogToDesktop(const string &logMessage)
  {
   if(fileHandle == INVALID_HANDLE)
     {
      Print("Erreur : Le fichier de log n'est pas ouvert.");
      return;
     }

// Obtenir l'heure actuelle
   datetime currentTime = TimeCurrent();
   string timestamp = TimeToString(currentTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS);

// Écrire le message de log avec un horodatage
   FileWrite(fileHandle, "[" + timestamp + "] " + logMessage);

// Optionnel : Forcer l'écriture si nécessaire (peut impacter légèrement les performances)
   FileFlush(fileHandle);
  }
  
  