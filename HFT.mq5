//+------------------------------------------------------------------+
//| ATENÇÃO TIME MASTERMIND:                                         |
//| 1) Antes de fazer qualquer alteração, avise aos demais do time,  |
//|    para evitar termos mais de uma pessoa trabalhando no mesmo    |
//|    código e consequente encavalamento de versões.                |
//| 2) Antes de começar a alteração, certifique-se de estar com a    |
//|    versão mais recente fazendo um "Update from Storage"          |
//|    ("Obter atualização do repositório").                         |
//| 3) Depois de terminada a alteração, grave sua versão fazendo um  |
//|    "Commit to Storage" ("Enviar alterações para o repositório"), |
//|    e avise aos demais do time.                                   |
//| 4) DOCUMENTE suas alterações no log abaixo, e utilize o ID do    |
//|    log nos comentários de cada alteração ao código               |
//+------------------------------------------------------------------+
//| LOG MASTERMIND                                                   |
//+------------------------------------------------------------------+
//|Data      |Usuário|ID  |Descrição                                 |
//+------------------------------------------------------------------+
//|13.06.2023|Rogerio|0001|Versão inicial enviada por Marcio         |
//|13.06.2023|Klayton|0002|Cópia da EstruturaOrdens para compilar    |
//|14.06.2023|Rogerio|0003|Adicionei este cabeçalho                  |
//|15.11.2023|Rogerio|0004|Novo arquivo CSV                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                          HFT.mq5 |
//|                                        Copyright 2021,MathTechBr |
//|                                             mathtechbr@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021,MathTechBr"
#property link      "mathtechbr@gmail.com"
#property version   "1.00"
#property description "Order Imbalance Based Strategy"

//+------------------------------------------------------------------+
//| INCLUDES/RESOURCES                                               |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <MathTechBr\MathTechBr.mqh>

//+------------------------------------------------------------------+
//| ENUM                                                             |
//+------------------------------------------------------------------+
enum ENUM_TIPO_LEITURA {
  POR_TICK,    // By price change
  POR_TIMER,   // By time interval
  POR_BOOK     // By BOOK change
};

enum ENUM_LAGS {
  LAG0 = 4,
  LAG1 = 6,
  LAG2 = 8,
  LAG3 = 10,
  LAG4 = 12,
  LAG5 = 14
};

//+------------------------------------------------------------------+
//| STRUCTS                                                          |
//+------------------------------------------------------------------+
struct EstruturaLeitura {
  double PrecoCompra;
  double PrecoVenda;
  long   QuantidadeCompra;
  long   QuantidadeVenda;
  double EquacaoM;
  double VolumeDia;
  double VolumeNegociado;
  long   DVAsk;
  long   DVBid;
  long   OI;
  double M;
  double DM;
  double OIR;
  double TP;
  double R;
  double S;
};

struct EstruturaVolume {
  double Ticks;
  double Contratos;
  double Financeiro;
  double VWAP;
};

//--- Klayton0002 Início da Inclusão
struct EstruturaOrdens
   {
   int    QuantidadeTotal;
   int    OperacoesEmAndamento;
   int    ComprasEmAndamento;
   int    VendasEmAndamento;
   double OffSet;
   double SaldoFinanceiro;
   double MaiorSaldo;
   double MenorSaldo;
   double TotalGain;
   double TotalLoss;  
   int    OperacoesGain;
   int    OperacoesLoss;
   int    SequenciaGain;
   int    SequenciaLoss;
   };
//--- Klayton0002 Fim da Inclusão
   
//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group              "CONFIGURATION"
input ulong              InpMagicNumber=0;            // Magic Number of robot (zero = automatic)
input string             InpSymbol="";                // Symbol for trading (if different from the chart)
input ENUM_TIPO_LEITURA  InpTipoLeitura=POR_TIMER;    // Type of data reading
input uint               InpMilissegundos=500;        // Time between reads per time interval (milliseconds)
input double             InpEFPC=0.35;                // EFPC
input int                InpLag=5;                    // LAG
input double             InpForecast=0.0;             // Forecast
input bool               InpLog=false;                // Generate logs
input group              "TIME OPERATION"
input uint               InpInitialHour=9;            // Initial hour operation
input uint               InpInitialMinute=5;          // Initial minute operation
input uint               InpFinalHour=17;             // Final hour operation
input uint               InpFinalMinute=30;           // Final minute operation
input group              "PERFORMANCE"
input double             InpTakeProfit=0;             // Points for Take Profit (zero = no TP)
input double             InpStopLoss=0;               // Points for Stop Loss (zero = no SL)
input double             InpVolume=1;                 // Volume operation
input double             InpDailyLoss=0;              // Daily loss limit (zero = no limit)
input double             InpDailyProfit=0;            // Daily profit limit (zero = no limit)

//+------------------------------------------------------------------+
//| GLOBALS                                                          |
//+------------------------------------------------------------------+
bool leilao;
datetime day_operation = 0;
datetime initial_time_operation;
datetime final_time_operation;
int handle_log = INVALID_HANDLE;
int handle_tmp = INVALID_HANDLE;
int NewFileHandle = INVALID_HANDLE; // Rogerio004

ulong magic_number;
string symbol_operation;
string hora_log = "";

EstruturaLeitura  Leitura[6];
EstruturaVolume   Volume;
EstruturaOrdens   Ordens; // Klayton002 Incluído

double            EFPC;
double            Coeficiente[14];
double            CalculoCoeficiente[14];
int               ContadorLeitura = 0;

//--- Posições no array conforme LAG
int lag0[LAG0] = {0,1,7,13};
int lag1[LAG1] = {0,1,2,7,8,13};
int lag2[LAG2] = {0,1,2,3,7,8,9,13};
int lag3[LAG3] = {0,1,2,3,4,7,8,9,10,13};
int lag4[LAG4] = {0,1,2,3,4,5,7,8,9,10,11,13};
int lag5[LAG5] = {0,1,2,3,4,5,6,7,8,9,10,11,12,13};


CTrade trade;
MqlTick tick;
POSITIONS_AND_ORDERS position;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
  if (!CheckInputErrors()) {
    return INIT_PARAMETERS_INCORRECT;
  }

  if (!InitializeIndicators()) {
    return INIT_FAILED;
  }

  if (!EventSetMillisecondTimer(InpMilissegundos)) {
    Print("Error on EventSetMillisecondTimer(): "+string(GetLastError()));
    return INIT_FAILED;
  }

  trade.SetExpertMagicNumber(magic_number);
  robot_name = "HFT";
  button_pause = "ButtonPause"+string(magic_number);
  button_stop  = "ButtonStop"+string(magic_number);
  GetPositionAndOrders(position);

  ChartSetInteger(0,CHART_SHOW_PERIOD_SEP,true);
  ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,clrLime);
  ChartSetInteger(0,CHART_COLOR_CHART_UP, clrLime);
  ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,clrRed);
  ChartSetInteger(0,CHART_COLOR_CHART_DOWN, clrRed);

  // BEGIN Rogerio004
  if (IsNewDay()) {
    InicioNovoDia();
  }
  // END Rogerio004
  
  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
  EventKillTimer();
  MarketBookRelease(_Symbol);
  
  FileClose(handle_tmp);
  
  // Rogerio0004 BEGIN
  ResetLastError();
  FileClose(NewFileHandle);
  Print("Arquivo CSV fechado");
  // Rogerio0004 END

  DeleteProfit();
}

//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade() {
  if (InpLog) {
    hora_log = PegaHorario(false);
    GetPositionAndOrders(position);
    
    SalvaLog2("Summary of operations:", hora_log);
    SalvaLog2("Buy in progress................. " + (string)Ordens.ComprasEmAndamento, hora_log);
    SalvaLog2("Sell in progress................ " + (string)Ordens.VendasEmAndamento, hora_log);
    if (Ordens.ComprasEmAndamento + Ordens.VendasEmAndamento > 0) {
      SalvaLog2("Last operation price............ " + DoubleToString(position.price, _Digits), hora_log);
    }
    SalvaLog2("Operations finalized profit..... " + (string)Ordens.OperacoesGain + " (" + DoubleToString((double)Ordens.OperacoesGain / (double)Ordens.QuantidadeTotal * 100, 1) + " %)", hora_log);
    SalvaLog2("Operations finalized loss....... " + (string)Ordens.OperacoesLoss + " (" + DoubleToString((double)Ordens.OperacoesLoss / (double)Ordens.QuantidadeTotal * 100, 1) + " %)", hora_log);
    SalvaLog2("Total operations................ " + (string)Ordens.QuantidadeTotal, hora_log);
    SalvaLog2("Higher profit sequence.......... " + (string)Ordens.SequenciaGain + " operations", hora_log);
    SalvaLog2("Higher loss sequence............ " + (string)Ordens.SequenciaLoss + " operations", hora_log);
    SalvaLog2("Gross profit.................... " + (string)Ordens.TotalGain, hora_log);
    SalvaLog2("Gross loss...................... " + (string)Ordens.TotalLoss, hora_log);
    SalvaLog2(" ", hora_log);
    SalvaLog2("Lowest balance on day........... " + (string)Ordens.MenorSaldo, hora_log);
    SalvaLog2("Highest balance on day.......... " + (string)Ordens.MaiorSaldo, hora_log);
    SalvaLog2("Financial balance............... " + (string)Ordens.SaldoFinanceiro, hora_log);
    SalvaLog2(" ", hora_log);
  }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam) {
  if(id==CHARTEVENT_OBJECT_CLICK) {
    if(sparam==button_stop && !position.stopped) {
      if (!CloseOperations()) {
        Print("Error closing operations: "+(string)GetLastError()+" - ID EA: "+string(magic_number));
      }
      if (!DeleteOrders()) {
        Print("Error deleting orders: "+(string)GetLastError()+" - ID EA: "+string(magic_number));
      }
      position.stopped = true;
      GetPositionAndOrders(position);
      Print("Operations stopped!!!!");
    }

    if(sparam==button_pause && !position.stopped) {
      position.paused = !position.paused;
      if (position.paused)
        Print("Operations paused!!!!");
      else 
        Print("Operations resumed!!!!");
    }
  }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
  if (!SymbolInfoTick(symbol_operation, tick)) {
    Print("Fatal error get SymbolInfoTick - ID EA: "+string(magic_number));
    return;
  }

  if (IsNewDay()) {
    InicioNovoDia();
  }


  // verifica se houve um negocio realizado ou se apenas houve mudança de valores/volumes sem nenhum negocio ter sido realizado
  // MUDANÇA TEMPORÁRIA Rogerio004. Porque ao menos em testes, todos os flags são 30 (Volume)
  //bool NegocioRealizado = (tick.flags & TICK_FLAG_BUY) + (tick.flags & TICK_FLAG_SELL) > 0;
  bool NegocioRealizado = (tick.flags & TICK_FLAG_VOLUME) == TICK_FLAG_VOLUME;

  // processa volumes somente em caso de negócio fechado no book
  if (NegocioRealizado) {
    // calcula volumes
    Volume.Ticks      += 1;
    Volume.Contratos  += (double)tick.volume;
    Volume.Financeiro += tick.last * tick.volume;
    Volume.VWAP        = Volume.Financeiro / Volume.Contratos;
  }
  
  leilao = tick.volume == 0;
  
  if (!TimeAllowed(initial_time_operation, final_time_operation)) {
    return;
  }
      
  if (InpTipoLeitura == POR_TICK) {
    ProcessaDados();
  }
    
  // abre posições somente se dia já iniciou
  if (Volume.Ticks == 0 || Leitura[0].S == 0 || position.limit_reached || position.paused || position.stopped) {
    return;
  }
  
  // calcula o EFPC
  CalculoCoeficiente[ 0] = Coeficiente[ 0];  //0,001 == 10-³
  CalculoCoeficiente[ 1] = Coeficiente[ 1] * Leitura[0].OI / Leitura[0].S;
  CalculoCoeficiente[ 2] = Coeficiente[ 2] * Leitura[1].OI / Leitura[0].S;
  CalculoCoeficiente[ 3] = Coeficiente[ 3] * Leitura[2].OI / Leitura[0].S;
  CalculoCoeficiente[ 4] = Coeficiente[ 4] * Leitura[3].OI / Leitura[0].S;
  CalculoCoeficiente[ 5] = Coeficiente[ 5] * Leitura[4].OI / Leitura[0].S;
  CalculoCoeficiente[ 6] = Coeficiente[ 6] * Leitura[5].OI / Leitura[0].S;
  CalculoCoeficiente[ 7] = Coeficiente[ 7] * Leitura[0].OIR / Leitura[0].S;
  CalculoCoeficiente[ 8] = Coeficiente[ 8] * Leitura[1].OIR / Leitura[0].S;
  CalculoCoeficiente[ 9] = Coeficiente[ 9] * Leitura[2].OIR / Leitura[0].S;
  CalculoCoeficiente[10] = Coeficiente[10] * Leitura[3].OIR / Leitura[0].S;
  CalculoCoeficiente[11] = Coeficiente[11] * Leitura[4].OIR / Leitura[0].S;
  CalculoCoeficiente[12] = Coeficiente[12] * Leitura[5].OIR / Leitura[0].S;
  CalculoCoeficiente[13] = Coeficiente[13] * Leitura[0].R / Leitura[0].S;  
  
  EFPC = 0;
  for (int i=0 ; i<=13 ; i++) {
    EFPC += CalculoCoeficiente[i];
  }
  
  // coeficientes sinalizaram compra
  if (EFPC >= InpEFPC) {
    SalvaLog("Sign to buy at EFPC: " + (string)EFPC);
    Buy();
    // "EFPC;BID;ASK;Last"
    FileWrite(handle_tmp,DoubleToString(EFPC,6)+";"
                        +DoubleToString(tick.bid,_Digits)+";"
                        +DoubleToString(tick.ask,_Digits)+";"
                        +DoubleToString(tick.last,_Digits));
  } else {
    // coeficientes sinalizaram venda
    if (EFPC <= -InpEFPC) {
      SalvaLog("Sign to sell at EFPC: " + (string)EFPC);
      Sell();
      // "EFPC;BID;ASK;Last"
      FileWrite(handle_tmp,DoubleToString(EFPC,6)+";"
                          +DoubleToString(tick.bid,_Digits)+";"
                          +DoubleToString(tick.ask,_Digits)+";"
                          +DoubleToString(tick.last,_Digits));
    }
  }
  
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
  if (InpTipoLeitura == POR_TIMER)
    {
     ProcessaDados();
     GeraNovoArquivo(); // Rogerio004
    }
}

//+------------------------------------------------------------------+
//| BookEvent function                                               |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol) {
  if (InpTipoLeitura == POR_BOOK)
    ProcessaDados();
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| PROCESS LOGIC                                                    |
//+------------------------------------------------------------------+
void ProcessaDados() {
  if (IsStopped() || position.stopped) {
    return;
  }

  // Início Rogerio Szterling
  if(!TimeAllowed(initial_time_operation,final_time_operation)) return;
  // Fim Rogerio Szterling

  if (position.paused) {
    static datetime time_paused = 0;
    TimedMessage(time_paused,"Operations paused!", magic_number, 60);
    return;
  }
  
  if (!GetPositionAndOrders(position)) {
    Print("Error getting Positions And Orders: "+(string)GetLastError()+" - ID EA: "+string(magic_number));
    return;
  }

  if (!position.limit_reached) {
    double local_profit = position.profit;
    if (InpDailyLoss > 0 && local_profit < 0 && MathAbs(local_profit) > InpDailyLoss) {
      Print("Daily limit loss reached - ID EA: "+string(magic_number));
      position.limit_reached = true;
    }

    if (InpDailyProfit > 0 && local_profit > InpDailyProfit) {
      Print("Daily limit profit reached - ID EA: "+string(magic_number));
      position.limit_reached = true;
    }

    if (position.limit_reached) {
      if (!CloseOperations()) {
        Print("Error closing operations: "+(string)GetLastError()+" - ID EA: "+string(magic_number));
      }
      if (!DeleteOrders()) {
        Print("Error deleting orders: "+(string)GetLastError()+" - ID EA: "+string(magic_number));
      }
    }
  }

  static datetime limit_reached = 0;
  if (position.limit_reached) {
    TimedMessage(limit_reached, "Daily limit reached", magic_number, 60);
    return;
  }

  if (!SymbolInfoTick(symbol_operation,tick)) {
    Print("Fatal error get SymbolInfoTick - ID EA: "+string(magic_number));
    return;
  }

//--- AUCTION
  static datetime auction = 0;
  if (tick.volume == 0) {
    TimedMessage(auction, "Returned because auction: BID ("+DoubleToString(tick.bid, _Digits)+
                 ") - ASK ("+DoubleToString(tick.ask, _Digits)+
                 ") - VOLUME ("+DoubleToString(tick.volume, _Digits)+")",magic_number, 30);
    return;
  }

  if (!TimeAllowed(initial_time_operation, final_time_operation)) {
    if (!CloseOperations()) {
      Print("Error closing operations: "+(string)GetLastError()+" - ID EA: "+string(magic_number));
    }
    if (!DeleteOrders()) {
      Print("Error deleting orders: "+(string)GetLastError()+" - ID EA: "+string(magic_number));
    }

    static datetime time_not_allowed = 0;
    TimedMessage(time_not_allowed, "Time not allowed to operation: "+(string)TimeCurrent(),magic_number, 60);
    return;
  }
  
  if (Volume.Ticks == 0) {
    return;
  }
  
  MqlBookInfo Book[];
  int size, pos_BID, pos_ASK;
  
  // Book não disponível em teste    // Rogerio0004
  if(!MQLInfoInteger(MQL_TESTER))    // Rogerio0004
    {                                // Rogerio0004
     // solicita Book
     ResetLastError();
     MarketBookGet(_Symbol, Book);
     size = ArraySize(Book);
     if (size == 0)
       {
        Print("***********  Não foi possível pegar dados do book, erro = " + (string)GetLastError());
        return;
       }
    }
  // Rogerio0004 BEGIN
  else
    {
     // Em ambiente de testes, o book só tem uma informação, que é o melhor ask e o melhor bid atual.
     MqlTick tTick;
     SymbolInfoTick(Symbol(),tTick);
      
     size=2;
     ArrayResize(Book,size);
     // Melhor venda
     Book[0].price       = tTick.ask;
     Book[0].type        = BOOK_TYPE_SELL;
     Book[0].volume      = 1;
     Book[0].volume_real = 1;
      
     // Melhor compra
     Book[1].price       = tTick.bid;
     Book[1].type        = BOOK_TYPE_BUY;
     Book[1].volume      = 1;
     Book[1].volume_real = 1;
    }
  // Rogerio0004 END
  
  pos_BID = size / 2;
  pos_ASK = pos_BID - 1;
  
  // atualiza contador de ofertas (leituras)
  ContadorLeitura ++;

  // desloca dados liberando a posição zero
  for (int i=5; i>0; i--) {
    Leitura[i].PrecoCompra      = Leitura[i-1].PrecoCompra;
    Leitura[i].PrecoVenda       = Leitura[i-1].PrecoVenda;
    Leitura[i].QuantidadeCompra = Leitura[i-1].QuantidadeCompra;
    Leitura[i].QuantidadeVenda  = Leitura[i-1].QuantidadeVenda;
    Leitura[i].EquacaoM         = Leitura[i-1].EquacaoM;
    Leitura[i].VolumeDia        = Leitura[i-1].VolumeDia;
    Leitura[i].VolumeNegociado  = Leitura[i-1].VolumeNegociado;
    Leitura[i].DVAsk            = Leitura[i-1].DVAsk;
    Leitura[i].DVBid            = Leitura[i-1].DVBid;
    Leitura[i].OI               = Leitura[i-1].OI;
    Leitura[i].M                = Leitura[i-1].M;
    Leitura[i].DM               = Leitura[i-1].DM;
    Leitura[i].OIR              = Leitura[i-1].OIR;
    Leitura[i].TP               = Leitura[i-1].TP;
    Leitura[i].R                = Leitura[i-1].R;
    Leitura[i].S                = Leitura[i-1].S;
  }

  // leitura atual
  Leitura[0].PrecoCompra      = Book[pos_BID].price;   //BID
  Leitura[0].PrecoVenda       = Book[pos_ASK].price;   //ASK
  Leitura[0].QuantidadeCompra = Book[pos_BID].volume;
  Leitura[0].QuantidadeVenda  = Book[pos_ASK].volume;

  // volume de negociação do dia
  Leitura[0].VolumeDia = Volume.VWAP;
     
  // equação M
  Leitura[0].M = (Leitura[0].PrecoCompra + Leitura[0].PrecoVenda) / 2;
        
  // equação OIR
  if (Leitura[0].QuantidadeCompra + Leitura[0].QuantidadeVenda == 0)
     Leitura[0].OIR = 0;
  else
     Leitura[0].OIR = double(Leitura[0].QuantidadeCompra - Leitura[0].QuantidadeVenda) / double(Leitura[0].QuantidadeCompra + Leitura[0].QuantidadeVenda);
  
  // equação S
  Leitura[0].S = Leitura[0].PrecoVenda - Leitura[0].PrecoCompra;
              
  // equação TP - primeira leitura
  if (ContadorLeitura == 1) {
    Leitura[0].TP = Leitura[0].M;
    return;
  } 

  // equacao DVBid
  if (Leitura[0].PrecoCompra < Leitura[1].PrecoCompra)
    Leitura[0].DVBid = 0;
  else if(Leitura[0].PrecoCompra == Leitura[1].PrecoCompra)
    Leitura[0].DVBid = Leitura[0].QuantidadeCompra - Leitura[1].QuantidadeCompra;
  else
    Leitura[0].DVBid = Leitura[0].QuantidadeCompra;
  
  // equacao DVAsk
  if (Leitura[0].PrecoVenda < Leitura[1].PrecoVenda)
    Leitura[0].DVAsk = Leitura[0].QuantidadeVenda;
  else if(Leitura[0].PrecoVenda == Leitura[1].PrecoVenda)
    Leitura[0].DVAsk = Leitura[0].QuantidadeVenda - Leitura[1].QuantidadeVenda;
  else
    Leitura[0].DVAsk = 0;
  
  // equação OI
  Leitura[0].OI = Leitura[0].DVBid - Leitura[0].DVAsk;
  
  // equação DM
  Leitura[0].DM = Leitura[0].M - Leitura[1].M;
  
  // volume negociado é calculado a partir da segunda leitura
  Leitura[0].VolumeNegociado = Leitura[0].VolumeDia - Leitura[1].VolumeDia;
  
  // equação TP - a partir da segunda leitura
  Leitura[0].TP = Volume.VWAP;
  
  // equação R
  Leitura[0].R = Leitura[0].TP - (Leitura[0].M + Leitura[1].M) / 2;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| BUY OPERATION                                                    |
//+------------------------------------------------------------------+
void Buy() {
  double sl = NormalizeDouble(tick.ask - InpStopLoss,_Digits);
  double tp = NormalizeDouble(tick.ask + InpTakeProfit,_Digits);

  //--- if not bought
  if (!(PositionOrOrderOpen(true) || PositionOrOrderOpen(false))) {
    bool ok = trade.Buy(InpVolume,symbol_operation,0,sl,tp,"Compra a mercado");

    /*  Caso não funcione com SL/TP no envio da ordem, voltar para este método, testando o erro 10003
    if (ok) {
      value = trade.ResultPrice();
      sl = GetSLValue(symbol_operation,InpStopLoss,value,true);
      tp = GetTPValue(symbol_operation,InpTakeProfit,value,true);
      if (!SetSLAndTP(trade.ResultOrder(),sl,tp)) {
        ExitBuy();
        ok = false;
      }
    }
    */

    if (ok) {
      if (trade.ResultRetcode() != 10008 && trade.ResultRetcode() != 10009) {
        Print("Error from server: "+(string)trade.ResultRetcode());
      } else {
        position.ticket_bought = trade.ResultOrder();
        position.bought = ok;
        position.price = trade.ResultPrice();
        position.sl = sl;
        position.tp = tp;
      }
    } else {
      Print("Error from server sending trade.buy");
    }
  }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| SELL OPERATION                                                   |
//+------------------------------------------------------------------+
void Sell() {
  double sl = NormalizeDouble(tick.bid + InpStopLoss,_Digits);
  double tp = NormalizeDouble(tick.bid - InpTakeProfit,_Digits);

  //--- if not sold
  if (!(PositionOrOrderOpen(true) || PositionOrOrderOpen(false))) {
    bool ok = trade.Sell(InpVolume,symbol_operation,0,sl,tp,"Venda a mercado");

    /*  Caso não funcione com SL/TP no envio da ordem, voltar para este método, testando o erro 10003
    if (ok) {
      value = trade.ResultPrice();
      sl = GetSLValue(symbol_operation,InpStopLoss,value,false);
      tp = GetTPValue(symbol_operation,InpTakeProfit,value,false);
      if (!SetSLAndTP(trade.ResultOrder(),sl,tp)) {
        ExitSell();
        ok = false;
      }
    }
    */

    if(ok) {
      if (trade.ResultRetcode() != 10008 && trade.ResultRetcode() != 10009) {
        Print("Error from server: "+(string)trade.ResultRetcode());
      } else {
        position.ticket_sold = trade.ResultOrder();
        position.sold = ok;
        position.price = trade.ResultPrice();
        position.sl = sl;
        position.tp = tp;
      }
    } else {
      Print("Error from server sending trade.sell");
    }
  }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| TEST OPEN POSITION AND ORDERS                                    |
//+------------------------------------------------------------------+
bool PositionOrOrderOpen(bool _buy) {
  if (_buy) {
    return (position.bought || position.bought_pending);
  }

  return (position.sold || position.sold_pending);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| CLOSE OPERATIONS                                                 |
//+------------------------------------------------------------------+
bool CloseOperations() {
  bool ret = true;

  GetPositionAndOrders(position);
  if (position.bought || position.sold) {
    ulong ticket = (position.bought) ? position.ticket_bought : position.ticket_sold;
    if (ticket > 0 && trade.PositionClose(ticket)) {
      if (trade.ResultRetcode() != 10008 && trade.ResultRetcode() != 10009) {
        ret = false;
      }
    } else {
      ret = false;
    }

    ulong ticket_result = trade.ResultOrder();
    double price_result = trade.ResultPrice();

    if (position.bought) {
      position.ticket_exit_buy = ticket_result;
      position.price_exit_buy = price_result;
    } else {
      position.ticket_exit_sell = ticket_result;
      position.price_exit_sell = price_result;
    }

    position.time_operation = tick.time;
    position.bought = false;
    position.sold   = false;
  }

  return ret;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| DELETE ORDERS                                                    |
//+------------------------------------------------------------------+
bool DeleteOrders() {
  bool ret = true;

  GetPositionAndOrders(position);
  if (position.bought_pending || position.sold_pending) {
    ulong ticket = (position.bought_pending) ? position.ticket_bought_pending : position.ticket_sold_pending;
    if (ticket > 0 && trade.OrderDelete(ticket)) {
      if (trade.ResultRetcode() != 10008 && trade.ResultRetcode() != 10009) {
        ret = false;
      }
    } else {
      ret = false;
    }

    position.bought_pending = false;
    position.sold_pending   = false;
  }

  return ret;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| NEW DAY?                                                         |
//+------------------------------------------------------------------+
bool IsNewDay() {
  datetime today = GetDateTimeServer();
  
  // Rogerio004 BEGIN : Pega o maior entre o today acima, e o TimeTradeServer
  MqlDateTime today2MQL; TimeTradeServer(today2MQL);
  today2MQL.hour=0; today2MQL.min=0; today2MQL.sec=0;
  
  datetime today2 = StructToTime(today2MQL);
  
  today=MathMax(today,today2);
  // Rogerio004 END

  if (today > day_operation) {
    day_operation = today;
    initial_time_operation = today + (InpInitialHour*60*60) + (InpInitialMinute*60);
    final_time_operation = today + (InpFinalHour*60*60) + (InpFinalMinute*60);
    return true;
  }

  return false;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| INITIALIZING DAY                                                 |
//+------------------------------------------------------------------+
void InicioNovoDia() {
  if (InpLog) 
    InitLogFile();

  // inicializa array leitura
  for (int i=0 ; i<ArraySize(Leitura); i++) {
    Leitura[i].PrecoCompra      = 0;
    Leitura[i].PrecoVenda       = 0;
    Leitura[i].QuantidadeCompra = 0;
    Leitura[i].QuantidadeVenda  = 0;
    Leitura[i].EquacaoM         = 0;
    Leitura[i].VolumeDia        = 0;
    Leitura[i].VolumeNegociado  = 0;
    Leitura[i].DVAsk            = 0;
    Leitura[i].DVBid            = 0;
    Leitura[i].OI               = 0;
    Leitura[i].M                = 0;
    Leitura[i].DM               = 0;
    Leitura[i].OIR              = 0;
    Leitura[i].TP               = 0;
    Leitura[i].R                = 0;
    Leitura[i].S                = 0;
  }

  // inicializa contadores de volume
  Volume.Ticks      = 0;
  Volume.Contratos  = 0;
  Volume.Financeiro = 0;
  Volume.VWAP       = 0;
   
  // controle de ordens
  Ordens.QuantidadeTotal      = 0;
  Ordens.OperacoesEmAndamento = 0;
  Ordens.ComprasEmAndamento   = 0;
  Ordens.VendasEmAndamento    = 0;
  Ordens.SaldoFinanceiro      = 0;
  Ordens.MaiorSaldo           = 0;
  Ordens.MenorSaldo           = 0;

  // contador de leituras no dia
  ContadorLeitura = 0;
   
  // inicializa controles de compra e venda
  //ArrayResize(Operacao, Ordens.QuantidadeTotal, 1000);

  // limpa coeficientes
  for (int i=0 ; i<14 ; i++)
    Coeficiente[i] = 0;

  // carrega coeficientes do pregão anterior
  CarregaCoeficientes();
  
  position.limit_reached = false;
  position.paused = false;
  position.stopped = false;
  GetPositionAndOrders(position);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| LOAD DATA                                                        |
//+------------------------------------------------------------------+
void CarregaCoeficientes() {
  string texto;
  string file_name = GetDataFileName();
  int handle_data = FileOpen(file_name, FILE_READ | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_TXT | FILE_COMMON);
  if (handle_data == INVALID_HANDLE) {
    Print("Error reading DATA FILE ["+file_name+"]: "+string(GetLastError()));
    return;
  }

  texto = "Carregando coeficientes do arquivo: " + file_name;
  SalvaLog(texto);
  Print("Robo ID " + (string)magic_number + ": " + texto);

  string dados[];
  int pos[];
  ArrayResize(pos,0);
  switch(InpLag) {
    case 0: ArrayResize(pos,LAG0);
            for (int i = 0; i < LAG0; i++)
              pos[i] = lag0[i];
      break;
    case 1: ArrayResize(pos,LAG1);
            for (int i = 0; i < LAG1; i++)
              pos[i] = lag1[i];
      break;
    case 2: ArrayResize(pos,LAG2);
            for (int i = 0; i < LAG2; i++)
              pos[i] = lag2[i];
      break;
    case 3: ArrayResize(pos,LAG3);
            for (int i = 0; i < LAG3; i++)
              pos[i] = lag3[i];
      break;
    case 4: ArrayResize(pos,LAG4);
            for (int i = 0; i < LAG4; i++)
              pos[i] = lag4[i];
      break;
    case 5: ArrayResize(pos,LAG5);
            for (int i = 0; i < LAG5; i++)
              pos[i] = lag5[i];
      break;
  }
  
  while(!FileIsEnding(handle_data)) {
    texto = FileReadString(handle_data);
    StringSplit(texto,',',dados);
    if (StringToInteger(dados[0]) == InpLag) {
      for (int i = 1; i <= ArraySize(pos); i++) {
        Coeficiente[pos[i-1]] = StringToDouble(dados[i]);
      }
    }
  }

  FileClose(handle_data);
}

//+------------------------------------------------------------------+
//| LOGS                                                             |
//+------------------------------------------------------------------+
void SalvaLog(string Texto) {
  SalvaLog2(Texto, "");
}

void SalvaLog2(string Texto, string HorarioLog) {
  if (!InpLog || (handle_log == INVALID_HANDLE)) return;

  // adiciona horario e preço atual na mensagem
  if (HorarioLog.Length() == 0) {
    HorarioLog = PegaHorario(false);
  }
  Texto = HorarioLog
        + StringSubstr("        " + (string)tick.last, -9)
        + " - " + Texto;
   
  // grava no arquivo
  FileWrite(handle_log, Texto);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| GET DATE/TIME WITH MILISECONDS                                   |
//+------------------------------------------------------------------+
string PegaHorario(bool FormatoArquivo) { 
  MqlTick local_tick;
  MqlDateTime now;
  SymbolInfoTick(_Symbol, local_tick);
  TimeToStruct(local_tick.time, now);
	
	string Ano = IntegerToString(now.year,2,'0');
	string Mes = IntegerToString(now.mon,2,'0');
	string Dia = IntegerToString(now.day,2,'0');

	if (FormatoArquivo)
	   return (Ano + "." + Mes + "." + Dia);

	string Hora = IntegerToString(now.hour,2,'0');
	string Minuto = IntegerToString(now.min,2,'0');
	string Segundo = IntegerToString(now.sec,2,'0');
	long ms = local_tick.time_msc;
	ms = long(MathMod(ms,(ms/1000)*1000));
	string MiliSegundo = IntegerToString(ms,3,'0');
	
	return (Dia + "/" + Mes + "/" + Ano + " " + Hora + ":" + Minuto + ":" + Segundo + "." + MiliSegundo); 
}

//+------------------------------------------------------------------+
//| GET DATA FILE NAME                                               |
//+------------------------------------------------------------------+
string GetDataFileName() {
  MqlDateTime now;
  datetime time = TimeLocal();
  string file_name = "";

  if (InpTipoLeitura == POR_BOOK)  file_name = "_book";
  if (InpTipoLeitura == POR_TIMER) file_name = "_time" + (string)InpMilissegundos + "ms";
  if (InpTipoLeitura == POR_TICK)  file_name = "_tick";

  time -= 24*60*60;
  TimeToStruct(time, now);  

  string yymmdd = IntegerToString(now.year,4,'0')+IntegerToString(now.mon,2,'0')+IntegerToString(now.day,2,'0');

  file_name = "coeficientes_"+yymmdd+"_"+StringSubstr(_Symbol, 0, 3) + file_name + ".txt";
  
  return file_name;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| CHECK INPUTS                                                     |
//+------------------------------------------------------------------+
bool CheckInputErrors() {
  if (magic_number == 0) {
    if (InpMagicNumber == 0)
      magic_number = GetRandonNumber();
    else
      magic_number = InpMagicNumber;
  }

  symbol_operation = InpSymbol;
  StringTrimLeft(symbol_operation);
  StringTrimRight(symbol_operation);

  if (StringLen(symbol_operation) == 0) {
    symbol_operation = _Symbol;
  }

  if (InpEFPC < 0) {
    Print("Input Threshold error!");
    return false;
  }
  
  if (InpLag < 0 || InpLag > 5) {
    Print("Input LAG error!");
    return false;
  }
  
  if (InpForecast < 0) {
    Print("Input Forecast error!");
    return false;
  }
  
  tickSize = SymbolInfoDouble(symbol_operation,SYMBOL_TRADE_TICK_SIZE);
  tickValue = SymbolInfoDouble(symbol_operation,SYMBOL_TRADE_TICK_VALUE);

  if (!VolumeOperationTest(symbol_operation, InpStopLoss)) {
    Print("Input SL error!");
    return false;
  }

  if (!VolumeOperationTest(symbol_operation, InpTakeProfit)) {
    Print("Input TP error!");
    return false;
  }

  if (!MinMaxVolumeTest(symbol_operation, InpVolume)) {
    Print("Input Volume error!");
    return false;
  }

  //--- Klayton002 Atribuição sem uso no restante do código (FICARÁ COMENTADO)
  //volume_operation = InpVolume;

  if (InpDailyLoss < 0) {
    Print("Input Daily Loss error!");
    return false;
  }

  if (InpDailyProfit < 0) {
    Print("Input Daily Profit error!");
    return false;
  }

  if (InpInitialHour > 23) {
    Print("Input initial hour operation error!");
    return false;
  }

  if (InpInitialMinute > 59) {
    Print("Input initial minute operation error!");
    return false;
  }

  if (InpFinalHour > 23) {
    Print("Input final hour operation error!");
    return false;
  }

  if (InpFinalMinute > 59) {
    Print("Input final minute operation error!");
    return false;
  }

  initial_time_operation = GetDateTimeServer((InpInitialHour*60*60) + (InpInitialMinute*60));
  final_time_operation = GetDateTimeServer((InpFinalHour*60*60) + (InpFinalMinute*60));

  if (final_time_operation < initial_time_operation) {
    Print("Time operation error!");
    return false;
  }

  position.account_type = (ENUM_ACCOUNT_MARGIN_MODE) AccountInfoInteger(ACCOUNT_MARGIN_MODE);
  position.profit_calc = ENUM_PROFIT_VALUE;
  position.magic_number = magic_number;
  position.symbol = symbol_operation;

//--- check done
  return true;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| INITIALIZE INDICATORS                                            |
//+------------------------------------------------------------------+
bool InitializeIndicators() {
  if (!MarketBookAdd(_Symbol)) {
    Print("Error on MarketBookAdd("+_Symbol+"): "+string(GetLastError()));
    return false;
  }
  
  InitTmpLog();

  return true;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| INITIALIZE LOG FILE                                              |
//+------------------------------------------------------------------+
void InitTmpLog() {
  MqlDateTime now;
  string file_name;

  TimeLocal(now);

  ResetLastError();
  if (handle_tmp != INVALID_HANDLE)
    FileClose(handle_tmp);

  // identifica o modo de leitura para usar no nome do arquivo
  if (InpTipoLeitura == POR_BOOK)  file_name = "MudancaBook";
  if (InpTipoLeitura == POR_TIMER) file_name = "IntervaloTempo_" + (string)InpMilissegundos + "ms";
  if (InpTipoLeitura == POR_TICK)  file_name = "MudancaPreco";
  file_name = "Temp_"+string(now.year)+string(now.mon)+string(now.day) + "_" + _Symbol + "_Robo_" + (string)magic_number + "_Operacao_" + file_name + ".log";
  Print("Tmp Log file: " + file_name);

  // remove arquivo, caso já exista
  if (FileIsExist(file_name))
    FileDelete(file_name);

  // abre o arquivo de log de operação para o dia atual
  handle_tmp = FileOpen(file_name, FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_TXT | FILE_COMMON);
  if (handle_tmp == INVALID_HANDLE) {
    Print("Error initializing TMP LOG file: "+string(GetLastError()));
    Print("No log will be recorded");
    return;
  }
  
  FileWrite(handle_tmp,"EFPC;BID;ASK;Last");
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| INITIALIZE LOG FILE                                              |
//+------------------------------------------------------------------+
void InitLogFile() {
  MqlDateTime now;
  string file_name;

  TimeLocal(now);

  ResetLastError();
  if (handle_log != INVALID_HANDLE)
    FileClose(handle_log);

  // identifica o modo de leitura para usar no nome do arquivo
  if (InpTipoLeitura == POR_BOOK)  file_name = "MudancaBook";
  if (InpTipoLeitura == POR_TIMER) file_name = "IntervaloTempo_" + (string)InpMilissegundos + "ms";
  if (InpTipoLeitura == POR_TICK)  file_name = "MudancaPreco";
  file_name = string(now.year)+string(now.mon)+string(now.day) + "_" + _Symbol + "_Robo_" + (string)magic_number + "_Operacao_" + file_name + ".log";
  Print("Log file: " + file_name);

  // remove arquivo, caso já exista
  if (FileIsExist(file_name))
    FileDelete(file_name);

  // abre o arquivo de log de operação para o dia atual
  handle_log = FileOpen(file_name, FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_TXT | FILE_COMMON);
  if (handle_log == INVALID_HANDLE) {
    Print("Error initializing LOG file: "+string(GetLastError()));
    Print("No log will be recorded");
  }
}
//+------------------------------------------------------------------+

// Rogerio004 BEGIN
//+------------------------------------------------------------------+
//| GeraNovoArquivo                                                  |
//| Função para gerar o novo arquivo solicitado pelo Marcio          |
//| 15/11/2023 Rogerio Szterling                                     |
//| Leitura;Data;Hora;QtdeCompra;PreçoCompra;PreçoVenda;QtdeVenda;   |
//| DVBid;DVAsk;OI;M;DM;OIR;TP;R;S;EFPC                              |
//+------------------------------------------------------------------+
void GeraNovoArquivo()
  {
   static int Counter       = 0;
   string tLine = "";

   datetime tCurrent=TimeCurrent();
   // Se ainda não é horário
   if(tCurrent<initial_time_operation) return;
   
   // Se já passou do horário
   if(tCurrent>final_time_operation)
     {
      if(NewFileHandle!=INVALID_HANDLE)
        {
         FileClose(NewFileHandle);
         NewFileHandle=INVALID_HANDLE;
        }
      return;
     }
   
   // Cria/Abre novo arquivo
   if(NewFileHandle==INVALID_HANDLE)
     {
      MqlDateTime tNow; TimeLocal(tNow);
      string tFileName="HFT CSV "+string(tNow.year)+string(tNow.mon)+string(tNow.day)+".csv";
      
      // Remove arquivo, caso já exista
      if(FileIsExist(tFileName)) FileDelete(tFileName);
      
      NewFileHandle = FileOpen(tFileName, FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_TXT|FILE_COMMON);
      Counter = 1;
      
      // Grava header
      tLine="sep=;\r\nLeitura;Data;Hora;QtdeCompra;PreçoCompra;PreçoVenda;QtdeVenda;DVBid;DVAsk;OI;M;DM;OIR;TP;R;S;EFPC\r\n";
      FileWriteString(NewFileHandle,tLine);
     }
   
   // Com o arquivo aberto, grava linha de dados
   string tDataHora=PegaHorario(false);
   tLine ="";
   tLine+=IntegerToString(Counter)                               +";"; // Leitura
//   tLine+=TimeToString   (TimeCurrent(),TIME_DATE)               +";"; // Data
//   tLine+=TimeToString   (TimeCurrent(),TIME_SECONDS)            +";"; // Hora
   tLine+=StringSubstr   (tDataHora,0,10)                        +";"; // Data
   tLine+=StringSubstr   (tDataHora,11,12)                       +";"; // Hora
   tLine+=DoubleToString (Leitura[0].QuantidadeCompra,0)         +";"; // QtdCompra
   tLine+=DoubleToString (Leitura[0].PrecoCompra,1)              +";"; // PrecoCompra
   tLine+=DoubleToString (Leitura[0].QuantidadeVenda,0)          +";"; // QtdVenda
   tLine+=DoubleToString (Leitura[0].PrecoVenda,1)               +";"; // PrecoVenda
   tLine+=IntegerToString(Leitura[0].DVBid)                      +";"; // DVBid
   tLine+=IntegerToString(Leitura[0].DVAsk)                      +";"; // DVAsk
   tLine+=IntegerToString(Leitura[0].OI)                         +";"; // OI
   tLine+=DoubleToString (Leitura[0].M,2)                        +";"; // M
   tLine+=DoubleToString (Leitura[0].DM,2)                       +";"; // DM
   tLine+=DoubleToString (Leitura[0].OIR,2)                      +";"; // OIR
   tLine+=DoubleToString (Leitura[0].TP,2)                       +";"; // TP
   tLine+=DoubleToString (Leitura[0].R,2)                        +";"; // R
   tLine+=DoubleToString (Leitura[0].S,2)                        +";"; // S
   tLine+=DoubleToString (EFPC,2)                                    ; // EFPC
   tLine+="\r\n";

   FileWriteString(NewFileHandle,tLine);
   Counter++;
   
  } // GeraNovoArquivo
// Rogerio004 END