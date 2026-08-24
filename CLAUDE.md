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
  - Entry: Swing Reversal (strict-adjacency) — LL แล้วต่อด้วย HH (ห้ามมี LH/HL คั่น) → Buy เมื่อ HH confirm, HH แล้วต่อด้วย LL (ห้ามมี LH/HL คั่น) → Sell เมื่อ LL confirm; track ผ่าน lastSwingType ตัวเดียว ทุก swing ที่มาแทรกจะยกเลิก pattern อัตโนมัติ
  - จุดเข้าออเดอร์แบบ V10.1: วงกลมใหญ่โปร่ง (เขียว/แดง) + label ดำแสดง Entry/SL/TP + R:R, ลูกศรจาก entry → SL (แดง) และ entry → TP (เขียว), เส้นแนวนอนสั้น 6 แท่งที่ Entry/SL/TP + ป้ายราคา
  - กรอบ Pattern: วาดกล่องครอบช่วง LL→HH (เขียว) หรือ HH→LL (แดง) เพื่อให้เห็น pattern ชัดเจน (toggle ได้)
  - Exit system: SL ใต้/เหนือ swing + ATR buffer, TP 3 โหมด (Swing Target / Risk:Reward / Trailing Swing), Structure Exit เมื่อโครงสร้าง Dow เปลี่ยน, จุดออกเป็นวงกลมส้ม + เส้น Entry/SL/TP
  - Stats tables สไตล์ V10.1 (Luxe theme): Main Stats, By Day, Daily Log, Monthly + dropdown เลือกช่วงเวลา (Days/Months/Specific Month) + เลือกตำแหน่งตารางได้
