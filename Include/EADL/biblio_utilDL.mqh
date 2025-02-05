//+------------------------------------------------------------------+
//| Initialisation des variables de la bibliothèque utilDL           |
//+------------------------------------------------------------------+
int fileHandle = INVALID_HANDLE;       // Handle global du fichier
string fileName = "journal_personnalise.txt"; // Nom du fichier

//+------------------------------------------------------------------+
//| Initialisation des fonctions de la bibliothèque utilDL           |
//+------------------------------------------------------------------+
void biblio_utilDL_Init()
{
   // Tentative d'ouverture du fichier en mode écriture/lecture
   fileHandle = FileOpen(fileName, FILE_WRITE | FILE_TXT | FILE_READ);
   if (fileHandle == INVALID_HANDLE)
   {
      PrintFormat("Erreur : Impossible d'ouvrir ou de créer le fichier '%s'. Code d'erreur : %d", fileName, GetLastError());
      return; // Aucun retour INIT_FAILED car non pertinent dans ce contexte
   }
   Print("Fichier de log initialisé avec succès.");
}

//+------------------------------------------------------------------+
//| Désinitialisation de la bibliothèque utilDL                      |
//+------------------------------------------------------------------+
void biblio_utilDL_Deinit()
{
   if (fileHandle != INVALID_HANDLE)
   {
      FileClose(fileHandle);
      Print("Fichier de log fermé avec succès.");
   }
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

   // Écrire le message de log avec horodatage
   FileWrite(fileHandle, "[" + timestamp + "] " + logMessage);
   FileFlush(fileHandle); // Forcer l'écriture
}


//+------------------------------------------------------------------+
//| Calcul du minimum de 3 timeframes                                |
//+------------------------------------------------------------------+

ENUM_TIMEFRAMES MinTimeframe(ENUM_TIMEFRAMES tf1, ENUM_TIMEFRAMES tf2, ENUM_TIMEFRAMES tf3)
{
   // Initialiser le minimum avec la première valeur
   ENUM_TIMEFRAMES min_tf = tf1;

   // Comparer avec la deuxième valeur
   if(tf2 < min_tf)
      min_tf = tf2;

   // Comparer avec la troisième valeur
   if(tf3 < min_tf)
      min_tf = tf3;

   return min_tf; // Retourner le minimum
}

//+------------------------------------------------------------------+
//| Fonction pour vérifier la condition "Marché Ouvert"              |
//+------------------------------------------------------------------+
bool IsMarketOpen(int HeureDebut, int HeureFin)
  {
   MqlDateTime tm = {}; // Déclaration d'un objet de type MqlDateTime
   TimeToStruct(TimeCurrent(), tm); // Récupération de l'heure actuelle et remplissage de la structure tm

// Vérifier si c'est un jour de la semaine et si l'heure est dans les heures d'ouverture
   if((tm.day_of_week < 6 && tm.day_of_week > 0) && (tm.hour >= HeureDebut && tm.hour < HeureFin))
     {
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Fonction pour calculer le temps d'ouverture de la prochaine barre |
//+------------------------------------------------------------------+
void CalculateNextBarTime(datetime &next_check_time, ENUM_TIMEFRAMES timeframe)
  {
// Valider le timeframe (en supposant que PeriodSeconds retourne 0 pour des timeframes invalides)
   int period_seconds = PeriodSeconds(timeframe);
   if(period_seconds <= 0)
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