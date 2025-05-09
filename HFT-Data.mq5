//+------------------------------------------------------------------+
//|                                                    HFT-Data2.mq5 |
//|                              Copyright 2021, Factum Invest Ltda. |
//|                                  https://www.factuminvest.com.br |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2019"
#property link        "mailto:phd.marcio@gmail.com"
#property version     "2.00"
#property description "Geração de Coeficientes HFT"
#property description "Programação Gian/Alencar Philereno"
#property description "Projeto Marcio"


//+---------------------------------------------------------------------------------------+
//| ATENÇÃO TIME MASTERMIND:                                                              |
//| 1) Antes de fazer qualquer alteração, avise aos demais do time, para evitar mais de   |
//|    uma pessoa trabalhando no mesmo código e consequente encavalamento de versões.     |
//| 2) Antes de começar a alteração, certifique-se de estar com a versão mais recente     |
//|    fazendo um "Update from Storage" ("Obter atualização do repositório").             |
//| 3) Depois de terminada a alteração, grave sua versão fazendo um "Commit to Storage"   |
//|    ("Enviar alterações para o repositório"), e avise aos demais do time.              |
//| 4) DOCUMENTE suas alterações no log abaixo, e utilize o ID do log nos comentários de  |
//|    cada alteração ao código.                                                          |
//+---------------------------------------------------------------------------------------+
//| LOG MASTERMIND                                                                        |
//+---------------------------------------------------------------------------------------+
//|Data      |Usuário|ID  |Descrição                                                      |
//+---------------------------------------------------------------------------------------+
//|19.06.2023|Klayton|0001|Versão Inicial Reescrita                                       |
//|20.06.2023|Klayton|0002|Movido parte código do init para a função 4) InicioNovoDia()   |
//|          |       |    |Linha  565-577                                                 |
//|21.06.2023|Rogerio|0003|Formatação CSV para arquivo do Book                            |
//|          |       |    |Parâmetro para profundidade do Book                            |
//|22.06.2023|Rogerio|0004|Melhorias de Performance                                       |
//|25.06.2023|Rogerio|0005|FileClose no fim do dia + checa Fim-de-semana no TimeAllowed   |
//|15.11.2023|Rogerio|0006|Leitura do Book em ambiente de testes. Várias peq melhorias.   |
//|          |       |    |Diversos bug fixes, principalmente relacionados a data/hora    |
//+---------------------------------------------------------------------------------------+
//| FUNÇÕES COM BREVE RESUMO                                                              |
//+---------------------------------------------------------------------------------------+
//| 1) CheckInputErrors() - VERIFICA ERROS NOS DADOS DE ENTRADA                           |
//| 2) IsNewCandleDay() - VERIFICA SE É NOVO DIA                                          |
//| 3) TimeAllowed() - VALIDA HORÁRIO DE NEGOCIAÇÃO                                       |
//| 4) InicioNovoDia() - INICIALIZA VARIÁVEIS A CADA NOVO DIA                             |
//| 5) ProcessaDados() - PROCESSA OS DADOS EFETUANDO OS CALCULOS                          |
//| 6) AtualizaArrayLeitura() - UPDATE ARRAY PARA RECEBER NOVA LEITURA                    |
//| 7) CalculaMatrizXX() - Calcula a matriz X'X                                           |
//| 8) CalculaMatrizXY() - Calcula a matriz X'Y                                           |
//| 9) PegaHorario() - RETORNA HORÁRIO COM MILISEGUNDOS                                   |
//| 10) SalvaMatrizes() - SALVA MATRIZES EM ARQUIVO                                       |
//| 11) GravaDadosMatrizBidimensional() - GRAVA DADOS DA MATRIZ DE 2 DIMENSÕES EM ARQUIVO |
//| 12) InverteMatrizes() - INVERTE E MULTIPLICA MATRIZES                                 |
//| 13) GravaDadosMatrizUnidimensional() - GRAVA DADOS DA MATRIZ DE 1 DIMENSÃO EM ARQUIVO |
//| 14) GetFileName() - RECEBE NOME DO ARQUIVO BASENADO NO TIPO LEITURA                   |
//| 15) GravaDadosCoeficientes() - GRAVA COEFICIENTES                                     |
//| 16) CargaMatrixPorLag() - CARREGA MATRIZES POR TIPO DE LAG                            |
//| 17) InverteMatrizesAlgLib() - INVERTE MATRIZES UTILIZANDO ALGOLIB                     |
//| 18) MultiplicaMatriz() - MULTIPLICA MATRIZES                                          |
//| 19) CriaArquivo() - Cria/Abre Arquivos                                                |
//| 20) FUNÇÃO QUE INFORMA O MOTIVO DAS PARADAS DO EA                                     |
//+---------------------------------------------------------------------------------------+
//| OBS:                                                                                  |
//| 1) Função CheckInputErrors() - Falta fazer as validações de Horário                   |
//+---------------------------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| INCLUDES                                                         |
//+------------------------------------------------------------------+
#include <Math\Alglib\alglib.mqh>


//+------------------------------------------------------------------+
//| ENUMERADOR QUE LIGA E DESLIGA                                    |
//+------------------------------------------------------------------+
enum ENUM_LIGA_DESLIGA
  {
   LIGADO,     // Ligado
   DESLIGADO   // Desligado
  };

//+------------------------------------------------------------------+
//| ENUMERADOR QUE DEFINE TIPO DE LEITURA                            |
//+------------------------------------------------------------------+
enum ENUM_TIPO_LEITURA
  {
   POR_TICK,    // Por mudança de preço
   POR_TIMER,   // Por intervalo de tempo
   POR_BOOK     // Por mudança no book
  };

//+------------------------------------------------------------------+
//| ENUMERADOR QUE DEFINE LAG A SER UTILIZADO                        |
//+------------------------------------------------------------------+
enum ENUM_LAGS
  {
   LAG0 = 4,
   LAG1 = 6,
   LAG2 = 8,
   LAG3 = 10,
   LAG4 = 12,
   LAG5 = 14
  };

//+------------------------------------------------------------------+
//| ENUMERADOR DE HORAS                                              |
//+------------------------------------------------------------------+

enum ENUM_HORAS
  {
   hora_00 = 0,    // 00
   hora_01 = 1,    // 01
   hora_02 = 2,    // 02
   hora_03 = 3,    // 03
   hora_04 = 4,    // 04
   hora_05 = 5,    // 05
   hora_06 = 6,    // 06
   hora_07 = 7,    // 07
   hora_08 = 8,    // 08
   hora_09 = 9,    // 09
   hora_10 = 10,   // 10
   hora_11 = 11,   // 11
   hora_12 = 12,   // 12
   hora_13 = 13,   // 13
   hora_14 = 14,   // 14
   hora_15 = 15,   // 15
   hora_16 = 16,   // 16
   hora_17 = 17,   // 17
   hora_18 = 18,   // 18
   hora_19 = 19,   // 19
   hora_20 = 20,   // 20
   hora_21 = 21,   // 21
   hora_22 = 22,   // 22
   hora_23 = 23    // 23
  };

//+------------------------------------------------------------------+
//| ENUMERADOR DE MINUTOS                                            |
//+------------------------------------------------------------------+

enum ENUM_MINUTOS
  {
   min_00 = 0,   // 00
   min_01 = 1,   // 01
   min_02 = 2,   // 02
   min_03 = 3,   // 03
   min_04 = 4,   // 04
   min_05 = 5,   // 05
   min_06 = 6,   // 06
   min_07 = 7,   // 07
   min_08 = 8,   // 08
   min_09 = 9,   // 09
   min_10 = 10,  // 10
   min_11 = 11,  // 11
   min_12 = 12,  // 12
   min_13 = 13,  // 13
   min_14 = 14,  // 14
   min_15 = 15,  // 15
   min_16 = 16,  // 16
   min_17 = 17,  // 17
   min_18 = 18,  // 18
   min_19 = 19,  // 19
   min_20 = 20,  // 20
   min_21 = 21,  // 21
   min_22 = 22,  // 22
   min_23 = 23,  // 23
   min_24 = 24,  // 24
   min_25 = 25,  // 25
   min_26 = 26,  // 26
   min_27 = 27,  // 27
   min_28 = 28,  // 28
   min_29 = 29,  // 29
   min_30 = 30,  // 30
   min_31 = 31,  // 31
   min_32 = 32,  // 32
   min_33 = 33,  // 33
   min_34 = 34,  // 34
   min_35 = 35,  // 35
   min_36 = 36,  // 36
   min_37 = 37,  // 37
   min_38 = 38,  // 38
   min_39 = 39,  // 39
   min_40 = 40,  // 40
   min_41 = 41,  // 41
   min_42 = 42,  // 42
   min_43 = 43,  // 43
   min_44 = 44,  // 44
   min_45 = 45,  // 45
   min_46 = 46,  // 46
   min_47 = 47,  // 47
   min_48 = 48,  // 48
   min_49 = 49,  // 49
   min_50 = 50,  // 50
   min_51 = 51,  // 51
   min_52 = 52,  // 52
   min_53 = 53,  // 53
   min_54 = 54,  // 54
   min_55 = 55,  // 55
   min_56 = 56,  // 56
   min_57 = 57,  // 57
   min_58 = 58,  // 58
   min_59 = 59   // 59
  };

//+------------------------------------------------------------------+
//| STRUCT DE LEITURA DOS DADOS                                      |
//+------------------------------------------------------------------+
struct EstruturaLeitura
  {
   double            PrecoCompra;
   double            PrecoVenda;
   long              QuantidadeCompra;
   long              QuantidadeVenda;
   double            EquacaoM;
   double            VolumeDia;
   double            VolumeNegociado;
   long              DVAsk;
   long              DVBid;
   long              OI;
   double            M;
   double            DM;
   double            OIR;
   double            TP;
   double            R;
   double            S;
  };

//+------------------------------------------------------------------+
//| STRUCT DE IDENTIFICAÇÃO DO TIPO DE VOLUME                        |
//+------------------------------------------------------------------+
struct EstruturaVolume
  {
   double            Ticks;
   double            Contratos;
   double            Financeiro;
   double            VWAP;
  };
//+------------------------------------------------------------------+
//| INPUTS - PARÂMETROS DE ENTRADA                                   |
//+------------------------------------------------------------------+
input group                   "EXTRAÇÃO DE DADOS PARA ARQUIVO"
input ENUM_LIGA_DESLIGA       iArquivoBook     = DESLIGADO;                   // Ativar extração do book para arquivo
input ENUM_LIGA_DESLIGA       iArquivoEquacoes = DESLIGADO;                   // Ativar extração de equações para arquivos
input ENUM_LIGA_DESLIGA       iArquivoMatrizes = DESLIGADO;                   // Gravar AGORA arquivo com parcial das matrizes ?
input ENUM_TIPO_LEITURA       iTipoLeitura     = POR_TIMER;                   // Tipo de leitura
input int                     iMilissegundos   = 500;                         // Tempo entre leituras por intervalo de tempo (milissegundos)

//--- Rogerio003 INICIO
input group                   "FILTROS"
input int                     iProfundidade    = 10;                          // Profundidade do Book no arquivo
//--- Rogerio003 FIM

input group                   "HORÁRIO DE INÍCIO DAS ENTRADAS"
input ENUM_HORAS              i_hora_inicio    = hora_09;                     // Hora
input ENUM_MINUTOS            i_min_inicio     = min_10;                      // Minutos

input group                   "HORÁRIO DE ENCERRAMENTO DAS ENTRADAS"
input ENUM_HORAS              i_hora_fim       = hora_16;                     // Hora
input ENUM_MINUTOS            i_min_fim        = min_00;                      // Minutos

//input string                  iInicioPregao    = "09:00";       // Horário inicial do pregão (mm:ss)
//input string                  iFinalPregao     = "17:55";       // Horário final do pregão (mm:ss)


//+------------------------------------------------------------------+
//| VARIÁVEIS GLOBAIS                                                |
//+------------------------------------------------------------------+

MqlTick       gLastTick;

string        gHoraInicio       = "",
              gHoraFim          = "";

//double        lastcloseD      = 0; // Rogerio0006 DELETE

datetime      gLastTimeDay      = 0,
              gHrInicial        = 0, // Rogerio0006 ADD
              gHrFinal          = 0; // Rogerio0006 ADD

//--- Handles de acesso a arquivos
int           gHandlerBook      = INVALID_HANDLE;
int           gHandlerOferta    = INVALID_HANDLE;

//--- Contadores
ulong         gContadorBook     = 0;          // contador de leituras do book se geração de arquivo book está ligado
ulong         gContadorLeitura  = 0;          // contador de leituras do book se geração de arquivo equações está ligado

//--- Flags de validação
//bool             InicioDia        = true;     // Rogerio004 Delete. Não é utilizada.
bool          gFinalDia         = false;
bool          gFinalDiaAnt      = false; // Rogerio0006: armazena o anterior para saber se "acabou de acabar" o dia
bool          gLeilao           = true;

/* Rogerio0006 BEGIN DELETE. Não são utilizados.
//--- Define os nomes dos arquivos
string        gFileNameEquacoes = "",
              gFileNameBook     = "",
              gFileNameMatriz   = "";
*/ //Rogerio0006 END DELETE

//--- Atribuições do Struct
EstruturaLeitura Leitura[6];
EstruturaVolume  Volume;

//--- Matrizes Lag 0
double           MatrizXX0[4, 4];
double           MatrizXXInversa0[4, 4];
double           MatrizXY0[4];
double           MatrizCoeficientes0[4];

//--- Matrizes Lag 1
double           MatrizXX1[6, 6];
double           MatrizXXInversa1[6, 6];
double           MatrizXY1[6];
double           MatrizCoeficientes1[6];

//--- Matrizes Lag 2
double           MatrizXX2[8, 8];
double           MatrizXXInversa2[8, 8];
double           MatrizXY2[8];
double           MatrizCoeficientes2[8];

//--- Matrizes Lag 3
double           MatrizXX3[10, 10];
double           MatrizXXInversa3[10, 10];
double           MatrizXY3[10];
double           MatrizCoeficientes3[10];

//--- Matrizes Lag 4
double           MatrizXX4[12, 12];
double           MatrizXXInversa4[12, 12];
double           MatrizXY4[12];
double           MatrizCoeficientes4[12];

//--- Matrizes Lag 5
double           MatrizXX5[14, 14];
double           MatrizXXInversa5[14, 14];
double           MatrizXY5[14];
double           MatrizCoeficientes5[14];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("Iniciando EA...");              //Rogerio0006
   Print("Inicializando variáveis...");   //Rogerio0006
// Rogerio0006 BEGIN
//--- Função 00) Inicialização de variáveis
   gHoraInicio       = IntegerToString(i_hora_inicio) + ":" + IntegerToString(i_min_inicio);
   gHoraFim          = IntegerToString(i_hora_fim)    + ":" + IntegerToString(i_min_fim);
   gLastTimeDay      = 0;
   gHrInicial        = 0;
   gHrFinal          = 0;

   gHandlerBook      = INVALID_HANDLE;
   gHandlerOferta    = INVALID_HANDLE;

   gContadorBook     = 0;
   gContadorLeitura  = 0;

   gFinalDia         = false;
   gFinalDiaAnt      = false;
   gLeilao           = true;

// Rogerio0006 END
  
//--- Função 01) Checa parâmetros de entrada (INPUT)
   Print("Verificando parâmetros de entrada...");   //Rogerio0006
   if(!CheckInputErrors())
     {
      return INIT_PARAMETERS_INCORRECT;
     }
     
   //--- Ativa evento de Book
   Print("Ativando book de ofertas...");   //Rogerio0006
   ResetLastError();
   if(!MarketBookAdd(_Symbol))
     {
      Print("***************************** Erro ao abrir DOM: " + (string)GetLastError());
      return INIT_FAILED;
     }
// 
   //--- Ativa o evento de timer
   Print("Ativando timer de ",iMilissegundos," ms...");   //Rogerio0006
   ResetLastError();
   if(!EventSetMillisecondTimer(iMilissegundos))
     {
      Print("***************************** Erro ao ativar timer: " + (string)GetLastError());
      return INIT_FAILED;
     }
     
   //--- Função 4) Inicializando robô pela primeira vez
   Print("Buscando novo dia...");   //Rogerio0006
   if(isNewDay())                   // Rogerio0006 (sempre será verdadeiro na inicialização)
      InicioNovoDia();

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   MarketBookRelease(_Symbol);
   EventKillTimer();
   
   if(Leitura[0].S != 0 && !gFinalDia) 
     SalvaMatrizes();

   // Rogerio0006 BEGIN
   if(gHandlerBook!=INVALID_HANDLE)
     {
      FileClose(gHandlerBook);
      Print("Arquivo de BOOK fechado");
     }
     
   if(gHandlerOferta!=INVALID_HANDLE)
     {
      FileClose(gHandlerOferta);
      Print("Arquivo de EQUAÇÕES fechado");
     }
   // Rogerio0006 END

   infoLeavingEA(reason);
  }
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Rogerio004 Início Delete: Função de novo dia agora está sendo executada em OnTimer ao invés de OnTick
   /*MqlRates  ArrayCandles[];

   // pega o último candle para identificar se há candle novo desenhado
   ArraySetAsSeries(ArrayCandles, true); 
   ResetLastError();
   if (CopyRates(_Symbol, PERIOD_H1, 0, 2, ArrayCandles) <= 0) 
      {
      Print("***********  Não foi possível pegar dados dos candles, erro = " + (string)GetLastError());
      return;
      }
   
   // verifica se mudou o dia (caso robo esteja rodando continuamente)
   if (StringSubstr((string)ArrayCandles[0].time, 0, 10) != StringSubstr((string)ArrayCandles[1].time, 0, 10))
      {
      // verifica se já executou procedimentos de inicio de dia
      if (!InicioDia)
         {
         // dia novo iniciando
         InicioDia = true;
         InicioNovoDia();
         }
      }
   else
      InicioDia = false; */
   // Rogerio004 Fim Delete

   // pega dados do ultimo tick   
   if (!SymbolInfoTick(_Symbol, gLastTick))
      {
      Print("***********  Não foi possível pegar dados do ultimo tick, erro = " + (string)GetLastError());
      return;
      }

   // verifica se houve um negocio realizado ou se apenas houve mudança de valores/volumes sem nenhum negocio ter sido realizado
   bool NegocioRealizado = (gLastTick.flags & TICK_FLAG_BUY) + (gLastTick.flags & TICK_FLAG_SELL) > 0;

   // processa volumes somente em caso de negócio fechado no book
   if (NegocioRealizado)
     {
      // calcula volumes
      Volume.Ticks      += 1;
      Volume.Contratos  += (double)gLastTick.volume;
      Volume.Financeiro += gLastTick.last * gLastTick.volume;
      Volume.VWAP        = Volume.Financeiro / Volume.Contratos;
     }
      
   // identifica leilão
   //Leilao = gLastTick.bid >= gLastTick.ask;
   gLeilao = (gLastTick.volume == 0);
   
   // processa dados por tick (se configurado)
   if (iTipoLeitura == POR_TICK)
      // valida horário do pregão
      if (TimeAllowed())
         ProcessaDados();
  
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   // if(isNewCandleDay()) // Rogerio0006 DELETE
   if(isNewDay())          // Rogerio0006 ADD
     {
      // lastTimeD = TimeCurrent(); // Rogerio0006 DELETE
      //--- Função 4) Inicializando robô em Novo Dia
      InicioNovoDia();
     }
     
   if(iTipoLeitura == POR_TIMER)
     {
      // valida horário do pregão   AQUI Inicio
      if(TimeAllowed())
        {
         //Print(TimeCurrent(), " - robo Habilitado para operar!!!!");
         ProcessaDados();
        }
//      else              // Rogerio0006 DELETE
//      if(!gFinalDia)    // Rogerio0006 DELETE
      if(gFinalDia && !gFinalDiaAnt)     // Rogerio0006 ADD: Acabou de acabar o dia
        {
         Print("Encerrando o dia...");
         //gFinalDia = true;    // Rogerio0006 DELETE
         gFinalDiaAnt = true;   // Rogerio0006 ADD
         // Rogerio005: Início: Fecha arquivos
         if(gHandlerBook!=INVALID_HANDLE)
           {
            FileClose(gHandlerBook);
            Print("Arquivo de BOOK fechado");
            gHandlerBook=INVALID_HANDLE;
           }
         if(gHandlerOferta!=INVALID_HANDLE)
           {
            FileClose(gHandlerOferta);
            Print("Arquivo de EQUAÇÕES fechado");
            gHandlerOferta=INVALID_HANDLE;
           }
         // Rogerio005: Fim
         SalvaMatrizes();
        }
     }
  }


//+------------------------------------------------------------------+
//| BookEvent function                                               |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
  {
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 1) CheckInputErrors() - VERIFICA ERROS NOS DADOS DE ENTRADA      |
//+------------------------------------------------------------------+
bool CheckInputErrors()
  {
   return true;
  }

/* Rogerio0006: Função IsNewCandleDay substituída pela IsNewDay
//+------------------------------------------------------------------+
//| 2) IsNewCandleDay() - VERIFICA SE É NOVO DIA                     |
//+------------------------------------------------------------------+
bool isNewCandleDay()
  {
   // Rogerio004 Início Modificação (linhas deletadas e adicionadas)
   //if(iClose(Symbol(), PERIOD_D1, 1) == lastcloseD)
   //   return(false);
   //if(iClose(Symbol(), PERIOD_D1, 1) != lastcloseD)
   //  {
   //   lastcloseD = iClose(Symbol(), PERIOD_D1, 1);
   //   return(true);
   //  }
   //return(true);
   double newcloseD = iClose(Symbol(),PERIOD_D1, 1);
   if(newcloseD == lastcloseD)
     return(false);
   else
     {
      lastcloseD=newcloseD;
      return(true);
     }
   // Rogerio004 Fim Modificação
  } // isNewCandleDay
*/

// Rogerio0006 BEGIN
//+------------------------------------------------------------------+
//| 2) isNewDay() - VERIFICA SE É NOVO DIA                           |
//+------------------------------------------------------------------+
bool isNewDay()
  {
   datetime tTime = iTime(Symbol(), PERIOD_D1, 0);

   // Rogerio0006 BEGIN : Pega o maior entre o tTime acima, e o TimeTradeServer
   MqlDateTime tNow; TimeTradeServer(tNow);
   tNow.hour=0; tNow.min=0; tNow.sec=0;
  
   datetime tTime2 = StructToTime(tNow);
  
  tTime=MathMax(tTime,tTime2);
  // Rogerio0006 END

   if(tTime>gLastTimeDay)
     {
      gLastTimeDay = tTime;
      gHrInicial   = tTime + 3600*i_hora_inicio + 60*i_min_inicio;
      gHrFinal     = tTime + 3600*i_hora_fim    + 60*i_min_fim;
      Print("Novo dia detectado: ",TimeToString(tTime)," | Operação das ",TimeToString(gHrInicial,TIME_MINUTES)," às ",TimeToString(gHrFinal,TIME_MINUTES));
      return true;
     }
   else
     return false;
  } // isNewDay()
// Rogerio0006 END
  
//+------------------------------------------------------------------+
//| 3) TimeAllowed() - VALIDA HORÁRIO DE NEGOCIAÇÃO                  |
//+------------------------------------------------------------------+
bool TimeAllowed()
  {
   // Rogerio005 Inicio: Verifica fim-de-semana
   MqlDateTime t_dt; TimeTradeServer(t_dt);
   if(t_dt.day_of_week==0 || t_dt.day_of_week==6)
     {
      //Print("Fim-de-semana detectado: sem negociação");
      return(false);
     }
   // Rogerio005 Fim: Verifica fim-de-semana
   
   /* Rogerio0006 BEGIN DELETE. Não precisa calcular o início e o fim a cada execução, pois estamos calculando em isNewDay
   int copied = CopyRates(_Symbol, PERIOD_D1, 0, 1, dailyBar);
   if(copied == 1)
     {
      // datetime dateStart = dailyBar[0].time; // '2019.11.15 00:00:00'
      datetime tempoInicial = dailyBar[0].time + (i_hora_inicio * 60 * 60) + (i_min_inicio * 60);

      datetime tempoFinal = dailyBar[0].time + (i_hora_fim * 60 * 60) + (i_min_fim * 60);
     }
   */ // Rogerio0006 END DELETE
     
   datetime tTimeNow = TimeCurrent();

   // if(timeNow >= tempoInicial && timeNow < tempoFinal) // Rogerio0006 DELETE
   if(tTimeNow>=gHrInicial && tTimeNow<gHrFinal)            // Rogerio0006 ADD
     {
      return(true);
     }
   else
     {
      gFinalDia = tTimeNow>=gHrFinal;                    // Rogerio0006 ADD
      return(false);
     }
  } // TimeAllowed

//+------------------------------------------------------------------+
//| 4) InicioNovoDia() - INICIALIZA VARIÁVEIS A CADA NOVO DIA        |
//+------------------------------------------------------------------+
void InicioNovoDia()
  {
// inicializa array leitura
   Print("Inicializando matriz de leitura...");   //Rogerio0006

   for(int i = 0 ; i < ArraySize(Leitura); i++)
     {
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
//--- Inicializa contadores de volume
   Print("Inicializando contadores...");   //Rogerio0006
   Volume.Ticks      = 0;
   Volume.Contratos  = 0;
   Volume.Financeiro = 0;
   Volume.VWAP       = 0;
//--- Inicializa contadores de leitura
   gContadorBook    = 0;
   gContadorLeitura = 0;
// dia iniciando
   gFinalDia        = false;
   gFinalDiaAnt     = false; // Rogerio0006 ADD
// inicializa matriz X'X
   for(int i = 0 ; i < 14 ; i++)
      for(int j = 0 ; j < 14 ; j++)
         MatrizXX5[i, j] = 0;
// inicializa matriz X'Y
   for(int i = 0 ; i < 14 ; i++)
      MatrizXY5[i] = 0;

/* Rogerio0006 BEGIN DELETE: função CriaArquivo foi simplificada   
   //--- Verifica se é para gerar arquivos de Book e Equações
   if((iArquivoBook == LIGADO) && (iArquivoEquacoes == LIGADO))   CriaArquivo(true, true);
   //--- Verifica se é para gerar apenas arquivos de Book
   else if(iArquivoBook == LIGADO)                  CriaArquivo(true, false);
   //--- Verifica se é para gerar apenas arquivos de Equações
   else if(iArquivoEquacoes == LIGADO)              CriaArquivo(false, true);
   //--- Verifica se não é para gerar arquivos - Pode ser retirado
   else                                   CriaArquivo(false, false);
*/ // Rogerio0006 END DELETE

   Print("Criando arquivos de saída...");   // Rogerio0006 ADD
   CriaArquivo();                           // Rogerio0006 ADD

   //--- Verifica se foi solicitada a geração do arquivo de matrizes
   if(iArquivoMatrizes == LIGADO)
     {
      //--- Função 10) salva as matrizes em arquivo
      // Print("Gerando arquivo de matrizes..."); // Rogerio0006 DELETE: Redundante
      SalvaMatrizes();
     }
      
   // cria arquivos de extração de book e extração de equações
   //CriaArquivo(true, true);
   // Print("Inicio do dia " + (string)TimeCurrent()); // Rogerio0006 DELETE
   Print("Inicio do dia " + TimeToString(MathMax(TimeCurrent(),TimeTradeServer()),TIME_DATE)); // Rogerio0006 ADD
  }

//+------------------------------------------------------------------+
//| 5) ProcessaDados() - PROCESSA OS DADOS EFETUANDO OS CALCULOS     |
//+------------------------------------------------------------------+
void ProcessaDados()
  {
// declara variáveis
   string Linha, Horario;
   int I, Tamanho;
   MqlBookInfo Book[];
// solicita Book
   // Book não disponível em teste
   if(!MQLInfoInteger(MQL_TESTER))
     {
      ResetLastError();
      MarketBookGet(_Symbol, Book);
      Tamanho = ArraySize(Book);
      if(Tamanho == 0)
        {
         Print("***********  Não foi possível pegar dados do book, erro = " + (string)GetLastError());
         return;
        }
     }
   else // MQL_TESTER = true
     // Em ambiente de testes, o book só tem uma informação, que é o melhor ask e o melhor bid atual.
     {
      MqlTick tTick;
      SymbolInfoTick(Symbol(),tTick);
      
      Tamanho=2;
      ArrayResize(Book,Tamanho);
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

// horário da extração
   Horario = PegaHorario(false) + " ";
   
//--- Rogerio003 INICIO: Encontra o ponto de equilíbrio do book (primeira oferta de compra depois das vendas)
   int tFirstBuy=0;
   for(int i=1;i<Tamanho;i++)
     if(Book[i].type!=Book[i-1].type)
       { tFirstBuy=i; break; }
//--- Rogerio003 FIM

// Loop de extração de dados do Book
   //for(I = 0 ; I < Tamanho ; I++)                               // Rogerio004 Delete: Agora executa só para a profundidade desejada
   for(I=tFirstBuy-iProfundidade; I<tFirstBuy+iProfundidade; I++) // Rogerio004 Inclusão pela razão acima
     {
      // Este loop tem duas partes:
      // LOOP BOOK PARTE 1. Para gravar o arquivo de book. Executa para todas as iterações do loop.
      // LOOP BOOK PARTE 2. Executa apenas para a melhor oferta de compra e venda, para atualizar as Leituras e grava arquivo de Equações

      // LOOP BOOK PARTE 1: INÍCIO
      if(iArquivoBook == LIGADO)
        {
         // inicio da linha para salvar
         if(gLeilao)
           //--- Rogerio003 INICIO: Não grava leilão para não impactar o CSV
           {
           // Linha = "Leilão    " + Horario;
           // FileWrite(HandlerBook, Linha);
           }
           //--- Rogerio003 FIM
         else
            if(Volume.Ticks > 0)
              {
               // contador de book
               //if(I == 0)                     // Rogerio004 Delete: Agora executa só para a profundidade desejada
               if(I == tFirstBuy-iProfundidade) // Rogerio004 Inclusão pela razão acima
                  gContadorBook ++;
               // salva linha no arquivo
               //--- Rogerio003 INICIO MODIFICAÇÃO
               //Linha = StringSubstr("0000000" + string(ContadorBook), -7);
               //Linha = IntegerToString(ContadorBook, 7, '0') + "   " + Horario;
               //Linha = Linha + StringSubstr(EnumToString(Book[I].type) + "  ", 0, 15) ;
               //Linha = Linha + StringSubstr("           " + string(Book[I].price), -9) + " ";
               //Linha = Linha + StringSubstr("           " + string(Book[I].volume), -9);

               Linha = (string)gContadorBook                   +";";       // Contador
               Linha+= StringSubstr(Horario,11,12)            +";";       // Pega somente hh:mm:ss.xxx (sem a data)
               Linha+= (Book[I].type==BOOK_TYPE_BUY)?          "C;":"V;"; // Compra ou Venda
               Linha+= DoubleToString(Book[I].price,Digits()) +";";       // Preço
               Linha+= (string)Book[I].volume;                            // Volume
               FileWrite(gHandlerBook, Linha);
               //--- Rogerio003 FIM MODIFICAÇÃO
              }
        }
      // LOOP BOOK PARTE 1: FIM

      // LOOP BOOK PARTE 2: INÍCIO
      // identifica melhor oferta de compra e venda
      //if(I > 0 && Book[I].type != Book[I - 1].type) // Rogerio003 DELETADO 
      if(I==tFirstBuy)                                // Rogerio003 ADICIONADO
        {
         if(gLeilao)  // papel em leilão
           {
            if(iArquivoEquacoes == LIGADO)
              {
               // preço está em leilão
               Linha = "Leilão    " + Horario;
               FileWrite(gHandlerOferta, Linha);
              }
           }
         else
            if(Volume.Ticks > 0)  // papel fora do leilão
              {
               // atualiza contador de ofertas (leituras)
               gContadorLeitura ++;
               // atualiza array de leitura para receber nova leitura
               AtualizaArrayLeitura();
               // leitura atual
               Leitura[0].PrecoCompra      = Book[I].price;
               Leitura[0].PrecoVenda       = Book[I - 1].price;
               Leitura[0].QuantidadeCompra = Book[I].volume;
               Leitura[0].QuantidadeVenda  = Book[I - 1].volume;
               // volume de negociação do dia
               Leitura[0].VolumeDia = Volume.VWAP;
               // equação M
               Leitura[0].M = (Leitura[0].PrecoCompra + Leitura[0].PrecoVenda) / 2;
               // equação OIR
               if(Leitura[0].QuantidadeCompra + Leitura[0].QuantidadeVenda == 0)
                  Leitura[0].OIR = 0;
               else
                  Leitura[0].OIR = double(Leitura[0].QuantidadeCompra - Leitura[0].QuantidadeVenda) / double(Leitura[0].QuantidadeCompra + Leitura[0].QuantidadeVenda);
               // equação S
               Leitura[0].S = Leitura[0].PrecoVenda - Leitura[0].PrecoCompra;
               // equação TP - primeira leitura
               if(gContadorLeitura == 1)
                  Leitura[0].TP = Leitura[0].M;
               else
                 {
                  // equacao DVBid
                  if(Leitura[0].PrecoCompra < Leitura[1].PrecoCompra)
                     Leitura[0].DVBid = 0;
                  else
                     if(Leitura[0].PrecoCompra == Leitura[1].PrecoCompra)
                        Leitura[0].DVBid = Leitura[0].QuantidadeCompra - Leitura[1].QuantidadeCompra;
                     else
                        Leitura[0].DVBid = Leitura[0].QuantidadeCompra;
                  // equacao DVAsk
                  if(Leitura[0].PrecoVenda < Leitura[1].PrecoVenda)
                     Leitura[0].DVAsk = Leitura[0].QuantidadeVenda;
                  else
                     if(Leitura[0].PrecoVenda == Leitura[1].PrecoVenda)
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
                  //if (Leitura[0].VolumeNegociado != Leitura[1].VolumeNegociado)
                  //   Leitura[0].TP = double(Leitura[0].VolumeDia - Leitura[1].VolumeDia) / double(Leitura[0].VolumeNegociado - Leitura[1].VolumeNegociado);
                  //else
                  //   Leitura[0].TP = Leitura[1].TP;
                  // equação TP - a partir da segunda leitura
                  Leitura[0].TP = Volume.VWAP;
                  // equação R
                  Leitura[0].R = Leitura[0].TP - (Leitura[0].M + Leitura[1].M) / 2;
                 }
               // calcula matrizes
               CalculaMatrizXX();
               CalculaMatrizXY();
               // linha de dados para salvar
               if(iArquivoEquacoes == LIGADO)
                 {
                  //FileSeek(HandlerOferta,0,SEEK_END);
                  //Linha = StringSubstr("0000000" + string(ContadorLeitura), -7);
                  //Linha = Linha + "   " + Horario;
                  //Linha = IntegerToString(ContadorBook, 7, '0') + ";" + Horario + ";";  // Rogerio003 DELETADO
                  Linha = IntegerToString(gContadorBook, 7, '0')                   + ";"; // Rogerio003 ADICIONADO
                  Linha+= StringSubstr(Horario,0,10)                               + ";"; // Rogerio003 ADICIONADO
                  Linha+= StringSubstr(Horario,11,12)                              + ";"; // Rogerio003 ADICIONADO
                  Linha = Linha + DoubleToString(Leitura[0].QuantidadeCompra, 0)   + ";";
                  Linha = Linha + DoubleToString(Leitura[0].PrecoCompra, Digits()) + ";"; // Rogerio003 Modificado para decimais variáveis
                  Linha = Linha + DoubleToString(Leitura[0].PrecoVenda, Digits())  + ";"; // Rogerio003 Modificado para decimais variáveis
                  Linha = Linha + DoubleToString(Leitura[0].QuantidadeVenda, 0) + ";";
                  Linha = Linha + DoubleToString(Leitura[0].DVBid, 2) + ";";
                  Linha = Linha + DoubleToString(Leitura[0].DVAsk, 2) + ";";
                  Linha = Linha + DoubleToString(Leitura[0].OI, 2) + ";";
                  Linha = Linha + DoubleToString(Leitura[0].M, 2) + ";";
                  Linha = Linha + DoubleToString(Leitura[0].DM, 2) + ";";
                  Linha = Linha + DoubleToString(Leitura[0].OIR, 2) + ";";
                  Linha = Linha + DoubleToString(Leitura[0].TP, 2) + ";";
                  Linha = Linha + DoubleToString(Leitura[0].R, 2) + ";";
                  Linha = Linha + DoubleToString(Leitura[0].S, 2) + ";";
                  FileWrite(gHandlerOferta, Linha);
                 }
              }
        }
      // LOOP BOOK PARTE 2: FIM
     } // Fim do Loop de Extração de dados do Book

//--- Rogerio003 INICIO DELETE
// separador de leituras de Book
//   if(iArquivoBook == LIGADO)
//      FileWrite(HandlerBook, "--------------------------------------------------------------------");
//--- Rogerio003 FIM DELETE

  } // Fim 5) ProcessaDados()

//+------------------------------------------------------------------+
//| 6) AtualizaArrayLeitura() - UPDATE ARRAY PARA RECEBER NOVA LEITURA|
//+------------------------------------------------------------------+
void AtualizaArrayLeitura()
  {
   int Inicio = ArraySize(Leitura) - 1;
// move dados no array
   for(int i = Inicio ; i > 0; i--)
     {
      Leitura[i].PrecoCompra      = Leitura[i - 1].PrecoCompra;
      Leitura[i].PrecoVenda       = Leitura[i - 1].PrecoVenda;
      Leitura[i].QuantidadeCompra = Leitura[i - 1].QuantidadeCompra;
      Leitura[i].QuantidadeVenda  = Leitura[i - 1].QuantidadeVenda;
      Leitura[i].EquacaoM         = Leitura[i - 1].EquacaoM;
      Leitura[i].VolumeDia        = Leitura[i - 1].VolumeDia;
      Leitura[i].VolumeNegociado  = Leitura[i - 1].VolumeNegociado;
      Leitura[i].DVAsk            = Leitura[i - 1].DVAsk;
      Leitura[i].DVBid            = Leitura[i - 1].DVBid;
      Leitura[i].OI               = Leitura[i - 1].OI;
      Leitura[i].M                = Leitura[i - 1].M;
      Leitura[i].DM               = Leitura[i - 1].DM;
      Leitura[i].OIR              = Leitura[i - 1].OIR;
      Leitura[i].TP               = Leitura[i - 1].TP;
      Leitura[i].R                = Leitura[i - 1].R;
      Leitura[i].S                = Leitura[i - 1].S;
     }
  }

//+------------------------------------------------------------------+
//| 7) CalculaMatrizXX() - Calcula a matriz X'X                      |
//+------------------------------------------------------------------+
void CalculaMatrizXX()
  {
   int n, i;
//ignora leituras iniciais
   if(Leitura[0].S == 0)
      return;
// S ao quadrado
   double SQuadrado = MathPow(Leitura[0].S, 2);
// coluna 0 e linha 0
   MatrizXX5[ 0, 0] = (double)gContadorLeitura;
// coluna 0 e linha 13 ==> ∑Rt/St
   MatrizXX5[ 0, 13] += Leitura[0].R / Leitura[0].S;
// coluna 13 e linha 13 ==> ∑(Rt/St)2
   MatrizXX5[13, 13] += MathPow(Leitura[0].R / Leitura[0].S, 2);
   for(n = 0; n <= 5 ; n++)
     {
      // -----------------------------------------------------------------------
      // calculos da linha = coluna
      // -----------------------------------------------------------------------
      // linha 1 a 6 ==> ∑(OI(t-n)/St)2
      MatrizXX5[ n + 1, n + 1] += MathPow(Leitura[n].OI / Leitura[0].S, 2);
      // linha 7 a 12 ==> ∑(OIR(t-n)/St)2
      MatrizXX5[ n + 7, n + 7] += MathPow(Leitura[n].OIR / Leitura[0].S, 2);
      // -----------------------------------------------------------------------
      // calculos da coluna 0
      // -----------------------------------------------------------------------
      // linha 1 a 6 ==> ∑OIt/St
      MatrizXX5[ 0, n + 1] += Leitura[n].OI / Leitura[0].S;
      // linha 7 a 12 ==> ∑OIRt/St
      MatrizXX5[ 0, n + 7] += Leitura[n].OIR / Leitura[0].S;
      // -----------------------------------------------------------------------
      // calculos da colunas 1 a 5 e linhas 2 a 6
      // -----------------------------------------------------------------------
      for(i = n + 1 ; i <= 5 ; i++)
         // ∑(OI(t-n)*OI(t-i))/(St)2
         MatrizXX5[ n + 1, i + 1] += (Leitura[n].OI * Leitura[i].OI) / SQuadrado;
      // -----------------------------------------------------------------------
      // calculos da colunas 1 a 6 e linhas 7 a 12
      // -----------------------------------------------------------------------
      for(i = 0 ; i <= 5 ; i++)
         // ∑(OI(t-n)*OIR(t-i))/(St)2
         MatrizXX5[ n + 1, i + 7] += (Leitura[n].OI * Leitura[i].OIR) / SQuadrado;
      // -----------------------------------------------------------------------
      // calculos da colunas 7 a 11 e linhas 8 a 12
      // -----------------------------------------------------------------------
      for(i = n + 1 ; i <= 5 ; i++)
         // ∑(OIR(t-n)*OIR(t-i))/(St)2
         MatrizXX5[ n + 7, i + 7] += (Leitura[n].OIR * Leitura[i].OIR) / SQuadrado;
      // -----------------------------------------------------------------------
      // calculos da linha 13 - colunas 1 a 12
      // -----------------------------------------------------------------------
      // colunas 1 a 6 ==> ∑(OI(t-n)*Rt)/(St)2
      MatrizXX5[ n + 1, 13] += (Leitura[n].OI * Leitura[0].R) / SQuadrado;
      // colunas 7 a 12 ==> ∑(OIR(t-1)*Rt)/(St)2
      MatrizXX5[ n + 7, 13] += (Leitura[n].OIR * Leitura[0].R) / SQuadrado;
     }
  }

//+------------------------------------------------------------------+
//| 8) CalculaMatrizXY() - Calcula a matriz X'Y                      |
//+------------------------------------------------------------------+
void CalculaMatrizXY()
  {
//ignora leituras iniciais
   if(Leitura[0].S == 0)
      return;
// linha 0 ==> ∑DMt
   MatrizXY5[0] += Leitura[0].DM;
// linha 13 ==> ∑Rt/St*DMt
   MatrizXY5[13] += Leitura[0].R / Leitura[0].S * Leitura[0].DM;
   for(int n = 0 ; n <= 5 ; n++)
     {
      // linhas 1 a 6 ==> ∑OI(t-n)/St*DMt
      MatrizXY5[n + 1] += Leitura[n].OI / Leitura[0].S * Leitura[0].DM;
      // linhas 7 a 12 ==> ∑OIR(t-n)/St*DMt
      MatrizXY5[n + 7] += Leitura[n].OIR / Leitura[0].S * Leitura[0].DM;
     }
  }

//+------------------------------------------------------------------+
//| 9) PegaHorario() - RETORNA HORÁRIO COM MILISEGUNDOS              |
//|    If TRUE:  yy_mm_dd (usado nos nomes de arquivo)               |
//|              (e também verifica TimeTradeServer - Rogerio0006)   |
//|    If FALSE: dd/mm/yy hh:mm:ss.xxx (usado na linhas dos arquivos)|
//+------------------------------------------------------------------+
string PegaHorario(bool FormatoTexto)
  {
   MqlTick tick;
   MqlDateTime now;
   SymbolInfoTick(_Symbol, tick);
   // Rogerio0006 BEGIN: no nome de arquivo, pegar o maior entre Tick e TimeTradeServer (pois antes do pregão abrir, ainda não tem tick no dia)
   if(FormatoTexto)
     TimeToStruct(MathMax(tick.time,TimeTradeServer()), now);
   else
   // Rogerio0006 END
     TimeToStruct(tick.time, now);
   string Ano = IntegerToString(now.year, 2, '0');
   string Mes = IntegerToString(now.mon, 2, '0');
   string Dia = IntegerToString(now.day, 2, '0');
   if(FormatoTexto)
     return (Ano + "_" + Mes + "_" + Dia);
   string Hora = IntegerToString(now.hour, 2, '0');
   string Minuto = IntegerToString(now.min, 2, '0');
   string Segundo = IntegerToString(now.sec, 2, '0');
   //long ms = tick.time_msc;                    // Rogerio003 Delete
   //ms = long(MathMod(ms, (ms / 1000) * 1000)); // Rogerio003 Delete
   string MiliSegundo = IntegerToString(tick.time_msc%1000, 3, '0');
   return (Dia + "/" + Mes + "/" + Ano + " " + Hora + ":" + Minuto + ":" + Segundo + "." + MiliSegundo);
  }

//+------------------------------------------------------------------+
//| 10) SalvaMatrizes() - SALVA MATRIZES EM ARQUIVO                  |
//+------------------------------------------------------------------+
void SalvaMatrizes()
  {
   int    HandlerMatriz;
   //int    Coluna, Linha;
   //string Texto, NomeArquivo;
   string NomeArquivo;
   // calculos de matrizes
   InverteMatrizes();
   // identifica o modo de leitura para usar no nome do arquivo
   if(iTipoLeitura == POR_BOOK)
      NomeArquivo = "MudancaBook";
   if(iTipoLeitura == POR_TIMER)
      NomeArquivo = "IntervaloTempo_" + (string)iMilissegundos + "ms";
   if(iTipoLeitura == POR_TICK)
      NomeArquivo = "MudancaPreco";
   NomeArquivo = StringSubstr(_Symbol, 0, 3) + "_Matrizes_" + NomeArquivo + ".txt";
   Print("Arquivo de MATRIZES criado      : ",NomeArquivo);
// abre o arquivo
   HandlerMatriz = FileOpen(NomeArquivo, FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_TXT | FILE_COMMON);
   FileWrite(HandlerMatriz, "Extraindo dados do ativo " + _Symbol + " - " + (string)TimeCurrent());
   GravaDadosMatrizBidimensional("Matriz X'X Lag 0", HandlerMatriz, MatrizXX0);
   GravaDadosMatrizUnidimensional("Matriz X'Y Lag 0", HandlerMatriz, MatrizXY0);
   GravaDadosMatrizBidimensional("Matriz Invertida Lag 0", HandlerMatriz, MatrizXXInversa0);
   GravaDadosMatrizUnidimensional("Matriz Coeficientes Lag 0", HandlerMatriz, MatrizCoeficientes0);
//--- Gravando a matriz identidade (MatrizXX * MatrizXXInversa) para verificação
//double Identidade0[4,4];
//MatrMulMatr(MatrizXX0, MatrizXXInversa0, Identidade0);
//GravaDadosMatrizBidimensional("Matriz Identidade Lag 0", HandlerMatriz, Identidade0);
   GravaDadosMatrizBidimensional("Matriz X'X Lag 1", HandlerMatriz, MatrizXX1);
   GravaDadosMatrizUnidimensional("Matriz X'Y Lag 1", HandlerMatriz, MatrizXY1);
   GravaDadosMatrizBidimensional("Matriz Invertida Lag 1", HandlerMatriz, MatrizXXInversa1);
   GravaDadosMatrizUnidimensional("Matriz Coeficientes Lag 1", HandlerMatriz, MatrizCoeficientes1);
//double Identidade1[6,6];
//MatrMulMatr(MatrizXX1, MatrizXXInversa1, Identidade1);
//GravaDadosMatrizBidimensional("Matriz Identidade Lag 1", HandlerMatriz, Identidade1);
   GravaDadosMatrizBidimensional("Matriz X'X Lag 2", HandlerMatriz, MatrizXX2);
   GravaDadosMatrizUnidimensional("Matriz X'Y Lag 2", HandlerMatriz, MatrizXY2);
   GravaDadosMatrizBidimensional("Matriz Invertida Lag 2", HandlerMatriz, MatrizXXInversa2);
   GravaDadosMatrizUnidimensional("Matriz Coeficientes Lag 2", HandlerMatriz, MatrizCoeficientes2);
//double Identidade2[8,8];
//MatrMulMatr(MatrizXX2, MatrizXXInversa2, Identidade2);
//GravaDadosMatrizBidimensional("Matriz Identidade Lag 2", HandlerMatriz, Identidade2);
   GravaDadosMatrizBidimensional("Matriz X'X Lag 3", HandlerMatriz, MatrizXX3);
   GravaDadosMatrizUnidimensional("Matriz X'Y Lag 3", HandlerMatriz, MatrizXY3);
   GravaDadosMatrizBidimensional("Matriz Invertida Lag 3", HandlerMatriz, MatrizXXInversa3);
   GravaDadosMatrizUnidimensional("Matriz Coeficientes Lag 3", HandlerMatriz, MatrizCoeficientes3);
//double Identidade3[10,10];
//MatrMulMatr(MatrizXX3, MatrizXXInversa3, Identidade3);
//GravaDadosMatrizBidimensional("Matriz Identidade Lag 3", HandlerMatriz, Identidade3);
   GravaDadosMatrizBidimensional("Matriz X'X Lag 4", HandlerMatriz, MatrizXX4);
   GravaDadosMatrizUnidimensional("Matriz X'Y Lag 4", HandlerMatriz, MatrizXY4);
   GravaDadosMatrizBidimensional("Matriz Invertida Lag 4", HandlerMatriz, MatrizXXInversa4);
   GravaDadosMatrizUnidimensional("Matriz Coeficientes Lag 4", HandlerMatriz, MatrizCoeficientes4);
//double Identidade4[12,12];
//MatrMulMatr(MatrizXX4, MatrizXXInversa4, Identidade4);
//GravaDadosMatrizBidimensional("Matriz Identidade Lag 4", HandlerMatriz, Identidade4);
   GravaDadosMatrizBidimensional("Matriz X'X Lag 5", HandlerMatriz, MatrizXX5);
   GravaDadosMatrizUnidimensional("Matriz X'Y Lag 5", HandlerMatriz, MatrizXY5);
   GravaDadosMatrizBidimensional("Matriz Invertida Lag 5", HandlerMatriz, MatrizXXInversa5);
   GravaDadosMatrizUnidimensional("Matriz Coeficientes Lag 5", HandlerMatriz, MatrizCoeficientes5);
//double Identidade5[14,14];
//MatrMulMatr(MatrizXX5, MatrizXXInversa5, Identidade5);
//GravaDadosMatrizBidimensional("Matriz Identidade Lag 5", HandlerMatriz, Identidade5);
// fecha o arquivo de matrizes
   FileClose(HandlerMatriz);
   Print("Arquivo de MATRIZES fechado");
   int handle_data = INVALID_HANDLE;
   string file_name = GetFileName();
   handle_data = FileOpen(file_name, FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_TXT | FILE_COMMON);
   if(handle_data == INVALID_HANDLE)
     {
      Print("Error writting DATA FILE [" + file_name + "]: " + string(GetLastError()));
      return;
     }
   Print("Arquivo de COEFICIENTES criado  : ",file_name);
   GravaDadosCoeficientes("0", handle_data, MatrizCoeficientes0);
   GravaDadosCoeficientes("1", handle_data, MatrizCoeficientes1);
   GravaDadosCoeficientes("2", handle_data, MatrizCoeficientes2);
   GravaDadosCoeficientes("3", handle_data, MatrizCoeficientes3);
   GravaDadosCoeficientes("4", handle_data, MatrizCoeficientes4);
   GravaDadosCoeficientes("5", handle_data, MatrizCoeficientes5);
   FileClose(handle_data);
   Print("Arquivo de COEFICIENTES fechado");
  }

//+---------------------------------------------------------------------------------------+
//| 11) GravaDadosMatrizBidimensional() - GRAVA DADOS DA MATRIZ DE 2 DIMENSÕES EM ARQUIVO |
//+---------------------------------------------------------------------------------------+
void GravaDadosMatrizBidimensional(string titulo, int handle, double &Matriz[][])
  {
   int lag = ArrayRange(Matriz, 0);
   string texto;
   FileWrite(handle, "-------------------");
   FileWrite(handle, titulo);
   FileWrite(handle, "-------------------");
   for(int i = 0; i < lag; i++)
     {
      texto = "";
      for(int j = 0; j < lag; j++)
        {
         texto += string(Matriz[i, j]) + " ; ";
        }
      FileWrite(handle, texto);
     }
  }


//+------------------------------------------------------------------+
//| 12) InverteMatrizes() - INVERTE E MULTIPLICA MATRIZES            |
//+------------------------------------------------------------------+
void InverteMatrizes()
  {
// espelha a matriz antes de processar
   for(int Linha = 0 ; Linha < 14 ; Linha++)
      for(int Coluna = Linha + 1 ; Coluna < 14 ; Coluna++)
         MatrizXX5[Coluna, Linha] = MatrizXX5[Linha, Coluna];
// carrega demais matrizes conforme seu lag
   CargaMatrixPorLag();
// inverte a matriz
//if (!cholsl(MatrizXX5, MatrizXXInversa5))
//   Print("****** ERRO na MATRIZ!");
   InverteMatrizesAlgLib(MatrizXXInversa0);
   InverteMatrizesAlgLib(MatrizXXInversa1);
   InverteMatrizesAlgLib(MatrizXXInversa2);
   InverteMatrizesAlgLib(MatrizXXInversa3);
   InverteMatrizesAlgLib(MatrizXXInversa4);
   InverteMatrizesAlgLib(MatrizXXInversa5);
// multiplica matriz inversa com a matriz XY
//MultiplicaMatrizes(MatrizXXInversa5, MatrizXY5, MatrizCoeficientes5);
   MultiplicaMatriz(MatrizXXInversa0, MatrizXY0, MatrizCoeficientes0);
   MultiplicaMatriz(MatrizXXInversa1, MatrizXY1, MatrizCoeficientes1);
   MultiplicaMatriz(MatrizXXInversa2, MatrizXY2, MatrizCoeficientes2);
   MultiplicaMatriz(MatrizXXInversa3, MatrizXY3, MatrizCoeficientes3);
   MultiplicaMatriz(MatrizXXInversa4, MatrizXY4, MatrizCoeficientes4);
   MultiplicaMatriz(MatrizXXInversa5, MatrizXY5, MatrizCoeficientes5);
  }

//+---------------------------------------------------------------------------------------+
//| 13) GravaDadosMatrizUnidimensional() - GRAVA DADOS DA MATRIZ DE 1 DIMENSÃO EM ARQUIVO |
//+---------------------------------------------------------------------------------------+
void GravaDadosMatrizUnidimensional(string titulo, int handle, double &Matriz[])
  {
   int lag = ArraySize(Matriz);
   string texto;
   FileWrite(handle, "-------------------");
   FileWrite(handle, titulo);
   FileWrite(handle, "-------------------");
   for(int i = 0; i < lag; i++)
     {
      texto = string(Matriz[i]);
      FileWrite(handle, texto);
     }
  }

//+----------------------------------------------------------------------+
//| 14) GetFileName() - RECEBE NOME DO ARQUIVO BASENADO NO TIPO LEITURA  |
//+----------------------------------------------------------------------+
string GetFileName()
  {
   MqlDateTime now;
   TimeLocal(now);
   string file_name = "";
   if(iTipoLeitura == POR_BOOK)
      file_name = "_book";
   if(iTipoLeitura == POR_TIMER)
      file_name = "_time" + (string)iMilissegundos + "ms";
   if(iTipoLeitura == POR_TICK)
      file_name = "_tick";
   string yymmdd = IntegerToString(now.year, 4, '0') + IntegerToString(now.mon, 2, '0') + IntegerToString(now.day, 2, '0');
   file_name = "coeficientes_" + yymmdd + "_" + StringSubstr(_Symbol, 0, 3) + file_name + ".txt";
   return file_name;
  }

//+------------------------------------------------------------------+
//| 15) GravaDadosCoeficientes() - GRAVA COEFICIENTES                |
//+------------------------------------------------------------------+
void GravaDadosCoeficientes(string tipo, int handle, double &Matriz[])
  {
   int lag = ArraySize(Matriz);
   string texto = tipo;
   for(int i = 0; i < lag; i++)
     {
      texto += "," + string(Matriz[i]);
     }
   FileWrite(handle, texto);
  }

//+------------------------------------------------------------------+
//| 16) CargaMatrixPorLag() - CARREGA MATRIZES POR TIPO DE LAG       |
//+------------------------------------------------------------------+
void CargaMatrixPorLag()
  {
   int x0[LAG0] = {0, 1, 7, 13};
   for(int i = 0; i < LAG0; i++)
     {
      for(int j = 0; j < LAG0; j++)
        {
         MatrizXX0[i, j] = MatrizXX5[x0[i], x0[j]];
         MatrizXXInversa0[i, j] = MatrizXX5[x0[i], x0[j]];
        }
      MatrizXY0[i] = MatrizXY5[x0[i]];
     }
   int x1[LAG1] = {0, 1, 2, 7, 8, 13};
   for(int i = 0; i < LAG1; i++)
     {
      for(int j = 0; j < LAG1; j++)
        {
         MatrizXX1[i, j] = MatrizXX5[x1[i], x1[j]];
         MatrizXXInversa1[i, j] = MatrizXX5[x1[i], x1[j]];
        }
      MatrizXY1[i] = MatrizXY5[x1[i]];
     }
   int x2[LAG2] = {0, 1, 2, 3, 7, 8, 9, 13};
   for(int i = 0; i < LAG2; i++)
     {
      for(int j = 0; j < LAG2; j++)
        {
         MatrizXX2[i, j] = MatrizXX5[x2[i], x2[j]];
         MatrizXXInversa2[i, j] = MatrizXX5[x2[i], x2[j]];
        }
      MatrizXY2[i] = MatrizXY5[x2[i]];
     }
   int x3[LAG3] = {0, 1, 2, 3, 4, 7, 8, 9, 10, 13};
   for(int i = 0; i < LAG3; i++)
     {
      for(int j = 0; j < LAG3; j++)
        {
         MatrizXX3[i, j] = MatrizXX5[x3[i], x3[j]];
         MatrizXXInversa3[i, j] = MatrizXX5[x3[i], x3[j]];
        }
      MatrizXY3[i] = MatrizXY5[x3[i]];
     }
   int x4[LAG4] = {0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 13};
   for(int i = 0; i < LAG4; i++)
     {
      for(int j = 0; j < LAG4; j++)
        {
         MatrizXX4[i, j] = MatrizXX5[x4[i], x4[j]];
         MatrizXXInversa4[i, j] = MatrizXX5[x4[i], x4[j]];
        }
      MatrizXY4[i] = MatrizXY5[x4[i]];
     }
// copia a matriz normal para a inversa
   for(int Linha = 0 ; Linha < 14 ; Linha++)
      for(int Coluna = 0 ; Coluna < 14 ; Coluna++)
         MatrizXXInversa5[Linha, Coluna] = MatrizXX5[Linha, Coluna];
  }

//+------------------------------------------------------------------+
//| 17) InverteMatrizesAlgLib() - INVERTE MATRIZES UTILIZANDO ALGOLIB|
//+------------------------------------------------------------------+
void InverteMatrizesAlgLib(double &MatrizInversa[][])
  {
   CMatInvReportShell rep;
   int info;
   int lag = ArrayRange(MatrizInversa, 0);
   CMatrixDouble MInversa(lag, lag);

   // Rogerio0006 BEGIN: Initialize MInversa
   for(int i=0;i<lag;i++)
     for(int j=0;j<lag;j++)
       MInversa.Set(i,j,0);
   // Rogerio0006 END

   //Print("MatrizInversa:");
   for(int i = 0; i < lag; i++)
     {
      for(int j = 0; j < lag; j++)
        {
         //Print("[",i,"][",j,"]",MatrizInversa[i,j]);
         MInversa[i].Set(j, MatrizInversa[i, j]);
         //MInversa[i].Set(i,j, MatrizInversa[i, j]);
        }
     }
     
   // IMPRIME MInversa ANTES DE INVERTER
   //Print("MInversa:");
   //for(int i=0;i<lag;i++)
   //  for(int j=0;j<lag;j++)
   //    Print("[",i,"][",j,"]",MInversa[i][j]);
          
     
   CAlglib::SPDMatrixInverse(MInversa, info, rep);
   for(int i = 0; i < lag; i++)
     {
      for(int j = 0; j < lag; j++)
        {
         MatrizInversa[i, j] = MInversa[i][j];
        }
     }
  }

//+------------------------------------------------------------------+
//| 18) MultiplicaMatriz() - MULTIPLICA MATRIZES                     |
//+------------------------------------------------------------------+
void MultiplicaMatriz(double &Matriz[][], double &Vetor[], double &Coeficientes[])
  {
   double somaprod;
   int rows1 = ArrayRange(Matriz, 0);
   int cols1 = ArrayRange(Matriz, 1);
   for(int i = 0 ; i < rows1; i++)
     {
      somaprod = 0;
      for(int j = 0 ; j < cols1 ; j++)
        {
         somaprod += Matriz[i, j] * Vetor[j];
        }
      Coeficientes[i] = somaprod;
     }
  }

//+------------------------------------------------------------------+
//| 19) CriaArquivo() - Cria/Abre Arquivos                           |
//+------------------------------------------------------------------+
//void CriaArquivo(bool ArquivoBook, bool ArquivoEquacoes) // Rogerio0006 Delete
void CriaArquivo()                                         // Rogerio0006 Add
  {
   string Descricao, NomeArquivo;

   // identifica o modo de leitura para usar no nome do arquivo
   if (iTipoLeitura == POR_BOOK)  Descricao = "MudancaBook";
   if (iTipoLeitura == POR_TIMER) Descricao = "IntervaloTempo_" + (string)iMilissegundos + "ms";
   if (iTipoLeitura == POR_TICK)  Descricao = "MudancaPreco";

   // arquivo de extração do book   
   // if (ArquivoBook)      // Rogerio0006 Delete
   if(iArquivoBook==LIGADO) // Rogerio0006 Add
     {
      // limpa erros
      ResetLastError();

      // fecha arquivo aberto 
      if (gHandlerBook != INVALID_HANDLE)
         {
         FileClose(gHandlerBook);
         Print("Arquivo de BOOK fechado");
         gHandlerBook = INVALID_HANDLE;
         }
         
      // verifica se deve abrir arquivo novo
      // if (iArquivoBook == LIGADO) // Rogerio0006 Delete: Redundante
        {
         NomeArquivo = PegaHorario(true) + "_" + _Symbol + "_DadosBook_" + Descricao + ".csv";
         //Print("Extraindo dados de BOOK para    : " ,NomeArquivo); // Rogerio0006 Delete: Redundante
         
         // abre o arquivo
         gHandlerBook = FileOpen(NomeArquivo, FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_TXT | FILE_COMMON);
         // Rogerio0006 BEGIN
         if(gHandlerBook==INVALID_HANDLE)
           Print("Erro ao abrir arquivo de book");
         else
           {
            Print("Arquivo de BOOK criado          : ",NomeArquivo);
         // Rogerio0006 END
         //--- Rogerio003 INICIO MODIFICAÇÃO
         //FileWrite(HandlerBook, "Extraindo dados do ativo " + _Symbol);
         //FileWrite(HandlerBook, "Leitura   Data       Hora         Tipo               Preço    Volume");
            FileWrite(gHandlerBook,"Leitura;Hora;Tipo;Preço;Volume");
           }
         //--- Rogerio003 FIM MODIFICAÇÃO
         
         // inicializa contador de extração
         gContadorBook = 0;
        }
     } // END iArquivoBook==LIGADO
   
   // arquivo de extração de equações
   //if (ArquivoEquacoes)       // Rogerio0006 Delete
   if(iArquivoEquacoes==LIGADO) // Rogerio0006 Add
     {
      // limpa erros
      ResetLastError();
      
      // fecha arquivo aberto
      if (gHandlerOferta != INVALID_HANDLE)
         {
         FileClose(gHandlerOferta);
         Print("Arquivo de EQUAÇÕES fechado");
         gHandlerOferta = INVALID_HANDLE;
         }
         
      // verifica se deve abrir arquivo novo
      //if (iArquivoEquacoes == LIGADO) // Rogerio0006 DELETE: Redundante
        {
         NomeArquivo = PegaHorario(true) + "_" + _Symbol + "_Equacoes_" + Descricao + ".csv";
         // Print("Extraindo dados de EQUAÇÕES para: ", NomeArquivo); // Rogerio0006 DELETE: Redundante
         
         // abre o arquivo
         gHandlerOferta = FileOpen(NomeArquivo, FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI | FILE_CSV | FILE_COMMON,";"); 
         // Print("HandleOferta Criação: ", gHandlerOferta); // Rogerio0006 DELETE
         // Rogerio0006 BEGIN
         if(gHandlerOferta==INVALID_HANDLE)
           Print("Erro ao abrir arquivo de equações");
         else
           {
            Print("Arquivo de EQUAÇÕES criado      : ",NomeArquivo);
         // Rogerio0006 END
            FileWrite(gHandlerOferta, "Leitura;Data;Hora;QtdeCompra;PreçoCompra;PreçoVenda;QtdeVenda;DVBid;DVAsk;OI;M;DM;OIR;TP;R;S");
           }     
        } // iArquivoEquacoes LIGADO
     } // iArquivoEquacoes==LIGADO
  } // CriaArquivo()

//+------------------------------------------------------------------+
//| 20) FUNÇÃO QUE INFORMA O MOTIVO DAS PARADAS DO EA                |
//+------------------------------------------------------------------+
void infoLeavingEA(int reason)
  {
   switch(reason)
     {
      case  0:
         Print("O Expert Advisor parou seu trabalho chamando a função ExpertRemove(). ");
         break;
      case  1:
         Print("Programa excluído do gráfico. ");
         break;
      case  2:
         Print("Programa recompilado. ");
         break;
      case  3:
         Print("Símbolo ou período alterado. ");
         break;
      case  4:
         Print("Gráfico fechado. ");
         break;
      case  5:
         Print("Parâmetros de entrada alterados pelo usuário. ");
         break;
      case  6:
         Print("Outra conta ativada ou reconectada ao servidor de negociação como resultado da alteração das configurações da conta. ");
         break;
      case  7:
         Print("Outro modelo de gráfico implementado. ");
         break;
      case  8:
         Print("Manipulador de OnInit() retornou um valor diferente de zero. ");
         break;
      case  9:
         Print("Terminal fechado. ");
         break;
      default:
         Print("O EA apresentou um erro desconhecido. ");
         break;
     }
  }
//+------------------------------------------------------------------+
