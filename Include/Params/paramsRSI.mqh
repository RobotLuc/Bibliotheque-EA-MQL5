//+------------------------------------------------------------------+
//|                 Gestion des Paramètres via CSV & SET            |
//|                   Modifié par Sélène pour Lucas                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Lucas Troncy"

input int Inp_MaxRSI = 2;  // Nombre dynamique de signaux RSI
input string ParamFile = "RSI_Config.csv";  // Fichier CSV des paramètres

struct RSI_Params
{
   ENUM_TIMEFRAMES timeframe;
   int period;
   ENUM_APPLIED_PRICE applied;
   bool usePattern0;
   bool usePattern1;
   bool usePattern2;
   bool usePattern3;
   bool usePattern4;
   bool usePattern5;
   int poidsMotif0;
   int poidsMotif1;
   int poidsMotif2;
   int poidsMotif3;
   int poidsMotif4;
   int poidsMotif5;
   double seuilSurVendu;
   double seuilSurAchete;
};

RSI_Params rsi_config[100]; // Tableau de taille maximale permettant d'adapter dynamiquement

//+------------------------------------------------------------------+
//| Fonction pour lire le fichier CSV et remplir les paramètres     |
//+------------------------------------------------------------------+
void LoadRSIParams()
{
   ResetLastError();
   string filePath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + ParamFile;
   Print("Chemin du fichier recherché : ", filePath);
   
   if (!FileIsExist(filePath))
   {
      Print("Fichier de paramètres non trouvé !");
      return;
   }

   int handle = FileOpen(filePath, FILE_READ | FILE_CSV, ';');
   if (handle == INVALID_HANDLE)
   {
      Print("Impossible d'ouvrir le fichier de paramètres ! Erreur : ", GetLastError());
      return;
   }

   // Ignorer la première ligne (titres des colonnes)
   FileReadString(handle);

   for (int i = 0; i < Inp_MaxRSI && i < 100; i++)
   {
      rsi_config[i].timeframe = (ENUM_TIMEFRAMES)FileReadInteger(handle);
      rsi_config[i].period = FileReadInteger(handle);
      rsi_config[i].applied = (ENUM_APPLIED_PRICE)FileReadInteger(handle);
      rsi_config[i].usePattern0 = FileReadInteger(handle);
      rsi_config[i].usePattern1 = FileReadInteger(handle);
      rsi_config[i].usePattern2 = FileReadInteger(handle);
      rsi_config[i].usePattern3 = FileReadInteger(handle);
      rsi_config[i].usePattern4 = FileReadInteger(handle);
      rsi_config[i].usePattern5 = FileReadInteger(handle);
      rsi_config[i].poidsMotif0 = FileReadInteger(handle);
      rsi_config[i].poidsMotif1 = FileReadInteger(handle);
      rsi_config[i].poidsMotif2 = FileReadInteger(handle);
      rsi_config[i].poidsMotif3 = FileReadInteger(handle);
      rsi_config[i].poidsMotif4 = FileReadInteger(handle);
      rsi_config[i].poidsMotif5 = FileReadInteger(handle);
      rsi_config[i].seuilSurVendu = FileReadDouble(handle);
      rsi_config[i].seuilSurAchete = FileReadDouble(handle);
   }

   FileClose(handle);
   Print("Paramètres RSI chargés avec succès depuis ", ParamFile);
}

//+------------------------------------------------------------------+
//| Fonction pour générer un fichier SET basé sur le CSV            |
//+------------------------------------------------------------------+
void SaveToSetFile()
{
   string setFile = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\RSI_Config.set";
   int handle = FileOpen(setFile, FILE_WRITE | FILE_CSV, ';');
   if (handle == INVALID_HANDLE)
   {
      Print("Erreur lors de la création du fichier SET !");
      return;
   }

   // Écriture des titres des colonnes dans le fichier SET
   FileWrite(handle, "Timeframe;Period;Applied;UsePattern0;UsePattern1;UsePattern2;UsePattern3;UsePattern4;UsePattern5;PoidsMotif0;PoidsMotif1;PoidsMotif2;PoidsMotif3;PoidsMotif4;PoidsMotif5;SeuilSurVendu;SeuilSurAchete");

   for (int i = 0; i < Inp_MaxRSI && i < 100; i++)
   {
      FileWrite(handle, rsi_config[i].timeframe, rsi_config[i].period, rsi_config[i].applied,
                rsi_config[i].usePattern0, rsi_config[i].usePattern1, rsi_config[i].usePattern2,
                rsi_config[i].usePattern3, rsi_config[i].usePattern4, rsi_config[i].usePattern5,
                rsi_config[i].poidsMotif0, rsi_config[i].poidsMotif1, rsi_config[i].poidsMotif2,
                rsi_config[i].poidsMotif3, rsi_config[i].poidsMotif4, rsi_config[i].poidsMotif5,
                rsi_config[i].seuilSurVendu, rsi_config[i].seuilSurAchete);
   }

   FileClose(handle);
   Print("Fichier ", setFile, " généré avec succès.");
}