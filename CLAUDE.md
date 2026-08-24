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
  - Entry Mode สไตล์ V10.1: (1) Breakout — เข้าที่ close ของแท่ง confirm ทันที; (2) Pullback — สร้าง pending order ที่ระดับ pullback (`% of Price` หรือ `% of Range` ของ HH↔LL) รอราคาถอยแตะจึง fill, มี expiry เป็นจำนวนแท่ง, ยกเลิก pending ทันทีถ้าสัญญาณตรงข้ามยิงตามมา
  - Realistic fill (กันออเดอร์ผี): pending สร้างได้เฉพาะเมื่อ level ยังไม่ถูกราคาผ่าน (BUY pattern: level < close, SELL pattern: level > close) ไม่งั้นเข้า market ที่ close แทน; fill ราคา clamp กับแท่งจริง (gap ข้าม level → fill ที่ open) แล้วคำนวณ initRisk ใหม่จากราคา fill; exit SL/TP ก็ clamp กับ open เช่นกัน (gap ข้าม SL → ออกที่ open)
  - Reverse Trade mode (fade the pattern): เปิดแล้วพลิกทิศเทรด — LL→HH detect ได้ SELL แทน BUY (SL วางเหนือ HH), HH→LL detect ได้ BUY แทน SELL (SL วางใต้ LL); tag ในผลเทรดต่อท้ายด้วย `⇄`; ใช้กับ pullback mode ได้ด้วย (fill trigger side ใช้ pendingFillOnLow ตัดสินตาม pattern ไม่ใช่ทิศเทรด)
  - Risk Management สไตล์ V10.1: 1R Basis เลือก SL% (% ของ pattern range) / Distance (คงที่) / ATR (× multiplier), SL Edge Mode วาง SL ที่ขอบ pattern, Risk per 1R ($) → คำนวณ Lot อัตโนมัติผ่าน `lot = risk / (1R × pipValueRatio)`, R:R Ratio, Spread adjustment (BUY +spread / SELL -spread)
  - Exit: เหลือแค่ SL hit / TP hit เท่านั้น (ไม่มี trailing / structure / reverse) — จุดออกเป็นวงกลมส้ม + tooltip แสดง entry/exit
  - Stats tables สไตล์ V10.1 (Luxe theme): Main Stats, By Day, Daily Log, Monthly + dropdown เลือกช่วงเวลา (Days/Months/Specific Month) + เลือกตำแหน่งตารางได้
