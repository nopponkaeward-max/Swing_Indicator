# Swing Indicator Project

## Workflow

- ทุกครั้งที่มีการอัปเดทไฟล์ ต้อง commit, push, และสร้าง Pull Request เพื่อ merge เข้า `main` เสมอ
- ไฟล์หลัก: `DowTheory_Trend.pine` (TradingView Pine Script v6)

## Project Structure

- `DowTheory_Trend.pine` - Dow Theory Trend indicator (Pine Script v6)
  - Swing High/Low detection (Fractal method)
  - Trendline drawing (Uptrend/Downtrend)
  - HH/HL/LH/LL labels
  - Info panel + Alert conditions
  - Entry: Swing Reversal (sequence-based) — LL แล้วเกิด HH → Buy เมื่อ HH confirm, HH แล้วเกิด LL → Sell เมื่อ LL confirm
  - จุดเข้าออเดอร์: label วงกลมเล็ก (เขียว = Buy ใต้แท่ง, แดง = Sell เหนือแท่ง) + เส้นเล็ก ๆ ที่ระดับราคา entry + label ราคา
  - กรอบ Pattern: วาดกล่องครอบช่วง LL→HH (เขียว) หรือ HH→LL (แดง) เพื่อให้เห็น pattern ชัดเจน (toggle ได้)
  - Exit system: SL ใต้/เหนือ swing + ATR buffer, TP 3 โหมด (Swing Target / Risk:Reward / Trailing Swing), Structure Exit เมื่อโครงสร้าง Dow เปลี่ยน, จุดออกเป็นวงกลมส้ม + เส้น Entry/SL/TP
  - Stats tables สไตล์ V10.1 (Luxe theme): Main Stats, By Day, Daily Log, Monthly + dropdown เลือกช่วงเวลา (Days/Months/Specific Month) + เลือกตำแหน่งตารางได้
