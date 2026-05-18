# Persona Behavior Specification

## Aarav — The Overspending Professional

Profile:
- 27-year-old software developer
- Single, lives in Bangalore
- Earns well, struggles with daily expense control
- Overspends through frequent small payments
- High UPI frequency: food delivery, cabs, coffee, weekend outings
- Has some investments/SIPs
- Goals: vacation, emergency fund, laptop
- Core anxiety: "I earn well, why does money disappear?"
- Moné value: safe-to-spend, spend velocity, Pay with Pause, nudges

### Monthly Rhythm

Month start (days 1-10):
- Rent paid on 3rd or 5th
- SIP on 5th/10th
- Broadband/mobile/subscriptions renew
- Feels safe because salary just came
- Higher food/cab/shopping spends

Mid month (days 11-20):
- Frequent UPI spends accumulate
- Credit card balance starts rising
- Food delivery exceeds normal pace
- Weekend shopping spike

Month end (days 21-31):
- Credit card due
- Salary arrives (28th)
- Reimbursements may come in
- May transfer leftover into goal/RD
- If overspent, goal allocation slips

### Day-Type Behavior

Weekday office:
- Coffee (₹150-250)
- Lunch (₹200-400)
- Cab/metro (₹100-350)
- Dinner delivery sometimes (₹300-600)

Work-from-home:
- Food delivery (₹250-500)
- Grocery top-up (₹300-800)
- Subscription/app spend

Friday:
- Cab (₹200-400)
- Dinner out (₹800-2000)
- Drinks/outing (₹500-1500)

Saturday:
- Shopping (₹500-5000)
- Dining out (₹600-2000)
- Grocery (₹500-2000)
- Entertainment (₹300-800)

Sunday:
- Grocery (₹400-1500)
- Laundry (₹200-400)
- Food delivery (₹300-600)
- Low-mobility spends

Salary day:
- Salary credit
- Rent/SIP planning
- Possible impulse purchase

Due-date day:
- Credit card payment
- Mobile/broadband payment

Bad day/stress:
- Late-night food (₹400-800)
- Cab instead of metro

Social weekend:
- Larger food/travel/fashion spends (2-3x normal)

### Aarav Unpredictability Scenarios

1. Job increment: salary increases from ₹1.65L to ₹1.9L
2. Job switch: old salary stops, full-and-final, joining bonus, new salary delayed, new salary starts
3. Work travel: flights/hotel/cabs paid by card, reimbursement later
4. Phone repair: unplanned ₹8000-15000 spend
5. Friend wedding: flight + gift + clothes + hotel (₹25000-40000)
6. Healthcare: doctor + pharmacy (₹2000-8000)
7. Late-night ordering phase: 5-7 consecutive days of late-night food
8. Gadget impulse: large card purchase (₹30000-80000)
9. Credit card partial payment: pays minimum, interest accrues

### What Moné Should Detect for Aarav
- Income pattern changed
- Salary uncertainty
- Reimbursable spend
- Unplanned spend
- Weekend/travel spike
- Healthcare essential spend
- Lifestyle drift
- Goal impact
- Credit discipline risk

---

## Priya — The Goal-Oriented Planner

Profile:
- 35-year-old product manager
- Earns well, stable high salary
- May get bonus or ESOP/dividend
- Household and family responsibilities
- Multiple financial goals
- Investments: SIPs, NPS, insurance
- Spends on: household, family, healthcare, travel, shopping
- Not primarily impulse-driven
- Core anxiety: "Am I still on track despite all commitments?"
- Moné value: goal health, obligation load, scenario planning, goal drift

### Monthly Rhythm

Month start (days 1-10):
- EMI/rent
- Domestic help salary
- SIPs/NPS contributions
- School/family support
- Utility bills
- Goal allocation

Mid month (days 11-20):
- Groceries
- Household items
- Work meals
- Insurance/healthcare maybe
- Shopping for family/home
- Credit card usage accumulates

Month end (days 21-31):
- Credit card payment
- Goal check
- Family transfer
- Travel planning
- May adjust goal priority

### Day-Type Behavior

Weekday:
- Commute/cab (₹150-400)
- Lunch (₹200-500)
- Work coffee (₹100-200)
- Small household orders (₹300-800)

High-work day:
- Food delivery (₹400-700)
- Cab (₹300-500)
- Late dinner (₹300-600)

Saturday:
- Large grocery (₹2000-5000)
- Family outing (₹1500-4000)
- Shopping (₹1000-8000)

Sunday:
- Household planning
- Subscriptions
- Medical/family calls

Salary day:
- Goal allocation
- SIP/NPS
- Bill planning

School/fees month:
- Large education debit (₹15000-50000)

Insurance month:
- Large annual/semi-annual premium (₹20000-60000)

Travel month:
- Flights (₹8000-25000)
- Hotel (₹5000-20000)
- Forex/cabs/restaurants

Healthcare month:
- Doctor (₹500-2000)
- Tests (₹2000-8000)
- Medicine (₹500-3000)

Festival month:
- Gifts (₹2000-10000)
- Clothing (₹3000-15000)
- Travel (₹5000-20000)
- Family support (₹5000-15000)

### Priya Unpredictability Scenarios

1. Increment/bonus: salary rises or bonus credit appears
2. Medical event: hospital/diagnostic/pharmacy spends
3. Parent support: large transfer to family
4. Travel booking: flights/hotel/insurance/cabs
5. Festival: gifts/clothes/sweets/travel
6. Home upgrade: furniture/appliance purchases
7. Work reimbursement: hotel/cab/meal debits, later credit
8. Insurance premium: annual debit
9. Goal reprioritization: emergency fund protected, vacation delayed
10. Credit card high month: due to travel/family

### What Moné Should Detect for Priya
- Goal acceleration opportunity
- Emergency buffer impact
- Goal drift explanation
- Large goal-linked spending
- Predictable annual spike
- Planned expense impact
- Reimbursable spend
- Upcoming obligation
- Trade-off (watch state, not blame)

---

## Behavioral State Library

States that modify spending patterns:

| State | Effect |
|-------|--------|
| Normal | Expected routine pattern |
| Stressed | More food delivery, more cabs, late-night spends |
| Social | Dining, gifts, cabs, events — 2-3x discretionary |
| Frugal | Reduced discretionary, fewer deliveries, more groceries |
| Overconfident after salary | Higher early-month spends, possible shopping/gadget |
| Cautious before salary | Lower discretionary, delayed purchases, card usage rises |
| Travel mode | Flights, hotels, cabs, restaurants — clustered |
| Health event | Doctor, pharmacy, diagnostics, hospital, insurance claim |
| Family event | Gifts, travel, transfers, clothing |
| Work crunch | Dinner delivery, cab, coffee — higher frequency |
| Appraisal month | Bonus/increment, luxury temptation |
| Job-switch phase | Salary gap, reimbursements, joining bonus, reduced discretionary |

---

## Realistic Spending Behavior Rules

### A. Spending is clustered, not evenly distributed

Salary week (week 1): higher confidence, higher spending
Week 2: routine spending
Week 3: fatigue + social spikes
Week 4: cautious or credit-card dependent

Weekend: discretionary spike
Festivals/travel: abnormal clusters

### B. Small spends create invisible leakage

Especially Aarav:
- ₹180 coffee
- ₹360 lunch
- ₹220 cab
- ₹499 app
- ₹640 dinner
- ₹300 snack

Each feels harmless; weekly total becomes meaningful.

Moné should detect: "Small food and commute spends are 34% above your usual pace."

### C. Big spends are often explainable

Especially Priya:
- ₹28,000 hospital
- ₹42,000 school fees
- ₹18,000 flight
- ₹12,000 gift
- ₹32,000 insurance

Moné should NOT label these "bad." It should explain impact:
"This pushes your vacation goal behind by 12 days."

### D. Reimbursements distort spending

Generate:
- Day 4: Flight booking -₹14,500
- Day 5: Hotel -₹8,200
- Day 10: Reimbursement +₹22,700

Moné should detect: "This may be reimbursable. Exclude from lifestyle spend?"

### E. Cash withdrawals create blind spots

Generate ATM withdrawals, then either:
1. Leave unresolved
2. Ask user to classify
3. Estimate slowly from pattern

Moné should show: "₹12,000 withdrawn in cash this month. Should this count as spent?"

---

## Time-of-Day Realism

| Activity | Typical Time |
|----------|-------------|
| Coffee | 10:00–12:00, 15:00–18:00 |
| Lunch delivery | 12:00–14:30 |
| Dinner delivery | 19:30–22:30 |
| Late-night food | 22:30–01:00 |
| Cabs to work | 08:00–10:30 |
| Cabs from work | 18:00–21:30 |
| Grocery | Weekend morning/evening, Sunday evening, salary-week stocking |
| Shopping | Weekend afternoon/evening, Friday night / Saturday |
| Rent/EMI/SIP | Morning banking hours, scheduled auto-debit, usually 1st–10th |
| Credit card payment | Evening, close to due date, sometimes due-date panic |
| Entertainment | Friday/Saturday evening |
| Healthcare | Weekday daytime (emergency any time) |
| Travel bookings | Night/weekend planning |
| Bills | Due date, salary day, weekend catch-up |
| Investments | Salary day + 1 to 5 days |

---

## Dataset Variants

### Aarav Datasets

1. **aarav_spend_control_normal** — Baseline: stable salary, normal spending rhythm, small leakage pattern, goals underperforming
2. **aarav_job_switch** — Old salary stops month 4, F&F settlement, 1-month gap, new salary higher but delayed start
3. **aarav_lifestyle_creep** — Post-increment spending gradually increases: more dining, gadgets, subscriptions, goals stagnate
4. **aarav_wedding_travel_spike** — Friend's wedding in month 6: flight, hotel, clothes, gifts — large cluster, goal impact

### Priya Datasets

5. **priya_goal_planner_normal** — Baseline: stable high salary, multiple goals on track, predictable obligations
6. **priya_healthcare_shock** — Parent hospitalization in month 5: large medical cluster, emergency fund drained, goals delayed
7. **priya_family_provider** — Higher family support: school fees, parent transfers, domestic help — reduces disposable income
8. **priya_bonus_goal_acceleration** — Bonus in month 7: smart allocation accelerates emergency fund and vacation goals
9. **priya_travel_goal_drift** — Two international trips in 12 months: vacation goal drifts as actual travel spend is separate
10. **priya_investor_heavy_low_liquidity** — Heavy SIP/NPS/insurance allocation, low liquid cash, stress when unexpected expense hits

### Later Datasets (Phase 2)

11. **freelancer_irregular_income** — No fixed salary, client payments irregular, planning difficult
12. **self_employed_business_owner** — Business income mixed with personal, GST obligations
13. **debt_burdened_user** — Multiple EMIs, BNPL, credit card revolving
14. **subscription_drifter** — Accumulates unused subscriptions, doesn't notice leakage
15. **cash_withdrawal_blind_spot** — Frequent ATM withdrawals, spending invisible to system

---

## Sample Weeks

### Aarav Sample Week (After Salary)

**Monday** (salary confidence):
- 10:30 Coffee ₹180 UPI (Starbucks)
- 13:00 Lunch ₹350 UPI (Swiggy)
- 18:30 Cab home ₹220 UPI (Uber)
- 20:30 Dinner delivery ₹480 UPI (Zomato)

**Tuesday** (normal office):
- 09:00 Metro ₹60 CARD
- 12:30 Lunch ₹280 UPI (office canteen)
- 16:00 Coffee ₹150 UPI (Blue Tokai)

**Wednesday** (work crunch):
- 09:15 Cab to office ₹240 UPI (Ola)
- 13:00 Lunch ₹320 UPI (Swiggy)
- 21:00 Dinner delivery ₹520 UPI (Zomato)
- 23:30 Late-night snack ₹280 UPI (Swiggy)

**Thursday** (subscription day):
- Spotify auto-debit ₹119 CARD
- iCloud auto-debit ₹75 CARD
- 12:30 Lunch ₹300 UPI

**Friday** (social evening):
- 09:00 Metro ₹60 CARD
- 12:30 Lunch ₹280 UPI
- 19:00 Cab to restaurant ₹350 UPI (Uber)
- 20:30 Dinner with friends ₹1,800 CARD (split: ₹900 actual)
- 23:00 Cab home ₹280 UPI (Ola)

**Saturday** (shopping):
- 11:00 Grocery ₹1,200 UPI (BigBasket)
- 14:00 Zara purchase ₹3,200 CARD
- 16:00 Café ₹350 UPI
- 19:00 Cab ₹180 UPI

**Sunday** (recovery):
- 10:00 Grocery top-up ₹450 UPI (Zepto)
- 12:00 Laundry ₹300 UPI
- 13:30 Food delivery ₹380 UPI (Swiggy)
- 18:00 Dinner delivery ₹420 UPI (Zomato)

**Expected Moné insight:** "You've spent 41% of your weekly flexible budget in 3 days."

### Priya Sample Week (Goal Pressure)

**Monday** (salary day):
- Salary credit ₹2,15,000
- SIP auto-debit ₹25,000
- NPS auto-debit ₹10,000
- Goal allocation transfer ₹15,000

**Tuesday** (household):
- Domestic help salary ₹8,000 CASH
- Groceries ₹3,500 UPI (BigBasket)
- Household items ₹1,200 UPI (Amazon)

**Wednesday** (parent medical):
- Doctor consultation ₹1,500 CARD
- Diagnostics ₹4,500 CARD
- Pharmacy ₹800 UPI

**Thursday** (workday):
- Cab ₹400 UPI
- Lunch ₹450 UPI
- Coffee ₹200 UPI

**Friday** (travel booking):
- Flight booking ₹18,000 CARD
- Hotel booking ₹12,000 CARD

**Saturday** (family shopping):
- Clothing for family ₹8,000 CARD
- Family dining ₹3,500 CARD

**Sunday** (review):
- Credit card bill payment ₹45,000
- Review goals — vacation may slip by 12 days

**Expected Moné insight:** "Your emergency fund is still protected, but vacation may slip by 12 days."
