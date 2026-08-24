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
  - Entry strategies (dropdown เลือกได้): S1 Pullback to Trendline, S2 Break of Structure (BOS), S3 Trendline Break Reversal
  - จุดเข้าออเดอร์แสดงเป็น label วงกลมเล็ก (เขียว = Buy ใต้แท่ง, แดง = Sell เหนือแท่ง) พร้อม tooltip บอก strategy
  - Exit system: SL ใต้/เหนือ swing + ATR buffer, TP 3 โหมด (Swing Target / Risk:Reward / Trailing Swing), Structure Exit เมื่อโครงสร้าง Dow เปลี่ยน, จุดออกเป็นวงกลมส้ม + เส้น Entry/SL/TP
  - Stats tables สไตล์ V10.1 (Luxe theme): Main Stats, By Day, Daily Log, Monthly + dropdown เลือกช่วงเวลา (Days/Months/Specific Month) + เลือกตำแหน่งตารางได้
