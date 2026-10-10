#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0

input int     MaxBarsToScan          = 500;
input int     MaxFVGPerTF            = 50;
input bool    ShowBullishFVG         = true;
input bool    ShowBearishFVG         = true;
input bool    FillZones              = true;
input int     FillAlpha              = 85;
input int     BorderWidth            = 2;

input bool    ShowTF_H4              = true;
input bool    ShowTF_D1              = true;
input bool    ShowTF_W1              = true;
input bool    ShowTF_MN1             = false;

input color   BullishColor           = clrDodgerBlue;
input color   BearishColor           = clrTomato;
input color   TF_H4_BullColor        = clrSkyBlue;
input color   TF_H4_BearColor        = clrLightSalmon;
input color   TF_D1_BullColor        = clrDeepSkyBlue;
input color   TF_D1_BearColor        = clrFireBrick;
input color   TF_W1_BullColor        = clrGoldenrod;
input color   TF_W1_BearColor        = clrOrangeRed;

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

   if(ShowTF_H4)
      DrawTimeframe(PERIOD_H4, TF_H4_BullColor, TF_H4_BearColor);

   if(ShowTF_D1)
      DrawTimeframe(PERIOD_D1, TF_D1_BullColor, TF_D1_BearColor);

   if(ShowTF_W1)
      DrawTimeframe(PERIOD_W1, TF_W1_BullColor, TF_W1_BearColor);

   if(ShowTF_MN1)
      DrawTimeframe(PERIOD_MN1, clrSlateGray, clrLightCoral);
}

void DrawTimeframe(ENUM_TIMEFRAMES tf,
                   const color bullColor,
                   const color bearColor)
{
   int barsTotal = iBars(_Symbol, tf);
   if(barsTotal < 4)
      return;

   int scannedBars = MathMin(MaxBarsToScan, barsTotal - 2);
   int bullCount = 0;
   int bearCount = 0;

   for(int idx = 0; idx < scannedBars; idx++)
   {
      if(idx + 2 >= barsTotal)
         break;

      // Bullish FVG: текущий low > предыдущий high (на 2 бара назад)
      if(ShowBullishFVG && bullCount < MaxFVGPerTF)
      {
         double low0 = iLow(_Symbol, tf, idx);
         double high2 = iHigh(_Symbol, tf, idx + 2);

         if(low0 > high2)
         {
            double zoneTop = low0;
            double zoneBottom = high2;
            datetime timeLeft = iTime(_Symbol, tf, idx + 2);
            datetime timeRight = iTime(_Symbol, tf, idx);

            CreateFVGRect(tf, true, idx, timeLeft, timeRight, zoneTop, zoneBottom, bullColor);
            bullCount++;
         }
      }

      // Bearish FVG: текущий high < предыдущий low (на 2 бара назад)
      if(ShowBearishFVG && bearCount < MaxFVGPerTF)
      {
         double high0 = iHigh(_Symbol, tf, idx);
         double low2 = iLow(_Symbol, tf, idx + 2);

         if(high0 < low2)
         {
            double zoneTop = low2;
            double zoneBottom = high0;
            datetime timeLeft = iTime(_Symbol, tf, idx + 2);
            datetime timeRight = iTime(_Symbol, tf, idx);

            CreateFVGRect(tf, false, idx, timeLeft, timeRight, zoneTop, zoneBottom, bearColor);
            bearCount++;
         }
      }

      if(bullCount >= MaxFVGPerTF && bearCount >= MaxFVGPerTF)
         break;
   }
}

void CreateFVGRect(ENUM_TIMEFRAMES tf,
                   const bool bullish,
                   const int idx,
                   const datetime timeLeft,
                   const datetime timeRight,
                   const double zoneTop,
                   const double zoneBottom,
                   const color objColor)
{
   string name = StringFormat("%sTF%d_%s_%d", gPrefix, (int)tf, bullish ? "B" : "S", idx);
   
   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, timeLeft, zoneTop, timeRight, zoneBottom))
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
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, ColorWithAlpha(objColor, FillAlpha));
   }
   else
   {
      ObjectSetInteger(0, name, OBJPROP_FILL, 0);
   }
}

color ColorWithAlpha(color c, int alpha)
{
   if(alpha < 0) alpha = 0;
   if(alpha > 255) alpha = 255;
   return((color)((alpha << 24) | (c & 0x00FFFFFF)));
}
