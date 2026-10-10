#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0

// ==========================================
// Professional FVG Indicator for MT5
// ==========================================
// Features:
// - Multi-timeframe FVG detection (H4, D1, W1, MN1)
// - Bullish / bearish colors
// - Exhausted FVG colors
// - Min gap filter
// - Optimized drawing with limited zones
// - Clean chart rendering without excessive load
// ==========================================

input int     MaxBarsToScan          = 220;                 // How many recent bars to scan
input int     MaxFVGPerTF            = 25;                  // Maximum zones per timeframe
input double  MinGapPoints           = 0.0;                 // Minimum FVG size in points (0 = off)
input bool    ShowBullishFVG         = true;                // Show bullish FVG
input bool    ShowBearishFVG         = true;                // Show bearish FVG
input bool    HighlightExhausted     = true;                // Highlight exhausted FVG
input bool    FillZones              = true;                // Fill zones
input int     FillAlpha              = 85;                  // Fill transparency (0..255)
input int     BorderWidth            = 1;                   // Border width
input int     ExhaustionBars         = 60;                  // Bars ahead to check if zone was exhausted
input bool    UseCurrentTF           = false;               // Draw also on current chart TF

// ==========================================
// Current timeframe colors
// ==========================================
input color   BullishColor           = clrDodgerBlue;       // Bullish FVG color
input color   BearishColor           = clrTomato;           // Bearish FVG color
input color   ExhaustedBullishColor  = clrLimeGreen;        // Exhausted bullish FVG color
input color   ExhaustedBearishColor  = clrDarkOrange;       // Exhausted bearish FVG color

// ==========================================
// Multi-TF colors
// ==========================================
input bool    ShowTF_H4              = true;                // Show H4 FVG
input bool    ShowTF_D1              = true;                // Show D1 FVG
input bool    ShowTF_W1              = true;                // Show W1 FVG
input bool    ShowTF_MN1             = false;               // Show MN1 FVG

input color   TF_H4_BullColor        = clrSkyBlue;
input color   TF_H4_BearColor        = clrTomato;
input color   TF_H4_ExBullColor      = clrLimeGreen;
input color   TF_H4_ExBearColor      = clrDarkOrange;

input color   TF_D1_BullColor        = clrDeepSkyBlue;
input color   TF_D1_BearColor        = clrFireBrick;
input color   TF_D1_ExBullColor      = clrLimeGreen;
input color   TF_D1_ExBearColor      = clrOrangeRed;

input color   TF_W1_BullColor        = clrGoldenrod;
input color   TF_W1_BearColor        = clrOrangeRed;
input color   TF_W1_ExBullColor      = clrLimeGreen;
input color   TF_W1_ExBearColor      = clrDarkOrange;

input color   TF_MN1_BullColor       = clrSlateGray;
input color   TF_MN1_BearColor       = clrLightCoral;
input color   TF_MN1_ExBullColor     = clrLimeGreen;
input color   TF_MN1_ExBearColor     = clrDarkOrange;

const string gPrefix = "FVG_";

int OnInit()
{
   ObjectsDeleteAll(0, gPrefix);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, gPrefix);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < 4)
      return(rates_total);

   DrawAllFVG();
   return(rates_total);
}

void DrawAllFVG()
{
   ObjectsDeleteAll(0, gPrefix);

   if(MaxBarsToScan <= 0)
      return;

   if(UseCurrentTF)
      DrawTimeframe(_Period, BullishColor, BearishColor, ExhaustedBullishColor, ExhaustedBearishColor);

   if(ShowTF_H4)
      DrawTimeframe(PERIOD_H4, TF_H4_BullColor, TF_H4_BearColor, TF_H4_ExBullColor, TF_H4_ExBearColor);

   if(ShowTF_D1)
      DrawTimeframe(PERIOD_D1, TF_D1_BullColor, TF_D1_BearColor, TF_D1_ExBullColor, TF_D1_ExBearColor);

   if(ShowTF_W1)
      DrawTimeframe(PERIOD_W1, TF_W1_BullColor, TF_W1_BearColor, TF_W1_ExBullColor, TF_W1_ExBearColor);

   if(ShowTF_MN1)
      DrawTimeframe(PERIOD_MN1, TF_MN1_BullColor, TF_MN1_BearColor, TF_MN1_ExBullColor, TF_MN1_ExBearColor);
}

void DrawTimeframe(ENUM_TIMEFRAMES tf,
                  const color bullColor,
                  const color bearColor,
                  const color bullExhaustedColor,
                  const color bearExhaustedColor)
{
   int barsTotal = iBars(_Symbol, tf);
   if(barsTotal < 4)
      return;

   int scannedBars = MathMin(MaxBarsToScan, barsTotal - 2);
   int count = 0;

   for(int idx = 0; idx < scannedBars && count < MaxFVGPerTF; idx++)
   {
      if(ShowBullishFVG)
      {
         double zoneTop = 0.0;
         double zoneBottom = 0.0;
         datetime timeLeft = 0;
         datetime timeRight = 0;

         if(IsBullishFVG(tf, idx, zoneTop, zoneBottom, timeLeft, timeRight))
         {
            double gapSize = MathAbs(zoneTop - zoneBottom);
            if(gapSize < MinGapPoints * _Point && MinGapPoints > 0.0)
               continue;

            bool exhausted = HighlightExhausted && IsZoneExhausted(tf, idx, true, zoneBottom, zoneTop);
            color zoneColor = exhausted ? bullExhaustedColor : bullColor;
            CreateFVGObject(tf, true, idx, timeLeft, timeRight, zoneTop, zoneBottom, zoneColor);
            count++;
            if(count >= MaxFVGPerTF)
               break;
         }
      }

      if(ShowBearishFVG)
      {
         double zoneTop = 0.0;
         double zoneBottom = 0.0;
         datetime timeLeft = 0;
         datetime timeRight = 0;

         if(IsBearishFVG(tf, idx, zoneTop, zoneBottom, timeLeft, timeRight))
         {
            double gapSize = MathAbs(zoneTop - zoneBottom);
            if(gapSize < MinGapPoints * _Point && MinGapPoints > 0.0)
               continue;

            bool exhausted = HighlightExhausted && IsZoneExhausted(tf, idx, false, zoneBottom, zoneTop);
            color zoneColor = exhausted ? bearExhaustedColor : bearColor;
            CreateFVGObject(tf, false, idx, timeLeft, timeRight, zoneTop, zoneBottom, zoneColor);
            count++;
            if(count >= MaxFVGPerTF)
               break;
         }
      }
   }
}

bool IsBullishFVG(ENUM_TIMEFRAMES tf,
                  const int idx,
                  double &zoneTop,
                  double &zoneBottom,
                  datetime &leftTime,
                  datetime &rightTime)
{
   if(idx + 2 >= iBars(_Symbol, tf))
      return(false);

   double currentLow = iLow(_Symbol, tf, idx);
   double earlierHigh = iHigh(_Symbol, tf, idx + 2);

   if(currentLow <= earlierHigh)
      return(false);

   zoneTop = currentLow;
   zoneBottom = earlierHigh;
   leftTime = iTime(_Symbol, tf, idx + 2);
   rightTime = iTime(_Symbol, tf, idx);
   return(true);
}

bool IsBearishFVG(ENUM_TIMEFRAMES tf,
                  const int idx,
                  double &zoneTop,
                  double &zoneBottom,
                  datetime &leftTime,
                  datetime &rightTime)
{
   if(idx + 2 >= iBars(_Symbol, tf))
      return(false);

   double currentHigh = iHigh(_Symbol, tf, idx);
   double earlierLow = iLow(_Symbol, tf, idx + 2);

   if(currentHigh >= earlierLow)
      return(false);

   zoneTop = earlierLow;
   zoneBottom = currentHigh;
   leftTime = iTime(_Symbol, tf, idx + 2);
   rightTime = iTime(_Symbol, tf, idx);
   return(true);
}

bool IsZoneExhausted(ENUM_TIMEFRAMES tf,
                    const int idx,
                    const bool bullish,
                    const double zoneBottom,
                    const double zoneTop)
{
   int barsLimit = iBars(_Symbol, tf);
   if(barsLimit <= idx + 1)
      return(false);

   int checkUntil = MathMin(barsLimit - 1, idx + ExhaustionBars);

   for(int j = idx + 1; j <= checkUntil; j++)
   {
      double closePrice = iClose(_Symbol, tf, j);

      if(bullish)
      {
         if(closePrice <= zoneBottom)
            return(true);
      }
      else
      {
         if(closePrice >= zoneTop)
            return(true);
      }
   }

   return(false);
}

void CreateFVGObject(ENUM_TIMEFRAMES tf,
                     const bool bullish,
                     const int idx,
                     const datetime timeLeft,
                     const datetime timeRight,
                     const double zoneTop,
                     const double zoneBottom,
                     const color objColor)
{
   string name = StringFormat("%sTF%d_%s_%d", gPrefix, (int)tf, bullish ? "B" : "S", idx);
   if(ObjectFind(0, name) >= 0)
      return;

   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, timeLeft, zoneTop, timeRight, zoneBottom))
      return;

   ObjectSetInteger(0, name, OBJPROP_BACK, 1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, 0);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, 0);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, 1);
   ObjectSetInteger(0, name, OBJPROP_COLOR, objColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, BorderWidth);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);

   if(FillZones)
   {
      ObjectSetInteger(0, name, OBJPROP_FILL, 1);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, ColorToARGB(objColor, FillAlpha));
   }
   else
   {
      ObjectSetInteger(0, name, OBJPROP_FILL, 0);
   }
}

color ColorToARGB(const color inputColor, const int alpha)
{
   int a = alpha;
   if(a < 0) a = 0;
   if(a > 255) a = 255;
   return((color)((a << 24) | (inputColor & 0x00FFFFFF)));
}
