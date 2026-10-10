#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0

input int     MaxBarsToScan           = 220;                  // How many recent candles to scan for FVGs
input int     MaxFVGPerTF             = 40;                   // Maximum FVG rectangles per timeframe
input bool    ShowBullishFVG          = true;                 // Draw bullish FVGs
input bool    ShowBearishFVG          = true;                 // Draw bearish FVGs
input bool    HighlightExhausted      = true;                 // Highlight already used FVGs with a different color
input bool    FillZones               = true;                 // Fill the FVG rectangle
input int     FillAlpha              = 85;                   // Fill transparency: 0..255
input int     BorderWidth            = 1;                    // Border width of the FVG zone
input int     ExhaustionBars         = 60;                   // How many bars forward to check whether the FVG was exhausted

input bool    UseCurrentTF            = false;                // Show FVGs on the current chart timeframe too
input color   BullishColor            = clrDodgerBlue;        // Standard bullish FVG color
input color   BearishColor            = clrTomato;            // Standard bearish FVG color
input color   ExhaustedBullishColor   = clrLimeGreen;         // Exhausted bullish FVG color
input color   ExhaustedBearishColor   = clrDarkOrange;        // Exhausted bearish FVG color

input bool    ShowTF_H4               = true;                 // Show FVGs from H4
input bool    ShowTF_D1               = true;                 // Show FVGs from D1
input bool    ShowTF_W1               = true;                 // Show FVGs from W1
input bool    ShowTF_MN1              = false;                // Show FVGs from MN1

input color   TF_H4_BullColor         = clrSkyBlue;           // H4 bullish FVG color
input color   TF_H4_BearColor         = clrTomato;            // H4 bearish FVG color
input color   TF_H4_ExBullColor       = clrLimeGreen;         // H4 exhausted bullish color
input color   TF_H4_ExBearColor       = clrDarkOrange;        // H4 exhausted bearish color

input color   TF_D1_BullColor         = clrDeepSkyBlue;       // D1 bullish FVG color
input color   TF_D1_BearColor         = clrFireBrick;         // D1 bearish FVG color
input color   TF_D1_ExBullColor       = clrLimeGreen;         // D1 exhausted bullish color
input color   TF_D1_ExBearColor       = clrOrangeRed;         // D1 exhausted bearish color

input color   TF_W1_BullColor         = clrGoldenrod;         // W1 bullish FVG color
input color   TF_W1_BearColor         = clrOrangeRed;          // W1 bearish FVG color
input color   TF_W1_ExBullColor       = clrLimeGreen;         // W1 exhausted bullish color
input color   TF_W1_ExBearColor       = clrDarkOrange;        // W1 exhausted bearish color

input color   TF_MN1_BullColor        = clrSlateGray;         // MN1 bullish FVG color
input color   TF_MN1_BearColor        = clrLightCoral;        // MN1 bearish FVG color
input color   TF_MN1_ExBullColor      = clrLimeGreen;         // MN1 exhausted bullish color
input color   TF_MN1_ExBearColor      = clrDarkOrange;        // MN1 exhausted bearish color

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
   {
      DrawTimeframe(_Period, BullishColor, BearishColor, ExhaustedBullishColor, ExhaustedBearishColor);
   }

   if(ShowTF_H4)
      DrawTimeframe(PERIOD_H4, TF_H4_BullColor, TF_H4_BearColor, TF_H4_ExBullColor, TF_H4_ExBearColor);

   if(ShowTF_D1)
      DrawTimeframe(PERIOD_D1, TF_D1_BullColor, TF_D1_BearColor, TF_D1_ExBullColor, TF_D1_ExBearColor);

   if(ShowTF_W1)
      DrawTimeframe(PERIOD_W1, TF_W1_BullColor, TF_W1_BearColor, TF_W1_ExBullColor, TF_W1_ExBearColor);

   if(ShowTF_MN1)
      DrawTimeframe(PERIOD_MN1, TF_MN1_BullColor, TF_MN1_BearColor, TF_MN1_ExBullColor, TF_MN1_ExBearColor);
}

void DrawTimeframe(const int tf,
                  const color bullColor,
                  const color bearColor,
                  const color bullExhaustedColor,
                  const color bearExhaustedColor)
{
   const int barsTotal = iBars(_Symbol, tf);
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
            const bool exhausted = HighlightExhausted && IsZoneExhausted(tf, idx, true, zoneBottom, zoneTop);
            const color zoneColor = exhausted ? bullExhaustedColor : bullColor;
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
            const bool exhausted = HighlightExhausted && IsZoneExhausted(tf, idx, false, zoneBottom, zoneTop);
            const color zoneColor = exhausted ? bearExhaustedColor : bearColor;
            CreateFVGObject(tf, false, idx, timeLeft, timeRight, zoneTop, zoneBottom, zoneColor);
            count++;
            if(count >= MaxFVGPerTF)
               break;
         }
      }
   }
}

bool IsBullishFVG(const int tf,
                  const int idx,
                  double &zoneTop,
                  double &zoneBottom,
                  datetime &leftTime,
                  datetime &rightTime)
{
   if(idx + 2 >= iBars(_Symbol, tf))
      return(false);

   const double barLow = iLow(_Symbol, tf, idx);
   const double highOfEarlierBar = iHigh(_Symbol, tf, idx + 2);

   if(barLow <= highOfEarlierBar)
      return(false);

   zoneTop = barLow;
   zoneBottom = highOfEarlierBar;
   leftTime = iTime(_Symbol, tf, idx + 2);
   rightTime = iTime(_Symbol, tf, idx);
   return(true);
}

bool IsBearishFVG(const int tf,
                  const int idx,
                  double &zoneTop,
                  double &zoneBottom,
                  datetime &leftTime,
                  datetime &rightTime)
{
   if(idx + 2 >= iBars(_Symbol, tf))
      return(false);

   const double barHigh = iHigh(_Symbol, tf, idx);
   const double lowOfEarlierBar = iLow(_Symbol, tf, idx + 2);

   if(barHigh >= lowOfEarlierBar)
      return(false);

   zoneTop = lowOfEarlierBar;
   zoneBottom = barHigh;
   leftTime = iTime(_Symbol, tf, idx + 2);
   rightTime = iTime(_Symbol, tf, idx);
   return(true);
}

bool IsZoneExhausted(const int tf,
                     const int idx,
                     const bool bullish,
                     const double zoneBottom,
                     const double zoneTop)
{
   const int barsLimit = iBars(_Symbol, tf);
   if(barsLimit <= idx + 1)
      return(false);

   const int checkUntil = MathMin(barsLimit - 1, idx + ExhaustionBars);
   for(int j = idx + 1; j <= checkUntil; j++)
   {
      const double closePrice = iClose(_Symbol, tf, j);
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

void CreateFVGObject(const int tf,
                     const bool bullish,
                     const int idx,
                     const datetime timeLeft,
                     const datetime timeRight,
                     const double zoneTop,
                     const double zoneBottom,
                     const color objColor)
{
   string name = StringFormat("%sTF%d_%s_%d", gPrefix, tf, bullish ? "B" : "S", idx);

   if(ObjectFind(0, name) >= 0)
      return;

   double topY = zoneTop;
   double bottomY = zoneBottom;

   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, timeLeft, topY, timeRight, bottomY))
      return;

   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_COLOR, objColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, BorderWidth);
   ObjectSetInteger(0, name, OBJPROP_FILL, FillZones ? 1 : 0);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, MakeAlphaColor(objColor, FillAlpha));
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_TYPE_FLAT);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
}

color MakeAlphaColor(const color baseColor, const int alpha)
{
   int a = alpha;
   if(a < 0)
      a = 0;
   if(a > 255)
      a = 255;

   const int r = GetRValue(baseColor);
   const int g = GetGValue(baseColor);
   const int b = GetBValue(baseColor);

   return(color)(((a & 0xFF) << 24) | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF));
}
