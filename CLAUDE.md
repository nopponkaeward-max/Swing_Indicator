# Swing Indicator Project

## Workflow

- ทุกครั้งที่มีการอัปเดทไฟล์ ต้อง commit, push, และสร้าง Pull Request เพื่อ merge เข้า `main` เสมอ
- ไฟล์หลัก: `DowTheory_Trend_V1.0.pine` (TradingView Pine Script v6)

## Project Structure

- `DowTheory_Trend_V1.0.pine` - Dow Theory Trend indicator (Pine Script v6)
  - Swing High/Low detection (Fractal method)
  - Trendline drawing (Uptrend/Downtrend)
  - HH/HL/LH/LL labels
  - Info panel + Alert conditions
  - Entry: Dow Theory Confirmation (strict-adjacency 3-swing) — LL → HH → HL confirm → Buy (ห้ามมี LH คั่น), HH → LL → LH confirm → Sell (ห้ามมี HL คั่น); track ผ่าน `prevSwingType` + `lastSwingType` shift 2 slot ทุกครั้งที่มี swing ใหม่, ทุก swing ที่แทรกจะยกเลิก pattern อัตโนมัติ; SL Edge Mode วางที่ HL (BUY) / LH (SELL) จุด confirm ล่าสุด — ตึงสุด; pattern range สำหรับ 1R ยังใช้ HH-LL เดิม (กว้าง); pullback % (Mode `% of Range`) ใช้ range แคบ HH-HL (BUY) / LH-LL (SELL); breakout ยังเบรค HH (BUY) / LL (SELL) ขอบเดิม
  - จุดเข้าออเดอร์แบบ V10.1: วงกลมใหญ่โปร่ง (เขียว/แดง) + label ดำแสดง Entry/SL/TP + R:R, ลูกศรจาก entry → SL (แดง) และ entry → TP (เขียว), เส้นแนวนอนสั้น 6 แท่งที่ Entry/SL/TP + ป้ายราคา
  - กรอบ Pattern: วาดกล่องครอบช่วง LL→HH (เขียว) หรือ HH→LL (แดง) เพื่อให้เห็น pattern ชัดเจน (toggle ได้)
  - Entry Mode สไตล์ V10.1: (1) Market — เข้าที่ close ของแท่ง confirm ทันที; (2) Pullback — สร้าง pending order ที่ระดับ pullback (`% of Price` หรือ `% of Range` ของ HH↔LL) รอราคาถอยแตะจึง fill, มี expiry เป็นจำนวนแท่ง, ยกเลิก pending ทันทีถ้าสัญญาณตรงข้ามยิงตามมา; (3) Breakout — สร้าง pending order ที่ระดับ HH (ขาขึ้น) หรือ LL (ขาลง) รอราคาเบรคผ่านจึง fill, ยกเลิกทันทีถ้ามี swing ใหม่ (HH/HL/LH/LL) ปรากฏก่อนเบรค, ใช้ expiry เดียวกับ Pullback
  - Realistic fill (กันออเดอร์ผี): pending สร้างได้เฉพาะเมื่อ level ยังไม่ถูกราคาผ่าน (BUY pattern: level < close, SELL pattern: level > close) ไม่งั้นเข้า market ที่ close แทน; fill ราคา clamp กับแท่งจริง (gap ข้าม level → fill ที่ open) แล้วคำนวณ initRisk ใหม่จากราคา fill; exit SL/TP ก็ clamp กับ open เช่นกัน (gap ข้าม SL → ออกที่ open)
  - Same-bar exit หลัง fill: section fill อยู่ก่อน exit check → แท่งที่ pending fill จะถูกเช็ค SL/TP ต่อทันทีเฉพาะ "ฝั่งที่ราคาวิ่งต่อหลังจุด fill" (deterministic): fill ขาลง → เช็ค level ใต้ entry (SL ของ Long / TP ของ Short), fill ขาขึ้น → เช็ค level เหนือ entry; ฝั่งตรงข้ามไม่รู้ลำดับ intra-bar จึงรอแท่งถัดไป; exitPx ในแท่ง fill อ้างอิงราคา fill แทน open
  - Opposite-signal cancel ใช้ `pendingPatDir` (ทิศ pattern ที่สร้าง pending) ไม่ใช่ทิศเทรด → ถูกต้องแม้เปิด Reverse mode
  - Reverse Trade mode (fade the pattern): เปิดแล้วพลิกทิศเทรด — LL→HH detect ได้ SELL แทน BUY (SL วางเหนือ HH), HH→LL detect ได้ BUY แทน SELL (SL วางใต้ LL); tag ในผลเทรดต่อท้ายด้วย `⇄`; ใช้กับ pullback mode ได้ด้วย (fill trigger side ใช้ pendingFillOnLow ตัดสินตาม pattern ไม่ใช่ทิศเทรด)
  - Risk Management สไตล์ V10.1: 1R Basis เลือก SL% (% ของ pattern range) / Distance (คงที่) / ATR (× multiplier), SL Edge Mode วาง SL ที่ขอบ pattern, Risk per 1R ($) → คำนวณ Lot อัตโนมัติผ่าน `lot = risk / (1R × pipValueRatio)`, R:R Ratio, Spread adjustment (BUY +spread / SELL -spread)
  - Exit สไตล์ V10.1: SL hit / TP hit เท่านั้น — วงกลมสีตามผล (เขียว=win, แดง=loss, เทา=breakeven, size.normal) + label แสดงจำนวน R (เช่น +1.85R / -1.00R) + เส้นแนวนอนสั้น 6 แท่งที่ราคา exit + เส้นประ trade path จาก entry ถึง exit (สีตามผล, toggle ได้); เส้น SL/TP ฝั่งที่ hit → solid สีเข้ม, ฝั่งที่ไม่ hit → จางลง
  - Recovery Mode: เมื่อเทรดหลักแพ้ (SL hit) → เปิด Recovery trade อัตโนมัติทันที; Entry = ราคา exit จริงของเทรดเดิม (exitPx — ปกติ = SL, ถ้า gap ข้าม = open), 1R สืบทอดจากเทรดเดิม; Direction เลือก Same/Reverse; R:R ตั้งค่าแยก; Recovery ได้ 1 ครั้งต่อ 1 main trade (ห้าม recover ซ้อน); tag ต่อท้ายด้วย "Reco"
  - Stats tables สไตล์ V10.1 (Luxe theme): Main Stats, By Day, Daily Log, Monthly + dropdown เลือกช่วงเวลา (Days/Months/Specific Month) + เลือกตำแหน่งตารางได้
