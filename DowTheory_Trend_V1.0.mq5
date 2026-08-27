//+------------------------------------------------------------------+
//|                                        DowTheory_Trend_V1.0.mq5  |
//|  EA converted from DowTheory_Trend_V1.0.pine (Pine Script v6)    |
//|                                                                  |
//|  ระบบ Frame Break (สไตล์ SessionBreak แต่กรอบ = Dow frame):        |
//|  - กรอบ = LL->HH (bull) หรือ HH->LL (bear), strict adjacency      |
//|    2-swing (swing อื่นแทรก = กรอบไม่ถูกนับ)                        |
//|  - กรอบ confirm -> arm รอเบรค OCO 2 ฝั่ง: เบรคขึ้นผ่าน HH = BUY,   |
//|    เบรคลงผ่าน LL = SELL (ทิศเทรดตามทิศเบรค)                       |
//|  - Entry Mode: 1. Breakout = fill ทันทีที่เบรค                     |
//|                2. Pullback = เบรคแล้วรอราคาถอยมาแตะ level ในกรอบ   |
//|  - กรอบใหม่ confirm -> ยกเลิก pending + ปิด position เดิมทั้งหมด    |
//|    (ไม่มี expiry — ทางเดียวที่ยกเลิกคือกรอบใหม่)                    |
//|  - Reverse Trade (fade the break), Recovery Mode (เปิดสวน/ตามทันที |
//|    เมื่อไม้หลักโดน SL), 1R Basis (SL% / Distance / ATR)            |
//|                                                                  |
//|  ต่างจากเวอร์ชัน Pine (โดยตั้งใจ):                                 |
//|  - เบรค/fill ตรวจแบบ tick-based (รู้ลำดับจริง จึงไม่ต้องมีกฎ        |
//|    "แท่งเบรคห้าม fill" และไม่มีเคส "เบรคสองฝั่งพร้อมกัน")           |
//|  - Spread ใช้ bid/ask จริงของโบรกเกอร์ (ไม่มี input spread)         |
//+------------------------------------------------------------------+
#property copyright "Dow Theory EA"
#property version   "1.00"

#include <Trade/Trade.mqh>

//=== Enums ==========================================================
enum ENUM_ENTRY_MODE
  {
   MODE_BREAKOUT = 0,   // 1. Breakout (fill ทันทีที่เบรคกรอบ)
   MODE_PULLBACK = 1    // 2. Pullback (เบรคแล้วรอถอยมาแตะ level)
  };
enum ENUM_PB_MODE
  {
   PB_OF_PRICE = 0,     // % of Price
   PB_OF_RANGE = 1      // % of Range (HH-LL)
  };
enum ENUM_ONER_BASIS
  {
   ONER_SLPCT = 0,      // SL% (% ของช่วงกรอบ HH-LL)
   ONER_DIST  = 1,      // Distance (ระยะคงที่)
   ONER_ATR   = 2       // ATR x Multiplier
  };
enum ENUM_REC_DIR
  {
   REC_SAME    = 0,     // Same (ทิศเดียวกับไม้เดิม)
   REC_REVERSE = 1      // Reverse (สวนทิศไม้เดิม)
  };

//=== Inputs =========================================================
input group "Swing Detection"
input int              InpLeftRight       = 3;      // Swing Left/Right Bars (Fractal)
input int              InpWarmupBars      = 300;    // Warm-up Lookback Bars

input group "Entry"
input bool             InpEnableEntry     = true;         // Enable Frame Break Entries
input ENUM_ENTRY_MODE  InpEntryMode       = MODE_PULLBACK; // Entry Mode
input ENUM_PB_MODE     InpPullbackMode    = PB_OF_RANGE;  // Pullback Mode (Mode 2)
input double           InpPullbackPct     = 0.4;    // [% of Price] Pullback %
input double           InpPullbackRangePct= 30.0;   // [% of Range] Pullback %
input bool             InpReverseTrade    = false;  // Reverse Trade (fade the break)

input group "Recovery Mode"
input bool             InpUseRecovery     = false;      // Enable Recovery
input ENUM_REC_DIR     InpRecDir          = REC_REVERSE; // Recovery Direction
input double           InpRecRR           = 1.5;        // Recovery R:R

input group "Risk Management"
input ENUM_ONER_BASIS  InpOneRBasis       = ONER_SLPCT; // 1R Basis
input double           InpOneRPct         = 20.0;   // [SL%] 1R = % of Frame Range
input double           InpOneRDist        = 5.0;    // [Distance] 1R = Fixed Distance (price)
input int              InpAtrPeriod       = 14;     // [ATR] Period
input double           InpAtrMult         = 1.5;    // [ATR] Multiplier
input double           InpRiskAmount      = 500.0;  // Risk per 1R ($)
input double           InpRR              = 2.0;    // Risk : Reward (R:R)
input bool             InpUseMoneyLot     = true;   // Lot จาก Tick Value จริง (ปิด = ใช้ 1 Lot Ratio แบบ Pine)
input double           InpPipValueRatio   = 100.0;  // 1 Lot Ratio (ใช้เมื่อปิด Money Lot)

input group "General"
input long             InpMagic           = 20250827; // Magic Number
input bool             InpDrawObjects     = true;     // Draw Chart Objects
input bool             InpShowPanel       = true;     // Show Info Panel (Comment)
input bool             InpAlerts          = false;    // Enable Alerts

//=== Globals ========================================================
CTrade   trade;
int      g_atrHandle = INVALID_HANDLE;
datetime g_lastBarTime = 0;

// --- Swing tracker (strict adjacency ผ่าน g_lastSwing ตัวเดียว) ---
string   g_lastSwing = "";          // "HH"/"LH"/"HL"/"LL" — swing ล่าสุด (ทุกฝั่ง)
double   g_lastSwingHighVal = 0.0;  // ราคา swing high ล่าสุด (ใช้เทียบ HH/LH)
int      g_swHighCount = 0;
double   g_lastSwingLowVal = 0.0;   // ราคา swing low ล่าสุด (ใช้เทียบ HL/LL)
int      g_swLowCount = 0;

// --- HH/LL ล่าสุด (ใช้เป็นขอบกรอบ) ---
double   g_hhPrice = 0.0;  bool g_hasHH = false;  datetime g_hhTime = 0;
double   g_llPrice = 0.0;  bool g_hasLL = false;  datetime g_llTime = 0;

// --- Trend state (จาก 2 swing highs + 2 swing lows ล่าสุด) ---
double   g_h1 = 0, g_h2 = 0;  datetime g_h1T = 0, g_h2T = 0;
double   g_l1 = 0, g_l2 = 0;  datetime g_l1T = 0, g_l2T = 0;

// --- Frame state machine ---
int      g_state = 0;        // 0 = ไม่มีกรอบ, 1 = armed รอเบรค, 2 = เบรคแล้วรอ pullback
int      g_brkDir = 0;       // 1 = เบรคขึ้น, -1 = เบรคลง
double   g_frameHigh = 0.0;
double   g_frameLow = 0.0;
string   g_frameTag = "";
double   g_pbLevel = 0.0;
bool     g_fillOnLow = false; // true = fill เมื่อราคาลงมาแตะ (หลังเบรคขึ้น)
datetime g_frameTime = 0;     // เวลาที่กรอบ arm (ใช้วาดเส้น)

// --- Position record (EA ถือได้ทีละ 1 ไม้) ---
bool     g_posOpen = false;
ulong    g_posTicket = 0;
int      g_posDir = 0;
double   g_posOneR = 0.0;
double   g_posRiskMoney = 0.0;
bool     g_posIsRecovery = false;

// --- Stats ---
int      g_trades = 0, g_wins = 0, g_losses = 0;
double   g_netR = 0.0;

const string OBJ_PREFIX = "DT_";

//=== Utility: drawing ==============================================
void DrawTrend(const string name, datetime t1, double p1, datetime t2, double p2,
               color clr, ENUM_LINE_STYLE style, int width, bool ray)
  {
   if(!InpDrawObjects) return;
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, ray);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
  }

void DrawText(const string name, datetime t, double p, const string txt, color clr, bool above)
  {
   if(!InpDrawObjects) return;
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, above ? ANCHOR_LOWER : ANCHOR_UPPER);
  }

void DrawBox(const string name, datetime t1, double p1, datetime t2, double p2, color clr)
  {
   if(!InpDrawObjects) return;
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, name, OBJPROP_FILL, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
  }

void DeleteFrameObjects()
  {
   ObjectDelete(0, OBJ_PREFIX + "FRH");
   ObjectDelete(0, OBJ_PREFIX + "FRL");
   ObjectDelete(0, OBJ_PREFIX + "PB");
  }

//=== Utility: 1R distance ==========================================
double OneRDist()
  {
   double range = g_frameHigh - g_frameLow;
   if(InpOneRBasis == ONER_DIST)
      return InpOneRDist;
   if(InpOneRBasis == ONER_ATR)
     {
      double buf[1];
      if(g_atrHandle == INVALID_HANDLE || CopyBuffer(g_atrHandle, 0, 1, 1, buf) < 1)
         return 0.0;
      return buf[0] * InpAtrMult;
     }
   return range * (InpOneRPct / 100.0);   // SL%
  }

//=== Utility: lot sizing ===========================================
double CalcLot(double oneR)
  {
   if(oneR <= 0.0) return 0.0;
   double lossPerLot;
   if(InpUseMoneyLot)
     {
      double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickVal <= 0.0 || tickSize <= 0.0) return 0.0;
      lossPerLot = oneR / tickSize * tickVal;
     }
   else
      lossPerLot = oneR * InpPipValueRatio;
   if(lossPerLot <= 0.0) return 0.0;
   double lot = InpRiskAmount / lossPerLot;
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step > 0.0) lot = MathFloor(lot / step) * step;
   if(lot < vmin) lot = vmin;
   if(lot > vmax) lot = vmax;
   return lot;
  }

// เงินที่เสียจริงถ้า SL hit (ใช้คิด R ใน stats)
double RiskMoneyOf(double lot, double slDist)
  {
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0.0 || tickSize <= 0.0) return 0.0;
   return lot * slDist / tickSize * tickVal;
  }

//=== Trading =======================================================
bool SelectOurPosition(ulong &ticket)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
         ticket = tk;
         return true;
        }
     }
   return false;
  }

void OpenTrade(int dir, double oneR, bool isRecovery, double rr, const string tag)
  {
   if(oneR <= 0.0)
     {
      Print("OpenTrade skipped: oneR <= 0");
      return;
     }
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = dir > 0 ? ask : bid;
   double sl = dir > 0 ? price - oneR : price + oneR;
   double tp = dir > 0 ? price + oneR * rr : price - oneR * rr;
   // กันระยะ SL/TP แคบกว่า stops level ของโบรกเกอร์
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(minDist > 0.0)
     {
      if(MathAbs(price - sl) < minDist)
         sl = dir > 0 ? price - minDist : price + minDist;
      if(MathAbs(price - tp) < minDist)
         tp = dir > 0 ? price + minDist : price - minDist;
     }
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   double lot = CalcLot(oneR);
   if(lot <= 0.0)
     {
      Print("OpenTrade skipped: lot <= 0");
      return;
     }
   bool ok = dir > 0
             ? trade.Buy(lot, _Symbol, 0.0, sl, tp, tag)
             : trade.Sell(lot, _Symbol, 0.0, sl, tp, tag);
   uint rc = trade.ResultRetcode();
   if(!ok || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_DONE_PARTIAL))
     {
      PrintFormat("OpenTrade FAILED: dir=%d retcode=%d (%s)", dir,
                  trade.ResultRetcode(), trade.ResultRetcodeDescription());
      return;
     }
   double fillPrice = trade.ResultPrice();
   if(fillPrice <= 0.0) fillPrice = price;
   g_posOpen       = true;
   g_posDir        = dir;
   g_posOneR       = oneR;
   g_posIsRecovery = isRecovery;
   g_posRiskMoney  = RiskMoneyOf(lot, MathAbs(fillPrice - sl));
   ulong tk = 0;
   if(SelectOurPosition(tk)) g_posTicket = tk;
   PrintFormat("%s %s lot=%.2f @%.5f SL=%.5f TP=%.5f (%s)",
               isRecovery ? "RECOVERY" : "OPEN", dir > 0 ? "BUY" : "SELL",
               lot, fillPrice, sl, tp, tag);
   if(InpAlerts)
      Alert(StringFormat("%s: %s %s @ %.5f", _Symbol,
            dir > 0 ? "BUY" : "SELL", tag, fillPrice));
  }

void CloseOurPosition(const string reason)
  {
   ulong tk = 0;
   if(!SelectOurPosition(tk)) return;
   if(!trade.PositionClose(tk))
      PrintFormat("PositionClose FAILED: %d (%s)",
                  trade.ResultRetcode(), trade.ResultRetcodeDescription());
   else
      Print("Position closed: ", reason);
  }

//=== Frame state machine ===========================================
void CancelFrame(const string reason)
  {
   if(g_state == 0) return;
   Print("CANCEL FRAME (", reason, ")");
   g_state = 0;
   g_brkDir = 0;
   g_pbLevel = 0.0;
   DeleteFrameObjects();
  }

void ArmFrame(bool isBull, datetime confirmTime)
  {
   g_frameHigh = g_hhPrice;
   g_frameLow  = g_llPrice;
   g_frameTag  = isBull ? "LL->HH" : "HH->LL";
   g_frameTime = confirmTime;
   g_state  = 1;
   g_brkDir = 0;
   g_pbLevel = 0.0;
   // เส้นขอบบน/ล่าง + กล่องกรอบ
   DrawTrend(OBJ_PREFIX + "FRH", g_frameTime, g_frameHigh, g_frameTime + PeriodSeconds() * 20,
             g_frameHigh, clrDodgerBlue, STYLE_DASH, 2, true);
   DrawTrend(OBJ_PREFIX + "FRL", g_frameTime, g_frameLow, g_frameTime + PeriodSeconds() * 20,
             g_frameLow, clrRed, STYLE_DASH, 2, true);
   datetime bt = isBull ? g_llTime : g_hhTime;
   DrawBox(OBJ_PREFIX + "BOX_" + TimeToString(g_frameTime, TIME_DATE | TIME_MINUTES),
           bt, g_frameHigh, g_frameTime, g_frameLow, isBull ? clrLime : clrRed);
   PrintFormat("FRAME %s armed: HH=%.5f LL=%.5f", g_frameTag, g_frameHigh, g_frameLow);
   if(InpAlerts)
      Alert(StringFormat("%s: FRAME %s armed (break %.5f = BUY / %.5f = SELL)",
            _Symbol, g_frameTag, g_frameHigh, g_frameLow));
  }

// กรอบใหม่ confirm: ปิดทุกอย่างเก่า -> arm ใหม่
void OnNewFrame(bool isBull, bool liveTrading, datetime confirmTime)
  {
   if(liveTrading && g_posOpen)
      CloseOurPosition("New Frame");   // ผล/stats บันทึกผ่าน OnTradeTransaction
   CancelFrame("new frame");
   ArmFrame(isBull, confirmTime);
  }

// เบรคกรอบ (จาก tick หรือจาก warm-up แบบแท่ง)
void DoBreak(int dir, bool liveTrading)
  {
   g_brkDir = dir;
   double brkLev = dir > 0 ? g_frameHigh : g_frameLow;
   if(InpEntryMode == MODE_BREAKOUT)
     {
      if(liveTrading)
        {
         int tdir = InpReverseTrade ? -dir : dir;
         string tag = g_frameTag + (dir > 0 ? " ^" : " v") + (InpReverseTrade ? " REV" : "");
         OpenTrade(tdir, OneRDist(), false, InpRR, tag);
        }
      g_state = 0;
      g_brkDir = 0;
      DeleteFrameObjects();
     }
   else
     {
      double range = g_frameHigh - g_frameLow;
      double pbDist = (InpPullbackMode == PB_OF_RANGE)
                      ? range * (InpPullbackRangePct / 100.0)
                      : brkLev * (InpPullbackPct / 100.0);
      g_pbLevel   = dir > 0 ? g_frameHigh - pbDist : g_frameLow + pbDist;
      g_fillOnLow = (dir > 0);
      g_state = 2;
      ObjectDelete(0, OBJ_PREFIX + "FRH");
      ObjectDelete(0, OBJ_PREFIX + "FRL");
      DrawTrend(OBJ_PREFIX + "PB", iTime(_Symbol, _Period, 0), g_pbLevel,
                iTime(_Symbol, _Period, 0) + PeriodSeconds() * 20, g_pbLevel,
                clrMagenta, STYLE_DOT, 2, true);
      PrintFormat("BREAK %s %s -> wait pullback @ %.5f",
                  dir > 0 ? "UP" : "DOWN", g_frameTag, g_pbLevel);
      if(InpAlerts)
         Alert(StringFormat("%s: Break %s — wait pullback @ %.5f",
               _Symbol, dir > 0 ? "UP" : "DOWN", g_pbLevel));
     }
  }

//=== Pivot / swing processing (เรียกเมื่อแท่ง c ปิด; c=1 สำหรับ live) ===
void ProcessClosedBar(int c, bool liveTrading)
  {
   int lr = InpLeftRight;
   int p  = c + lr;                       // pivot candidate shift
   int bars = Bars(_Symbol, _Period);
   if(p + lr >= bars) return;

   // --- ตรวจ pivot high/low ที่ shift p (strict > / <) ---
   double hp = iHigh(_Symbol, _Period, p);
   double lp = iLow(_Symbol, _Period, p);
   if(hp <= 0.0 || lp <= 0.0) return;   // history ยังโหลดไม่ครบ
   bool isPH = true, isPL = true;
   for(int k = 1; k <= lr; k++)
     {
      if(hp <= iHigh(_Symbol, _Period, p - k) || hp <= iHigh(_Symbol, _Period, p + k))
         isPH = false;
      if(lp >= iLow(_Symbol, _Period, p - k) || lp >= iLow(_Symbol, _Period, p + k))
         isPL = false;
      if(!isPH && !isPL) break;
     }

   datetime pt = iTime(_Symbol, _Period, p);

   // --- จัดประเภท (เทียบ swing เดียวกันก่อนหน้า) ---
   string newHighType = "", newLowType = "";
   bool newHighConf = false, newLowConf = false;
   if(isPH)
     {
      if(g_swHighCount >= 1)
        {
         newHighConf = true;
         newHighType = (hp > g_lastSwingHighVal) ? "HH" : "LH";
        }
     }
   if(isPL)
     {
      if(g_swLowCount >= 1)
        {
         newLowConf = true;
         newLowType = (lp < g_lastSwingLowVal) ? "LL" : "HL";
        }
     }

   // --- Frame signal (เช็คก่อน update g_lastSwing — เหมือน Pine) ---
   bool bull = InpEnableEntry && newHighConf && newHighType == "HH" && g_lastSwing == "LL";
   bool bear = InpEnableEntry && newLowConf  && newLowType  == "LL" && g_lastSwing == "HH";

   // --- Update state (high ก่อน low — เหมือน Pine) ---
   if(isPH)
     {
      g_h2 = g_h1; g_h2T = g_h1T;
      g_h1 = hp;   g_h1T = pt;
      g_lastSwingHighVal = hp;
      g_swHighCount++;
      if(newHighConf)
        {
         g_lastSwing = newHighType;
         if(newHighType == "HH") { g_hhPrice = hp; g_hhTime = pt; g_hasHH = true; }
         DrawText(OBJ_PREFIX + "SW_" + IntegerToString((long)pt) + "H", pt, hp,
                  newHighType, newHighType == "HH" ? clrLime : clrRed, true);
        }
     }
   if(isPL)
     {
      g_l2 = g_l1; g_l2T = g_l1T;
      g_l1 = lp;   g_l1T = pt;
      g_lastSwingLowVal = lp;
      g_swLowCount++;
      if(newLowConf)
        {
         g_lastSwing = newLowType;
         if(newLowType == "LL") { g_llPrice = lp; g_llTime = pt; g_hasLL = true; }
         DrawText(OBJ_PREFIX + "SW_" + IntegerToString((long)pt) + "L", pt, lp,
                  newLowType, newLowType == "HL" ? clrLime : clrRed, false);
        }
     }

   // --- Trendlines (ต่อ 2 swing lows / 2 swing highs ล่าสุด) ---
   if(g_swLowCount >= 2)
      DrawTrend(OBJ_PREFIX + "UPTL", g_l2T, g_l2, g_l1T, g_l1, clrLime, STYLE_SOLID, 1, true);
   if(g_swHighCount >= 2)
      DrawTrend(OBJ_PREFIX + "DNTL", g_h2T, g_h2, g_h1T, g_h1, clrRed, STYLE_SOLID, 1, true);

   // --- กรอบใหม่: freeze/ยกเลิกของเก่า -> arm ---
   // (bull/bear ไม่มีทางจริงพร้อมกัน: เงื่อนไข g_lastSwing ตัดกันเอง)
   if((bull || bear) && g_hasHH && g_hasLL)
     {
      OnNewFrame(bull, liveTrading, iTime(_Symbol, _Period, c));
      return;   // แท่งที่กรอบใหม่ confirm: ห้ามใช้ high/low แท่งนี้กับกรอบ (freeze)
     }

   // --- Warm-up เท่านั้น: เดิน state ด้วย high/low ของแท่ง c (ไม่ส่งออเดอร์) ---
   // live ไม่ต้องทำ — tick handler จัดการเรียลไทม์อยู่แล้ว
   if(!liveTrading && g_state != 0)
     {
      double bh = iHigh(_Symbol, _Period, c);
      double bl = iLow(_Symbol, _Period, c);
      if(g_state == 1)
        {
         bool up = bh >= g_frameHigh;
         bool dn = bl <= g_frameLow;
         if(up && dn)
            CancelFrame("both sides broken (warm-up)");
         else if(up || dn)
            DoBreak(up ? 1 : -1, false);
        }
      else if(g_state == 2)
        {
         bool hit = g_fillOnLow ? (bl <= g_pbLevel) : (bh >= g_pbLevel);
         if(hit)
           {
            // fill ในอดีต — ไม่เปิดออเดอร์ย้อนหลัง แค่เคลียร์กรอบ (ถือว่าใช้ไปแล้ว)
            Print("Warm-up: pullback level was filled in history — frame consumed");
            g_state = 0;
            g_brkDir = 0;
            DeleteFrameObjects();
           }
        }
     }
  }

//=== Tick-level break / pullback fill ==============================
void ProcessTick()
  {
   if(g_state == 0 || g_posOpen) return;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0) return;
   if(g_state == 1)
     {
      if(bid >= g_frameHigh)
         DoBreak(1, true);
      else if(bid <= g_frameLow)
         DoBreak(-1, true);
     }
   else if(g_state == 2)
     {
      bool hit = g_fillOnLow ? (bid <= g_pbLevel) : (bid >= g_pbLevel);
      if(hit)
        {
         int tdir = InpReverseTrade ? -g_brkDir : g_brkDir;
         string tag = g_frameTag + (g_brkDir > 0 ? " ^PB" : " vPB") + (InpReverseTrade ? " REV" : "");
         OpenTrade(tdir, OneRDist(), false, InpRR, tag);
         g_state = 0;
         g_brkDir = 0;
         DeleteFrameObjects();
        }
     }
  }

//=== Info panel ====================================================
void UpdatePanel()
  {
   if(!InpShowPanel) { Comment(""); return; }
   string trend = "SIDEWAY";
   if(g_swHighCount >= 2 && g_swLowCount >= 2)
     {
      if(g_h1 > g_h2 && g_l1 > g_l2) trend = "UPTREND (HH+HL)";
      else if(g_l1 < g_l2 && g_h1 < g_h2) trend = "DOWNTREND (LL+LH)";
     }
   string st = g_state == 0 ? "no frame" :
               g_state == 1 ? StringFormat("ARMED %s  ^%.5f  v%.5f", g_frameTag, g_frameHigh, g_frameLow) :
                              StringFormat("BROKE %s %s -> pullback @ %.5f", g_frameTag,
                                           g_brkDir > 0 ? "UP" : "DOWN", g_pbLevel);
   string pos = "FLAT";
   if(g_posOpen)
      pos = StringFormat("%s%s oneR=%.5f", g_posDir > 0 ? "LONG" : "SHORT",
                         g_posIsRecovery ? " (Reco)" : "", g_posOneR);
   double wr = (g_wins + g_losses) > 0 ? 100.0 * g_wins / (g_wins + g_losses) : 0.0;
   Comment(StringFormat(
      "Dow Theory Frame Break EA v1.0\nTrend: %s\nMode: %s%s%s\nFrame: %s\nPosition: %s\nTrades: %d  W:%d L:%d  WR: %.1f%%  NetR: %+.2f",
      trend,
      InpEntryMode == MODE_BREAKOUT ? "1. Breakout" : "2. Pullback",
      InpReverseTrade ? "  [REVERSE]" : "",
      InpUseRecovery ? "  [+Recovery]" : "",
      st, pos, g_trades, g_wins, g_losses, wr, g_netR));
  }

//=== MT5 events ====================================================
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFillingBySymbol(_Symbol);   // ใช้ filling mode ที่ symbol/โบรกเกอร์รองรับ
   g_atrHandle = iATR(_Symbol, _Period, InpAtrPeriod);
   if(InpOneRBasis == ONER_ATR && g_atrHandle == INVALID_HANDLE)
     {
      Print("iATR handle failed");
      return INIT_FAILED;
     }
   g_lastBarTime = iTime(_Symbol, _Period, 0);

   // --- Warm-up: ไล่สร้าง swing/frame state จากอดีต (ไม่ส่งออเดอร์) ---
   int bars = Bars(_Symbol, _Period);
   int maxC = MathMin(InpWarmupBars, bars - 2 * InpLeftRight - 2);
   for(int c = maxC; c >= 1; c--)
      ProcessClosedBar(c, false);

   // ถ้ามี position เดิมของ EA ค้างอยู่ (restart) -> รับเป็นของเรา
   ulong tk = 0;
   if(SelectOurPosition(tk))
     {
      g_posOpen = true;
      g_posTicket = tk;
      g_posDir = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      double slp = PositionGetDouble(POSITION_SL);
      g_posOneR = (slp > 0.0) ? MathAbs(op - slp) : 0.0;
      g_posRiskMoney = RiskMoneyOf(PositionGetDouble(POSITION_VOLUME), g_posOneR);
      g_posIsRecovery = (StringFind(PositionGetString(POSITION_COMMENT), "Reco") >= 0);
      Print("Adopted existing position ticket=", (long)tk);
     }
   UpdatePanel();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   Comment("");
   ObjectsDeleteAll(0, OBJ_PREFIX);
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
  }

void OnTick()
  {
   // แท่งใหม่เปิด -> ประมวลผลแท่งที่เพิ่งปิดทั้งหมด (รวมแท่งที่พลาดตอน disconnect)
   datetime bt = iTime(_Symbol, _Period, 0);
   if(bt != g_lastBarTime)
     {
      int firstClosed = iBarShift(_Symbol, _Period, g_lastBarTime, true);
      if(firstClosed < 1) firstClosed = 1;   // ประวัติ reshuffle -> อย่างน้อยแท่งล่าสุด
      g_lastBarTime = bt;
      for(int c = firstClosed; c >= 1; c--)
         ProcessClosedBar(c, true);
     }
   // เบรค / pullback fill แบบ tick-based
   ProcessTick();
   UpdatePanel();
  }

// ตรวจ deal ปิดไม้ของเรา -> stats + Recovery
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagic) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;
   if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                 + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON);

   // snapshot ก่อนเคลียร์ record
   bool wasRec   = g_posIsRecovery;
   int  wasDir   = g_posDir;
   double wasOneR = g_posOneR;
   double riskM  = g_posRiskMoney;

   g_trades++;
   if(profit > 0.0) g_wins++;
   else if(profit < 0.0) g_losses++;
   if(riskM > 0.0) g_netR += profit / riskM;

   g_posOpen = false;
   g_posTicket = 0;
   g_posDir = 0;
   g_posOneR = 0.0;
   g_posRiskMoney = 0.0;
   g_posIsRecovery = false;

   PrintFormat("CLOSED: profit=%.2f reason=%d R=%.2f", profit, (int)reason,
               riskM > 0.0 ? profit / riskM : 0.0);

   // Recovery: ไม้หลักโดน SL -> เปิด recovery ทันที (1 ครั้งต่อไม้หลัก)
   if(reason == DEAL_REASON_SL && profit < 0.0 &&
      InpUseRecovery && !wasRec && wasOneR > 0.0 && wasDir != 0)
     {
      int rdir = (InpRecDir == REC_SAME) ? wasDir : -wasDir;
      OpenTrade(rdir, wasOneR, true, InpRecRR, "Reco");
     }
  }
//+------------------------------------------------------------------+
