//+---------------------------------------------------------------------------------------------------------------------------------+
// Squelette de Robot de trading générique                                                                                          |                                                                                                              |
//Notes de version :                                                                                                                |
// * Basé sur DavidLucas-v1.0                                                                                                       |
// * v0.0 - 13/09/2024 - reprise du travail sur le robot                                                                            |
// * v1.0 - 29/09/24 mise en place du squelette d'algorithme complet                                                                |
// * v1.1 - 09/10/2024 modifications sur la logique d'entrée et le calcul de la prochaine heure de test                             |
// * v1.2 - 23/10/2024 ajout de la logique de sortie de marché                                                                      |
// * v1.3 - 28/10/2024 relecture avec David logique TP et SL                                                                        |
// * v1.4 - 23/11/2024 ajout de la logique d'achat                                                                                  |
// * v1.5 - 23/11/2024 modification de la fonction de passage d'ordre avec cette fois 3 TP différents, 1 pour chaque ordre          |
// * v1.6 - 23/11/2024 fonction PlacerOrdre() corrigée car ne prenait pas le numéro des tickets                                     |
//+---------------------------------------------------------------------------------------------------------------------------------+
#property copyright "Copyright 2024, Lucas Troncy - David Lhoyer"
#property version   "1.6"

//--- Appel aux fonctions exterieures
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

//--- Objets. ExtTrade sera utilisé pour passer les ordres d'achat et de vente
CTrade      ExtTrade;
CSymbolInfo ExtSymbolInfo;

//+------------------------------------------------------------------+
//| Déclaration des variables gloables                               |
//+------------------------------------------------------------------+
// Les variables globales sont initialisées dans la fonction OnInit()

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

int g_IND_POSITION;                    // Indicateur d'existence de position'
int g_IND_ENTREE;                      // Indicateur de signal d'entrée
datetime g_next_check_time;            // Variable statique locale qui définit la prochaine heure d'exécution des détections de motif
ulong tickets[];                       // Tableau pour stocker les numéros de tickets des lots possédés
uint tpMultipliers[3]={1, 10, 10};     // Multiplicateurs pour différents take profits

// Journalisation
int fileHandle = INVALID_HANDLE; // Handle global du fichier
string fileName = "journal_personnalise.txt"; // Nom du fichier


//+------------------------------------------------------------------+
//| Déclaration des fonctions de gestion de position                 |
//+------------------------------------------------------------------+
// Ces fonctions doivent être déclarées ici car on va devoir déclarer un tableau de fonction pour gérer individuellement
// chaque position

// Définir un type pour une fonction retournant un bool
typedef bool (*ConditionSortieFunc)();

// Déclaration des prototypes de fonctions
bool ConditionSortie1();
bool ConditionSortie2();
bool ConditionSortie3();

// Déclaration du tableau de pointeurs vers des fonctions
ConditionSortieFunc tableauDeConditionsSortie[3];

//+------------------------------------------------------------------+
//| Déclaration et initialisation des variables d'input utilisateur  |
//+------------------------------------------------------------------+

//--- Expert ID
   input long InpMagicNumber=100100;   // Numéro magique de l'Expert Advisor, fixé à 100100 arbitrairement

//--- Paramètres d'heures de marché et de marché
   input int InpHeureDebut=8;                 // Heure de début de trading en GMT
   input int InpHeureFin=16;                  // Heure de fin de trading en GMT
//input string SymboleATrader = "USDEUR";   // Symbole à trader

//--- Paramètres de trading
   input uint InpSL      =100;         // Stop Loss en points - doit être non nul !
   input uint InpTP      =100;         // Take Profit en points
   input uint InpSlippage=10;          // Slippage en points
   input double InpLot   =1;         // Taille de lot
   input uint InpCliquet = 50;            // InpCliquet : écart en points entre le cours et le SL qui déclenche la modification du SL
   input uint InpPourcentCliquet = 50;  // InpPourcentCliquet : pourcentage du InpCliquet qui est ajouté au SL. Compris entre 0 et 100 

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
   input ENUM_TIMEFRAMES InpUT_HA_Long = PERIOD_M30;   // Période Heiken Ashi la plus longue
   input ENUM_TIMEFRAMES InpUT_HA_Moyen = PERIOD_M15; // Période Heiken Ashi intermédiaire
   input ENUM_TIMEFRAMES InpUT_HA_Court = PERIOD_M2;  // Période Heiken Ashi la plus courte

   input double   InpTaille_HAlong = 100; // Taille du corps de bougie sur UT long en points
   input double   InpTaille_HAmoyen = 80; // Taille du corps de bougie sur UT moyen en points
   input double   InpTaille_HAcourt = 80;  // Taille du corps de bougie sur UT court en points

// Création des paramètres du motif de sortie
   input ENUM_TIMEFRAMES InpMAPeriod = PERIOD_M15;  // Période de la moyenne mobile


//--- Initialisation des pointeurs d'indicateurs
   int    ExtIndicatorHandleRSI=INVALID_HANDLE;  // Pointeur de l'indicateur RSI
   int    ExtIndicatorHandleDMI=INVALID_HANDLE;  // Pointeur de l'indicateur DMI
   int    ExtHandHeikenAshiUTL=INVALID_HANDLE;  // Pointeur de l'indicateur Heiken Ashi UT Long
   int    ExtHandHeikenAshiUTC=INVALID_HANDLE;  // Pointeur de l'indicateur Heiken Ashi UT court
   int    ExtHandHeikenAshiUTM=INVALID_HANDLE;  // Pointeur de l'indicateur Heiken Ashi UT moyen
   int    ExtmaHandle=INVALID_HANDLE;              // Pointeur de l'indicateur de moyenne mobile 

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//+------------------------------------------------------------------+
//| Fonction d'initialisation de l'Expert Advisor                     |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Définition des paramètres pour l'objet CTrade
    ExtTrade.SetDeviationInPoints(InpSlippage);    // Slippage
    ExtTrade.SetExpertMagicNumber(InpMagicNumber); // Numéro magique de l'Expert Advisor
    ExtTrade.LogLevel(LOG_LEVEL_ERRORS);           // Niveau de logging

    //--- Initialisation des indicateurs : DMI, RSI, Heiken Ashi et moyenne mobile
    ExtIndicatorHandleRSI=iRSI(_Symbol, InpUT_RSI, InpPeriodRSI, InpPriceRSI);
    ExtIndicatorHandleDMI=iADX(_Symbol, InpUT_DMI, InpPeriodDMI);
    ExtHandHeikenAshiUTL=iCustom(_Symbol,InpUT_HA_Long,"\\Indicators\\Examples\\Heiken_Ashi");
    ExtHandHeikenAshiUTM=iCustom(_Symbol,InpUT_HA_Moyen,"\\Indicators\\Examples\\Heiken_Ashi");
    ExtHandHeikenAshiUTC=iCustom(_Symbol,InpUT_HA_Court,"\\Indicators\\Examples\\Heiken_Ashi");
    ExtmaHandle = iMA(NULL, 0, InpMAPeriod, 0, MODE_SMA, PRICE_CLOSE);

    // Vérifier toutes les initialisations dans un bloc conditionnel unique
    if (!(InpUT_HA_Long > InpUT_HA_Moyen && InpUT_HA_Moyen > InpUT_HA_Court) ||
       ExtIndicatorHandleRSI == INVALID_HANDLE ||
       ExtIndicatorHandleDMI == INVALID_HANDLE ||
       ExtHandHeikenAshiUTL == INVALID_HANDLE ||
       ExtHandHeikenAshiUTM == INVALID_HANDLE ||
       ExtHandHeikenAshiUTC == INVALID_HANDLE ||
       ExtmaHandle == INVALID_HANDLE ||
       InpPourcentCliquet >100) 
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
        if (ExtmaHandle == INVALID_HANDLE) 
        {
            Print("Erreur : Impossible d'initialiser la moyenne mobile.");
        }
        if (ExtHandHeikenAshiUTL == INVALID_HANDLE || ExtHandHeikenAshiUTM == INVALID_HANDLE || ExtHandHeikenAshiUTC == INVALID_HANDLE)
        {
            Print("Erreur à la création de l'indicateur Heiken Ashi");
        }
         if (InpPourcentCliquet>100)
        {
            Print("Le pourcentage du InpCliquet en points doit être entre 0 et 100");
        }             
        ExpertRemove(); // Supprimer l'Expert Advisor
        return INIT_FAILED; // Retourner un statut d'échec 
        }
//+------------------------------------------------------------------+
//| Initialisation des variables globales                            |
//+------------------------------------------------------------------+
   g_IND_POSITION =IND_POSITION::P_NOT;  // Initialisation : pas de position pour démarrer
   g_IND_ENTREE =IND_ENTREE::E_NOT;    // Initialisation : pas de signal d'entrée
   g_next_check_time = 0; // Variable statique locale qui définit la prochaine heure d'exécution des détections de motif
   ArrayResize(tickets, 0); // Initialisation explicite pour garantir un tableau des tickets vide
//+------------------------------------------------------------------+
//| Initialisation du tableau des conditions de sortie               |
//+------------------------------------------------------------------+
    tableauDeConditionsSortie[0] = ConditionSortie1;
    tableauDeConditionsSortie[1] = ConditionSortie2;
    tableauDeConditionsSortie[2] = ConditionSortie3;
//+------------------------------------------------------------------+
//| Journalisation                                                   |
//+------------------------------------------------------------------+
    // Supprimer et recréer le fichier en écrasant le contenu existant
    fileHandle = FileOpen(fileName, FILE_WRITE | FILE_TXT);
    if (fileHandle == INVALID_HANDLE)
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
    if (fileHandle == INVALID_HANDLE)
    {
        PrintFormat("Erreur : Impossible de réouvrir le fichier '%s' pour l'écriture en mode append. Code d'erreur : %d", fileName, GetLastError());
        return INIT_FAILED;
    }
    else
    {
        Print("Fichier de log prêt pour ajout de données.");
    }

// Fin de l'initialisation
    return(INIT_SUCCEEDED);
}
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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
    IndicatorRelease(ExtmaHandle);
    
    if (fileHandle != INVALID_HANDLE)
    {
        FileClose(fileHandle);
        Print("Fichier de log fermé avec succès.");
    }
}
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//+------------------------------------------------------------------+
//| Fonction de tick de l'Expert Advisor                               |
//+------------------------------------------------------------------+
void OnTick()
  {
     
   if (!IsMarketOpen()) 
      { 
         //LogToDesktop("Le marché est fermé");
         return;
      }
      
   if (TimeCurrent() < g_next_check_time) {return;}
   
   if (g_IND_POSITION == P_NOT) // S'il n'y a pas de position ouverte, on teste si on a le signal pour entrer sur le marché
     {
       if (!testEntree() || !validationEntree()) // S'il n'y a pas de signal ou bien qu'il n'y a pas de confirmation, on arrête
         {
            return;
         }                    
       else if (PlacerOrdre())
         {      
           return;
         }   // Si toutes les conditions sont remplies, placer l'ordre qui va bien
      }            
   else // S'il y a au moins une position ouverte, on teste pour savoir si on a une configuration de dénouement
      {
      CliquetStopLoss(); // Mettre à jour le SL
      AppelerConditionsSortie(); // Gérer les positions
      verifTickets(); // Vérifier s'il y a encore des tickets après l'appel des conditions de sortie et mettre à jour g_IND_POSITION le cas échéant 
      } 
  }
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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
        LogToDesktop("Erreur lors de la récupération de la couleur Heiken Ashi");
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
        
        string logMessage = StringFormat("Pas d'entrée moyen terme. Tendance principale : %s, RSI : %.2f, Indicateur HA Moyen : %s", 
        couleurLongTerme ? "Rouge" : "Bleue", RSI(0), (haConditionMedium==0) ? "Pas de tendance moyen terme" : ((haConditionMedium==1) ?"bougie bleue grand corps cul plat" : "bougie rouge grand corps cul plat"));
        
        LogToDesktop(logMessage);
        
        return false;  // Conditions non remplies pour l'entrée
    }
    
   // Vérifier les conditions pour la bougie court terme et le DMI
   if (!(haConditionShort == (haRequired ? 1 : -1) && DMI() == (haRequired ? 1 : -1))) {
      CalculateNextBarTime(g_next_check_time, InpUT_HA_Court);
      
      string logMessage = StringFormat("Condition moyen terme détectée, pas de condition court terme. Tendance principale : %s, Indicateur HA Moyen : %s, Indicateur HA Court : %s, DMI : %s", 
      couleurLongTerme ? "Rouge" : "Bleue", 
      (haConditionMedium==0) ? "Pas de tendance moyen terme" : ((haConditionMedium==1) ?"bougie bleue grand corps cul plat" : "bougie rouge grand corps cul plat"),
      (haConditionShort==0) ? "Pas de tendance court terme" : ((haConditionShort==1) ?"bougie bleue grand corps cul plat" : "bougie rouge grand corps cul plat"),
      (DMI()==0) ? "Pas de tendance DMI" : "tendance DMI");
            
      LogToDesktop(logMessage);
      
      g_IND_ENTREE = E_NOT;
      return false;  // Conditions non remplies pour l'entrée
   }
    // Mettre à jour l'indicateur d'entrée basé sur la couleur Heiken Ashi
    g_IND_ENTREE = haRequired ? E_LONG : E_SHORT;  // E_LONG si bleu, E_SHORT si rouge
    
    // string logMessage = StringFormat("Entrée sur le marché. Tendance principale : %s, Indicateur HA Moyen : %s, Indicateur HA Court : %s, DMI : %s", 
    //  couleurLongTerme ? "Rouge" : "Bleue", 
    //  (haConditionMedium==0) ? "Pas de tendance moyen terme" : ((haConditionMedium==1) ?"bougie bleue grand corps cul plat" : "bougie rouge grand corps cul plat"),
    //  (haConditionShort==0) ? "Pas de tendance court terme" : ((haConditionShort==1) ?"bougie bleue grand corps cul plat" : "bougie rouge grand corps cul plat"),
    //  (DMI()==0) ? "Pas de tendance DMI" : "tendance DMI");
            
      //LogToDesktop(logMessage);
    LogToDesktop("Entrée sur le marché.");
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
    ExtSymbolInfo.Refresh();      // Rafraîchir les informations du symbole
    ExtSymbolInfo.RefreshRates(); // Rafraîchir les taux de marché

    ArrayResize(tickets, 0); // Réinitialiser le tableau des tickets

    double price = 0;      // Variable pour le prix d'achat ou de vente
    double stoploss = 0.0; // Variable pour le stop loss
    double takeprofit = 0.0; // Variable pour le take profit

    int digits = ExtSymbolInfo.Digits();     // Récupérer le nombre de décimales pour le symbole
    double point = ExtSymbolInfo.Point();    // Récupérer la valeur du point
    double spread = ExtSymbolInfo.Ask() - ExtSymbolInfo.Bid(); // Calculer l'écart entre le prix d'achat et le prix de vente

    // Calculer les stop-loss et take-profits de base une seule fois
    if (g_IND_ENTREE == E_LONG)
    {
        price = NormalizeDouble(ExtSymbolInfo.Ask(), digits); // Prix d'achat normalisé
        stoploss = NormalizeDouble(price - InpSL * point, digits); // Calculer le stop loss
    }
    else if (g_IND_ENTREE == E_SHORT)
    {
        price = NormalizeDouble(ExtSymbolInfo.Bid(), digits); // Prix de vente normalisé
        stoploss = NormalizeDouble(price + InpSL * point, digits); // Calculer le stop loss
    }

    // Placer les trois ordres avec des take-profits différents
    for (int i = 0; i < 3; i++)
    {
        bool success = false; // Indicateur de succès pour chaque ordre
        ulong ticket = 0;     // Variable pour stocker le ticket de l'ordre

        if (g_IND_ENTREE == E_LONG) // Ordre LONG
        {
            takeprofit = NormalizeDouble(price + (InpTP * tpMultipliers[i]) * point, digits); // Take profit avec multiplicateur

            // Tenter d'acheter
            success = ExtTrade.Buy(InpLot, Symbol(), price, stoploss, takeprofit);

            if (success && ExtTrade.ResultRetcode() == TRADE_RETCODE_DONE)
            {
                ticket = ExtTrade.ResultOrder(); // Récupérer le ticket de l'ordre
            }
        }
        else if (g_IND_ENTREE == E_SHORT) // Ordre SHORT
        {
            takeprofit = NormalizeDouble(price - (InpTP * tpMultipliers[i]) * point, digits); // Take profit avec multiplicateur

            // Tenter de vendre
            success = ExtTrade.Sell(InpLot, Symbol(), price, stoploss, takeprofit);

            if (success && ExtTrade.ResultRetcode() == TRADE_RETCODE_DONE)
            {
                ticket = ExtTrade.ResultOrder(); // Récupérer le ticket de l'ordre
            }
        }

        // Vérifier si l'ordre a échoué
        if (ticket == 0)
        {
            LogTradeError(g_IND_ENTREE == E_LONG ? "buy" : "sell", price, stoploss, takeprofit);
            return false; // Retourner false si une transaction échoue
        }

        // Ajouter le ticket au tableau
        ArrayResize(tickets, ArraySize(tickets) + 1);
        tickets[ArraySize(tickets) - 1] = ticket;
    }

    // Mettre à jour l'indicateur de position
    g_IND_POSITION = (g_IND_ENTREE == E_LONG) ? P_LONG : P_SHORT;
    g_IND_ENTREE = E_NOT; // Réinitialiser l'indicateur d'entrée

    // Log des tickets
    string output = "Tickets : [";
    for (int i = 0; i < ArraySize(tickets); i++)
    {
        output += IntegerToString(tickets[i]); // Convertir chaque élément en chaîne
        if (i < ArraySize(tickets) - 1) output += ", "; // Ajouter une virgule entre les éléments
    }
    output += "]";

    LogToDesktop(output);   
    LogToDesktop(StringFormat("Ordre placé. g_IND_POSITION : %d", g_IND_POSITION));

    return true; // Retourner true si tous les ordres ont été placés avec succès
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
   string logmessage = StringFormat("Échec de %s %s à %G (SL=%G TP=%G) échec. Prix actuel=%G erreur=%d", 
               type, Symbol(), price, stoploss, takeprofit, (type == "buy" ? ExtSymbolInfo.Ask() : ExtSymbolInfo.Bid()), GetLastError());
   LogToDesktop(logmessage);
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
//+------------------------------------------------------------------+
//| Fonction pour effet Cliquet sur le stop loss                     |
//+------------------------------------------------------------------+
void CliquetStopLoss()
{
    // Vérifier si le tableau tickets[] contient des positions
    if (ArraySize(tickets) == 0)
    {
        Print("Le tableau tickets est vide.");
        return;
    }

    // Parcourir chaque ticket dans le tableau tickets[]
    for (int i = 0; i < ArraySize(tickets); i++)
    {
        ulong ticket = tickets[i];

        // Vérifiez si la position existe pour ce ticket
        if (!PositionSelectByTicket(ticket))
        {
            Print("La position avec le ticket ", ticket, " n'existe pas ou a déjà été clôturée.");
            continue;  // Passer au ticket suivant si la position n'existe plus
        }

        // Récupérer les informations de la position
        double currentPrice = SymbolInfoDouble(Symbol(), (g_IND_POSITION == P_LONG) ? SYMBOL_BID : SYMBOL_ASK); // Prix en fonction du type (long/short)
        double currentStopLoss = PositionGetDouble(POSITION_SL); // Stop loss actuel
        double volume = PositionGetDouble(POSITION_VOLUME); // Volume de la position

        // Calculer la différence entre le cours actuel et le stop loss
        double ecart = (g_IND_POSITION == P_LONG) 
            ? currentPrice - currentStopLoss  // Pour une position longue
            : currentStopLoss - currentPrice; // Pour une position courte

        // Vérifiez si l'écart est supérieur à la valeur minimale définie (g_ecart)
        if (ecart > InpCliquet * SymbolInfoDouble(Symbol(), SYMBOL_POINT))
        {
            // Calculer le nouveau stop loss
            double nouveauStopLoss = (g_IND_POSITION == P_LONG)
                ? (currentStopLoss + ecart) * InpPourcentCliquet / 100  // Ajustement pour une position longue
                : (currentStopLoss - ecart) * InpPourcentCliquet / 100; // Ajustement pour une position courte

            // Normalisez le stop loss pour respecter les décimales du symbole
            nouveauStopLoss = NormalizeDouble(nouveauStopLoss, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));

            // Modifier le stop loss
            if (!ExtTrade.PositionModify(ticket, nouveauStopLoss, PositionGetDouble(POSITION_TP)))
            {
                Print("Erreur lors de la modification du stop loss pour le ticket ", ticket);
            }
            else
            {
                Print("Stop loss modifié pour le ticket ", ticket, " : ", nouveauStopLoss);
            }
        }
        else
        {
            Print("Écart insuffisant pour modifier le stop loss pour le ticket ", ticket);
        }
    }
}
//+------------------------------------------------------------------+
//| Fonction de vérification de l'existance de tickets               |
//+------------------------------------------------------------------+
void verifTickets()
{
   if (!(PositionSelectByTicket(tickets[0]) || PositionSelectByTicket(tickets[1]) || PositionSelectByTicket(tickets[2])))
      {
         g_IND_POSITION = P_NOT;   
      }
}
//+------------------------------------------------------------------+
//| Fonction de gestion des positions                                |
//+------------------------------------------------------------------+
// Fonction qui boucle sur le tableau contenant les fonctions de conditions de sortie et qui appelle chaque fonction
void AppelerConditionsSortie()
{
   if (g_IND_POSITION == P_NOT) 
      {
         return;
      }
    // Boucle pour traiter chaque ticket et condition de sortie
    for (int i = 0; i < ArraySize(tableauDeConditionsSortie); i++)
       {
       // Vérifier si une position est associée au ticket courant
       if (PositionSelectByTicket(tickets[i]))
          {
             // Vérifier si la condition de sortie est remplie pour ce ticket
             if (tableauDeConditionsSortie[i]())
                {
                   // Tentative de clôture de la position
                   if (!ExtTrade.PositionClose(tickets[i]))
                      {
                          Print("Erreur lors de la clôture de la position pour le ticket ", tickets[i]);
                       }
                   else
                      {
                          Print("Position avec le ticket ", tickets[i], " clôturée avec succès.");
                      }
                }
          }
       else
          {
             Print("La position avec le ticket ", tickets[i], " est déjà clôturée ou inexistante.");
          }
         }
    // Si aucune condition remplie, mettre à jour g_next_check_time.
}
//+------------------------------------------------------------------+
//| Conditions de sortie                                             |
//+------------------------------------------------------------------+
bool ConditionSortie1()
{
    // Le ticket numéro 1 est toujours géré par le SL, donc cette fonction est juste pour mémoire
    return false;
}

bool ConditionSortie2()
{
// Cette condition de sortie est atteinte sur le deuxième ticket si le DMI change de tendance.
   if (((g_IND_POSITION == P_LONG) && DMI_Sortie() == 1) || ((g_IND_POSITION == P_SHORT) && DMI_Sortie() == -1))
      {
         return true;
      }
    else return false; // Retourner faux si la condition de sortie n'est pas atteinte
}

bool ConditionSortie3()
{
// Cette condition de sortie est atteinte sur le troisième ticket si la moyenne mobile croise le prix à la hausse ou la baisse
   if (((g_IND_POSITION == P_LONG) && CrossMovingAverage() == 1) || ((g_IND_POSITION == P_SHORT) && CrossMovingAverage() == -1))
      {
         return true;
      }
    else return false; // Retourner faux si la condition de sortie n'est pas atteinte
}
//+------------------------------------------------------------------+
//| Journalisation                                                   |
//+------------------------------------------------------------------+
void LogToDesktop(const string &logMessage)
{
    if (fileHandle == INVALID_HANDLE)
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

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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
    double point = ExtSymbolInfo.Point(); // Récupérer la valeur du point
    

// Récupérer les propriétés Heiken Ashi
    if (CopyBuffer(handleHA, 0, 0, 1, HA_ouverture) < 0 ||
        CopyBuffer(handleHA, 1, 0, 1, HA_haut) < 0 ||
        CopyBuffer(handleHA, 2, 0, 1, HA_bas) < 0 ||
        CopyBuffer(handleHA, 3, 0, 1, HA_fermeture) < 0 ||
        CopyBuffer(handleHA, 4, 0, 1, HA_couleur) < 0) {
        PrintFormat("Erreur lors de la récupération des propriétés Heiken Ashi, code %d", GetLastError());
        return -2;  // Indiquer une erreur
    }
// Déterminer la valeur de l'indicateur composite basée sur les propriétés de la bougie
    if (HA_couleur[0] == 0 && HA_ouverture[0] == HA_bas[0] && (HA_fermeture[0] - HA_ouverture[0]) >= parametreTaille*point) {
        return 1;  // Bougie bleue, grand corps, cul plat
    } else if (HA_couleur[0] == 1 && HA_ouverture[0] == HA_haut[0] && (HA_ouverture[0] - HA_fermeture[0]) >= parametreTaille*point) {
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

    // Vérifier si l'indicateur DMI est valide
    if (ExtIndicatorHandleDMI == INVALID_HANDLE) {
        Print("Erreur : L'indicateur DMI n'est pas valide.");
        return -1000;  // Retourner -1000 en cas d'erreur d'indicateur
    }
    // Récupérer les valeurs DMI pour les 4 dernières bougies
    int copiedPlus = CopyBuffer(ExtIndicatorHandleDMI, 1, 0, 4, indicator_DMI_values_plus);
    int copiedMinus = CopyBuffer(ExtIndicatorHandleDMI, 2, 0, 4, indicator_DMI_values_moins);
    
    if (copiedPlus < 0 || copiedMinus < 0) {
        PrintFormat("Erreur lors de la récupération des valeurs DMI, code %d", GetLastError());
        return -1000;  // Retourner -1000 si la récupération échoue
    }
    // Vérification d'une tendance haussière :
    // Les trois dernières bougies doivent indiquer un -DI supérieur à +DI,
    // et la dernière bougie (indice 0) doit avoir un +DI supérieur à -DI
    if (indicator_DMI_values_plus[3] < indicator_DMI_values_moins[3] &&
        indicator_DMI_values_plus[2] < indicator_DMI_values_moins[2] &&
        indicator_DMI_values_plus[1] < indicator_DMI_values_moins[1]) {
        // La dernière bougie (indice 0) confirme la tendance haussière
        if (indicator_DMI_values_plus[0] > indicator_DMI_values_moins[0]) {
            return 1;  // Tendance haussière
        }
    }
    // Vérification d'une tendance baissière :
    // Les trois dernières bougies doivent indiquer un +DI supérieur à -DI,
    // et la dernière bougie (indice 0) doit avoir un -DI supérieur à +DI
    if (indicator_DMI_values_plus[3] > indicator_DMI_values_moins[3] &&
        indicator_DMI_values_plus[2] > indicator_DMI_values_moins[2] &&
        indicator_DMI_values_plus[1] > indicator_DMI_values_moins[1]) {
        // La dernière bougie (indice 0) confirme la tendance baissière
        if (indicator_DMI_values_plus[0] < indicator_DMI_values_moins[0]) {
            return -1;  // Tendance baissière
        }
    }
    // Absence de tendance clairement définie
    return 0;  // Absence de tendance
}

// Fonction DMI_Sortie() qui vérifie la relation entre +DI et -DI sur la dernière bougie
int DMI_Sortie() {
    double indicator_DMI_values_plus[1];  // Tableau pour stocker les valeurs de +DI
    double indicator_DMI_values_moins[1]; // Tableau pour stocker les valeurs de -DI
    
    // Vérifier si l'indicateur DMI est valide
    if (ExtIndicatorHandleDMI == INVALID_HANDLE) {
        Print("Erreur : L'indicateur DMI n'est pas valide.");
        return -1000;  // Retourner -1000 en cas d'erreur d'indicateur
    }

    // Récupérer les valeurs DMI pour la dernière bougie (indice 0)
    int copiedPlus = CopyBuffer(ExtIndicatorHandleDMI, 1, 0, 1, indicator_DMI_values_plus);
    int copiedMinus = CopyBuffer(ExtIndicatorHandleDMI, 2, 0, 1, indicator_DMI_values_moins);
    
    if (copiedPlus < 0 || copiedMinus < 0) {
        PrintFormat("Erreur lors de la récupération des valeurs DMI, code %d", GetLastError());
        return -1000;  // Retourner -1000 si la récupération échoue
    }

    // Vérifier la relation entre +DI et -DI sur la dernière bougie
    if (indicator_DMI_values_plus[0] > indicator_DMI_values_moins[0]) {
        return 1;  // +DI > -DI
    }
    else if (indicator_DMI_values_plus[0] < indicator_DMI_values_moins[0]) {
        return -1; // +DI < -DI
    }
    else {
        return 0;  // +DI == -DI
    }
}

// Indicateur de croisement de moyenne mobile avec le cours         
int CrossMovingAverage() {
// Variables pour stocker les valeurs
    double maValues[2];  // Moyenne mobile sur les 2 dernières bougies
    double currentPrice, previousPrice;
// Récupération des valeurs de la moyenne mobile
    // Récupération des valeurs de la moyenne mobile
    if (CopyBuffer(ExtmaHandle, 0, 0, 2, maValues) < 0) {
        PrintFormat("Erreur lors de la récupération des valeurs de la moyenne mobile, code %d", GetLastError());
        return -1000;  // Retourner -1000 en cas d'erreur
    }

    // Récupération des cours
    currentPrice = iClose(NULL, 0, 0);  // Cours actuel
    previousPrice = iClose(NULL, 0, 1); // Cours précédent

    // Vérification des croisements
    if (maValues[1] < previousPrice && maValues[0] > currentPrice) {
        return 1;  // Croisement haussier
    }
    if (maValues[1] > previousPrice && maValues[0] < currentPrice) {
        return -1;  // Croisement baissier
    }

    return 0;  // Aucun croisement détecté
}