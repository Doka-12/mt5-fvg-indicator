#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0

input int     MaxBarsToScan          = 220;
input int     MaxFVGPerTF            = 25;
input double  MinGapPoints           = 0.0;
input bool    ShowBullishFVG         = true;
input bool    ShowBearishFVG         = true;
input bool    FillZones              = true;
input int     FillAlpha              = 85;
input int     BorderWidth            = 1;
input bool    UseCurrentTF           = false;
input int     LiveExtendBars         = 30;
input int     CheckBarsPast          = 5;

// Current timeframe colors
input color   BullishColor           = clrDodgerBlue;
input color   BearishColor           = clrTomato;

// Multi-timeframe selection
input bool    ShowTF_H4              = true;
input bool    ShowTF_D1              = true;
input bool    ShowTF_W1              = true;
input bool    ShowTF_MN1             = false;

// H4 colors
input color   TF_H4_BullColor        = clrSkyBlue;
input color   TF_H4_BearColor        = clrTomato;

// D1 colors
input color   TF_D1_BullColor        = clrDeepSkyBlue;
input color   TF_D1_BearColor        = clrFireBrick;

// W1 colors
input color   TF_W1_BullColor        = clrGoldenrod;
input color   TF_W1_BearColor        = clrOrangeRed;

// MN1 colors
input color   TF_MN1_BullColor       = clrSlateGray;
input color   TF_MN1_BearColor       = clrLightCoral;

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
      DrawTimeframe(_Period, BullishColor, BearishColor);

   if(ShowTF_H4)
      DrawTimeframe(PERIOD_H4, TF_H4_BullColor, TF_H4_BearColor);

   if(ShowTF_D1)
      DrawTimeframe(PERIOD_D1, TF_D1_BullColor, TF_D1_BearColor);

   if(ShowTF_W1)
      DrawTimeframe(PERIOD_W1, TF_W1_BullColor, TF_W1_BearColor);

   if(ShowTF_MN1)
      DrawTimeframe(PERIOD_MN1, TF_MN1_BullColor, TF_MN1_BearColor);
}

void DrawTimeframe(ENUM_TIMEFRAMES tf,
                   const color bullColor,
                   const color bearColor)
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

            if(WasTouchedRecently(tf, zoneBottom, zoneTop))
               continue;

            CreateFVGObject(tf, true, idx, timeLeft, timeRight, zoneTop, zoneBottom, bullColor);
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

            if(WasTouchedRecently(tf, zoneBottom, zoneTop))
               continue;

            CreateFVGObject(tf, false, idx, timeLeft, timeRight, zoneTop, zoneBottom, bearColor);
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

bool WasTouchedRecently(ENUM_TIMEFRAMES tf,
                        const double zoneBottom,
                        const double zoneTop)
{
   int barsTotal = iBars(_Symbol, tf);
   if(barsTotal <= 0)
      return(false);

   int checkBars = MathMin(CheckBarsPast, barsTotal - 1);

   for(int j = 0; j < checkBars; j++)
   {
      double low = iLow(_Symbol, tf, j);
      double high = iHigh(_Symbol, tf, j);

      if(low <= zoneBottom && high >= zoneTop)
         return(true);
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

   datetime extendRight = timeRight + LiveExtendBars * PeriodSeconds(tf);

   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, timeLeft, zoneTop, extendRight, zoneBottom))
      return;

   ObjectSetInteger(0, name, OBJPROP_BACK, 1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, 0);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, 0);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, 0);
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
