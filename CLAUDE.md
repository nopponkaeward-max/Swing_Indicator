# Swing Indicator Project

## Workflow

- ทุกครั้งที่มีการอัปเดทไฟล์ ต้อง commit, push, และสร้าง Pull Request เพื่อ merge เข้า `main` เสมอ
- ไฟล์หลัก: `MegaphoneV1.0.pine` (TradingView Pine Script v6)

## Project Structure

- `MegaphoneV1.0.pine` - Megaphone Breakout Trading System (Pine Script v6, **ตรวจจับ + วาด + เทรดเบรคเอาท์จากกล่อง**)
  - Swing High/Low detection (Fractal) + label HH/HL/LH/LL
  - Megaphone = ยอดทำ HH ต่อเนื่อง (rising steps ≥ `inpMinRise`) + ก้นทำ LL ต่อเนื่อง (falling steps ≥ `inpMinFall`) พร้อมกัน = กรอบถ่างออก; นับ trailing run จาก array swing (จากใหม่→เก่า, break เมื่อเจอ step ที่ไม่ต่อเนื่อง — LH ทำ rise=0, HL ทำ fall=0); Bull = swing ล่าสุดเป็น HH (กล่องเขียว), Bear = LL (กล่องแดง)
  - State machine: pattern ใหม่ก่อตัว → วาดเส้นขอบ + กล่องครอบ + label `◀ BULL/BEAR MEGAPHONE ▶`; ยังถ่างต่อ → ยืดขอบตาม (**การขยายกรอบไม่ใช่ breakout**); หยุดถ่าง (เจอ LH/HL) → freeze แล้ว **arm OCO plan** ที่ขอบกรอบสุดท้าย (เฉพาะเมื่อ close ยังอยู่ในกรอบ + วันผ่าน day filter) พร้อมยืดขอบขวาของกล่องตามราคาไปจนกว่าจะเบรค/หมดอายุ/มี pattern ใหม่
  - Breakout: แท่ง confirmed แรกที่ high > planTop → BUY / low < planBot → SELL ที่ขอบกรอบ (gap ข้าม → fill ที่ open, บวก/ลบ spread); เบรคสองฝั่งแท่งเดียว → ทิศตามสีแท่ง; ห้ามเบรคแท่งเดียวกับที่ arm; plan หมดอายุตาม `inpPlanExpiry` แท่ง (กันออเดอร์ผีไกลจากกล่อง); pattern ใหม่ confirm → ยกเลิก plan + ปิดทุก position ที่ close
  - Risk: 1R = SL% × range (ไม่มี Distance/ATR), SL = ent±1R, TP = ent±1R×RR, lot = Risk$/(1R×pipValueRatio); ไม่มี Trailing SL / Recovery
  - 2nd Order (toggle): main เบรคแล้วราคาย่อแตะ 50% midline → **ปิด main ที่ midline** (บันทึก R จริง) แล้วเปิด 2nd order ทิศเดิมที่ midline; TP = ขอบที่เบรค, SL = ขอบตรงข้าม (R:R ≈ 1:1)
  - Visuals สไตล์ V11.0: วงกลม entry, ลูกศร entry→SL/TP, เส้น+ป้ายราคา Entry/SL/TP, label CONFIRMED, exit circle + R label + trade path; Luxe stats 4 ตาราง (Main, By Day, Daily Log, Monthly) + Day-of-week filter + stats mode (Days/Months/Specific Month)
  - Info panel (มุมขวาบน): สถานะ FORMING/ARMED/none, rising/falling count, swing count, box range, active trades, plan state; alert เมื่อ pattern ใหม่ก่อตัว
  - Pine v6 gotchas ที่เจอแล้ว: `var bool` เก็บ `na` ไม่ได้ (ใช้ int sentinel), `int/int` เป็น integer division (คูณ `1.0` ก่อนหาร)
- `DowTheory_Trend_V1.0.mq5` - Expert Advisor สำหรับ MT5 (Frame Break system — คนละระบบกับ Megaphone, เก็บไว้เป็น EA เทรด)
  - เบรค/fill ตรวจแบบ tick-based (รู้ลำดับ intra-bar จริง จึงไม่ต้องมีกฎ "แท่งเบรคห้าม fill" และไม่มีเคสเบรคสองฝั่งพร้อมกัน), pivot/frame confirm แบบ bar-close, spread ใช้ bid/ask จริง (ไม่มี input spread)
  - Warm-up: OnInit ไล่สร้าง swing/frame state จากอดีต (ไม่ส่งออเดอร์ย้อนหลัง — กรอบที่เบรค/fill ไปแล้วในอดีตถือว่า consumed), รับ position เดิมของ EA กลับหลัง restart (adopt by magic + "Reco" ใน comment)
  - Recovery ผ่าน `OnTradeTransaction`: DEAL_ENTRY_OUT + DEAL_REASON_SL + ขาดทุน → เปิด recovery market ทันที (ราคาปัจจุบัน ≈ SL), 1R สืบทอด, ห้ามซ้อน
  - Lot: default คำนวณจาก tick value จริง (`lot = Risk$ / (1R/tickSize×tickValue)`), ปิดได้เพื่อใช้สูตร Pine (`1R × pipValueRatio`); clamp กับ volume min/max/step; กัน SL/TP แคบกว่า stops level
  - วาด: swing labels (HH/HL/LH/LL), เส้นขอบกรอบ (น้ำเงิน/แดง), เส้น pullback (magenta), กล่องกรอบ, trendlines; Info panel + stats (trades/WR/NetR) ผ่าน `Comment()`
  - กันเคส: แท่งพลาดตอน disconnect (ไล่ process ทุกแท่งที่ปิดค้าง), history ไม่ครบ (iHigh=0), partial fill (DONE_PARTIAL), filling mode ตาม symbol
### Frame Break trading model (โมเดลเทรดของ `.mq5` EA — เดิมเป็น Pine indicator, ตอนนี้ .pine ถูกแทนด้วย Megaphone แล้ว)
  - Swing High/Low detection (Fractal method)
  - Trendline drawing (Uptrend/Downtrend)
  - HH/HL/LH/LL labels
  - Info panel + Alert conditions
  - Entry: **Frame Break** (สไตล์ V10.1 SessionBreak แต่กรอบ = Dow frame แทน session) — กรอบคือ LL→HH (bull) หรือ HH→LL (bear) แบบ strict adjacency 2-swing (track ผ่าน `lastSwingType` ตัวเดียว, swing แทรก = กรอบไม่ถูกนับ); กรอบ confirm → arm รอเบรค OCO 2 ฝั่ง (`pendingState=1`): เบรคขึ้นผ่าน HH → BUY, เบรคลงผ่าน LL → SELL (ทิศเทรดตามทิศเบรค ไม่เกี่ยวกับชนิดกรอบ); **Entry Mode 2 แบบ**: (1) Breakout — fill ทันทีที่เบรคที่ราคาขอบกรอบ (gap ข้าม → fill ที่ open), `tradeFilledOnLow = not brkUp`; (2) Pullback — เบรคแล้ว (`pendingState=2`) → ตั้ง pending ที่ pullback level ในกรอบ: `% of Range` → เบรคขึ้น level = HH−(HH-LL)×X% / เบรคลง level = LL+(HH-LL)×X%, `% of Price` → วัดจากขอบที่เบรค; ราคาถอยกลับมาแตะ level → fill; SL/TP/lot คำนวณตอน fill ทั้งสอง mode (SL = ent±1R, TP = ent±1R×RR); แท่งที่เบรคจะไม่เช็ค pullback ในแท่งเดียวกัน (V10.1-style else-if); แท่งเดียวกลืนทั้งกรอบ (เบรคทั้งสองฝั่ง) → ยกเลิกกรอบ; **ไม่มี expiry** — กรอบ/pending/position ถูกยกเลิกหรือปิดได้ทางเดียวคือกรอบใหม่ confirm
  - **กรอบใหม่ยกเลิกทุกอย่าง**: เมื่อกรอบใหม่ confirm → ยกเลิก pending/กรอบเก่า (label `"CANCEL FRAME (new frame)"`) และ**ปิด position ที่เปิดอยู่ที่ราคา close** (exit tooltip `"EXIT (New Frame)"`, เส้น SL/TP จางทั้งคู่, บันทึกลง stats ตาม R จริง) — SL/TP intra-bar ของแท่งนั้นถูกเช็คก่อน; **แท่งที่กรอบใหม่ confirm กรอบเก่าถูก freeze ทันที** (`newFrameEvent` ประกาศก่อน state machine และ guard ทั้ง state 1/2) — ห้ามเบรค/ห้าม fill จากกรอบเก่าในแท่งนั้น
  - Reverse Trade (fade the break): เบรคขึ้น → SELL แทน BUY, เบรคลง → BUY แทน SELL; จุด fill ไม่เปลี่ยน (ยังรอ pullback level เดิม) เปลี่ยนแค่ทิศเทรด; tag ต่อท้าย `⇄`
  - จุดเข้าออเดอร์แบบ V10.1: วงกลมใหญ่โปร่ง (เขียว/แดง) + label ดำแสดง Entry/SL/TP + R:R, ลูกศรจาก entry → SL (แดง) และ entry → TP (เขียว), เส้นแนวนอนสั้น 6 แท่งที่ Entry/SL/TP + ป้ายราคา; ระหว่าง arm มีเส้นขอบบน (น้ำเงิน) / ขอบล่าง (แดง) + label FRAME armed, หลังเบรคมีเส้น pullback (fuchsia dotted) + วงกลมที่จุดเบรค
  - กรอบ Frame: วาดกล่องครอบช่วง LL→HH (เขียว) หรือ HH→LL (แดง) เพื่อให้เห็นกรอบชัดเจน (toggle ได้)
  - Realistic fill (กันออเดอร์ผี): pending สร้างได้เฉพาะเมื่อ level ยังไม่ถูกราคาผ่าน (BUY pattern: level < close, SELL pattern: level > close) ไม่งั้นเข้า market ที่ close แทน; fill ราคา clamp กับแท่งจริง (gap ข้าม level → fill ที่ open) แล้วคำนวณ initRisk ใหม่จากราคา fill; exit SL/TP ก็ clamp กับ open เช่นกัน (gap ข้าม SL → ออกที่ open)
  - Same-bar exit หลัง fill: section state machine อยู่ก่อน exit check → แท่งที่ fill จะถูกเช็ค SL/TP ต่อทันทีเฉพาะ "ฝั่งที่ราคาวิ่งต่อหลังจุด fill" (deterministic): fill ขาลง → เช็ค level ใต้ entry (SL ของ Long / TP ของ Short), fill ขาขึ้น → เช็ค level เหนือ entry; ฝั่งตรงข้ามไม่รู้ลำดับ intra-bar จึงรอแท่งถัดไป; exitPx ในแท่ง fill อ้างอิงราคา fill แทน open (fill trigger side = `pendingFillOnLow` ตัดสินตามทิศเบรค ไม่ใช่ทิศเทรด — ถูกต้องแม้เปิด Reverse)
  - Risk Management: 1R Basis เลือก SL% (% ของ pattern range) / Distance (คงที่) / ATR (× multiplier), Risk per 1R ($) → คำนวณ Lot อัตโนมัติผ่าน `lot = risk / (1R × pipValueRatio)`, R:R Ratio, Spread adjustment (BUY +spread / SELL -spread); SL วางที่ ent±oneR (ไม่มี SL Edge Mode / SelfR toggles แล้ว — RR ตรงตามที่ตั้งเสมอ)
  - Exit สไตล์ V10.1: SL hit / TP hit เท่านั้น — วงกลมสีตามผล (เขียว=win, แดง=loss, เทา=breakeven, size.normal) + label แสดงจำนวน R (เช่น +1.85R / -1.00R) + เส้นแนวนอนสั้น 6 แท่งที่ราคา exit + เส้นประ trade path จาก entry ถึง exit (สีตามผล, toggle ได้); เส้น SL/TP ฝั่งที่ hit → solid สีเข้ม, ฝั่งที่ไม่ hit → จางลง
  - Recovery Mode: เมื่อเทรดหลักแพ้ (SL hit) → เปิด Recovery trade อัตโนมัติทันที; Entry = ราคา exit จริงของเทรดเดิม (exitPx — ปกติ = SL, ถ้า gap ข้าม = open), 1R สืบทอดจากเทรดเดิม; Direction เลือก Same/Reverse; R:R ตั้งค่าแยก; Recovery ได้ 1 ครั้งต่อ 1 main trade (ห้าม recover ซ้อน); tag ต่อท้ายด้วย "Reco"
  - Stats tables สไตล์ V10.1 (Luxe theme): Main Stats, By Day, Daily Log, Monthly + dropdown เลือกช่วงเวลา (Days/Months/Specific Month) + เลือกตำแหน่งตารางได้
