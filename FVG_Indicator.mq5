#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0

input int    FVGLookbackBars        = 200;                  // How many recent candles to scan for FVG
input bool   ShowBullishFVG         = true;                 // Show bullish FVG
input bool   ShowBearishFVG         = true;                 // Show bearish FVG
input color  BullishFVGColor        = clrDodgerBlue;        // Bullish FVG color
input color  BearishFVGColor        = clrTomato;            // Bearish FVG color
input bool   HighlightExhausted     = true;                 // Highlight exhausted FVG zones with another color
input color  BullishExhaustedColor  = clrLimeGreen;         // Exhausted bullish FVG color
input color  BearishExhaustedColor  = clrDarkOrange;        // Exhausted bearish FVG color
input int    FVGBorderWidth         = 1;                    // Border width for FVG zones
input bool   FillZones              = true;                 // Fill the FVG zone
input int    FillTransparency       = 85;                   // Fill transparency: 0..255
input bool   ShowTF_H4              = true;                 // Search FVG on H4
input color  TF_H4_Color            = clrAqua;              // H4 FVG color
input bool   ShowTF_D1              = true;                 // Search FVG on D1
input color  TF_D1_Color            = clrGold;              // D1 FVG color
input bool   ShowTF_W1              = true;                 // Search FVG on W1
input color  TF_W1_Color            = clrOrange;            // W1 FVG color
input bool   ShowTF_MN1             = false;                // Search FVG on MN1
input color  TF_MN1_Color           = clrDarkGray;          // MN1 FVG color
input int    ExhaustionCheckBars    = 80;                   // How far forward to check whether the zone was exhausted

string g_prefix = "FVG_";

int OnInit()
{
   ObjectsDeleteAll(0, g_prefix);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, g_prefix);
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
   RefreshFVG();
   return(rates_total);
}

void RefreshFVG()
{
   if(!IsStopped())
      ObjectsDeleteAll(0, g_prefix);

   if(FVGLookbackBars <= 0)
      return;

   if(ShowBullishFVG)
   {
      ScanTimeframe(PERIOD_H4, TF_H4_Color, true, ShowTF_H4);
      ScanTimeframe(PERIOD_D1, TF_D1_Color, true, ShowTF_D1);
      ScanTimeframe(PERIOD_W1, TF_W1_Color, true, ShowTF_W1);
      ScanTimeframe(PERIOD_MN1, TF_MN1_Color, true, ShowTF_MN1);
   }

   if(ShowBearishFVG)
   {
      ScanTimeframe(PERIOD_H4, TF_H4_Color, false, ShowTF_H4);
      ScanTimeframe(PERIOD_D1, TF_D1_Color, false, ShowTF_D1);
      ScanTimeframe(PERIOD_W1, TF_W1_Color, false, ShowTF_W1);
      ScanTimeframe(PERIOD_MN1, TF_MN1_Color, false, ShowTF_MN1);
   }
}

void ScanTimeframe(const int tf, const color colorForTF, const bool bullish, const bool enabled)
{
   if(!enabled)
      return;

   const int barsTotal = iBars(_Symbol, tf);
   if(barsTotal < 4)
      return;

   const int limit = MathMin(barsTotal - 3, FVGLookbackBars + 2);

   for(int i = 0; i < limit; i++)
   {
      const datetime leftTime = iTime(_Symbol, tf, i + 2);
      const datetime rightTime = iTime(_Symbol, tf, i);
      if(rightTime <= 0 || leftTime <= 0)
         continue;

      const double currLow  = iLow(_Symbol, tf, i);
      const double currHigh = iHigh(_Symbol, tf, i);
      const double prevLow  = iLow(_Symbol, tf, i + 2);
      const double prevHigh = iHigh(_Symbol, tf, i + 2);

      if(bullish)
      {
         if(currLow <= prevHigh)
            continue;

         const double zoneTop    = MathMax(prevHigh, currLow);
         const double zoneBottom = MathMin(prevHigh, currLow);
         const bool exhausted = IsZoneExhausted(tf, i, true, zoneBottom, zoneTop);
         const color zoneColor = exhausted ? BullishExhaustedColor : colorForTF;

         CreateFVGObject(tf, true, leftTime, rightTime, zoneTop, zoneBottom, zoneColor);
      }
      else
      {
         if(currHigh >= prevLow)
            continue;

         const double zoneTop    = MathMax(prevLow, currHigh);
         const double zoneBottom = MathMin(prevLow, currHigh);
         const bool exhausted = IsZoneExhausted(tf, i, false, zoneBottom, zoneTop);
         const color zoneColor = exhausted ? BearishExhaustedColor : colorForTF;

         CreateFVGObject(tf, false, leftTime, rightTime, zoneTop, zoneBottom, zoneColor);
      }
   }
}

bool IsZoneExhausted(const int tf, const int startIndex, const bool bullish, const double zoneBottom, const double zoneTop)
{
   if(!HighlightExhausted)
      return false;

   const int maxCheck = MathMin(ExhaustionCheckBars, iBars(_Symbol, tf) - startIndex - 1);
   if(maxCheck <= 0)
      return false;

   for(int j = startIndex + 1; j <= startIndex + maxCheck; j++)
   {
      const double closePrice = iClose(_Symbol, tf, j);
      if(bullish)
      {
         if(closePrice <= zoneBottom)
            return true;
      }
      else
      {
         if(closePrice >= zoneTop)
            return true;
      }
   }

   return false;
}

void CreateFVGObject(const int tf,
                    const bool bullish,
                    const datetime leftTime,
                    const datetime rightTime,
                    const double topPrice,
                    const double bottomPrice,
                    const color zoneColor)
{
   string name = StringFormat("%sTF%ld_%s_%ld_%ld", g_prefix, tf, bullish ? "B" : "S", leftTime, rightTime);

   if(ObjectFind(0, name) >= 0)
      return;

   const bool created = ObjectCreate(0, name, OBJ_RECTANGLE, 0, leftTime, topPrice, rightTime, bottomPrice);
   if(!created)
      return;

   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_COLOR, zoneColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, FVGBorderWidth);
   ObjectSetInteger(0, name, OBJPROP_FILL, FillZones ? 1 : 0);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, SetAlphaColor(zoneColor, FillTransparency));
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_TYPE_FLAT);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
}

color SetAlphaColor(const color baseColor, const int alpha)
{
   const int a = MathMax(0, MathMin(255, alpha));
   const int r = GetRValue(baseColor);
   const int g = GetGValue(baseColor);
   const int b = GetBValue(baseColor);
   return(color)((a << 24) | (r << 16) | (g << 8) | b);
}

// END OF FILE
