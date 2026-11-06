# Architecture — Island Dominion

نظرة عامة على architecture اللعبة بعد جميع مراحل التطوير (M0–M7 + Final Stabilization).

---

## 1. نظرة عامة عالية المستوى

اللعبة تتبع架构 **Client–Server Authoritative** مع فصل واضح بين:
- **Shared Engine:** منطق اللعبة المستقل عن واجهة المستخدم (plain Lua modules)
- **Server Scripts:** إدارة الحالة، التحقق من المدخلات، الذكاء الاصطناعي، القوى، الأحداث
- **Client Script:** واجهة المستخدم فقط، ترسل طلبات للخادم وتعرض حالة اللعبة

---

## 2. هيكل المجلدات (Rojo)

```
IslandDominion/
├── default.project.json          # إعدادات Rojo
├── README.md
├── QA_REPORT.md
├── ARCHITECTURE.md
├── .gitignore
├── shared/                       # وحدات مشتركة (Server + Client)
│   ├── MapData.lua               # بيانات الخريطة، الألوان، أنواع الأراضي، السمات
│   └── Engine/                   # محرك اللعبة
│       ├── Cell.lua              # نموذج الخلية مع clone()
│       ├── Board.lua             # إدارة الشبكة، الجيران، التسلسل
│       ├── GameState.lua         # حالة المباراة الكاملة مع clone()
│       ├── TurnManager.lua       # إدارة الأدوار
│       ├── ResourceSystem.lua    # أنواع الموارد
│       ├── WinSystem.lua         # شرط الفوز
│       ├── CaptureSystem.lua     # منطق الاحتجاز (يعمل على real أو clone board)
│       ├── ValidationSystem.lua  # التحقق من المدخلات
│       ├── PowerSystem.lua       (M5)  # القوى السيادية مع التأثيرات الفعلية
│       ├── EventSystem.lua       (M5)  # الأحداث العالمية مع تأثيرات الإنتاج
│       ├── MatchModifierSystem.lua (M5)  # معدلات المباراة
│       ├── ProgressionSystem.lua (M5)  # XP، رتب، إنجازات
│       ├── MultiplayerManager.lua (M6) # لوب، فرق، مهلة دور، قطع اتصال
│       ├── AIConfig.lua          (M3)  # شخصيات AI وأوزانها
│       └── AIPlayer.lua          (M3)  # محرك الذكاء الاصطناعي مع محاكاة آمنة
├── server/                       # سكربتات الخادم فقط
│   ├── RemoteSetup.server.lua    # إنشاء RemoteEvents بشكل آمن ومضمون
│   └── GameManager.server.lua    # مدير اللعبة (server authority)
├── client/                       # سكريبت العميل فقط
│   └── ClientController.client.lua # واجهة المستخدم مع تحديثات تفاضلية
├── tests/                        # اختبارات انعكاسية
│   └── CoreTests.lua             # ~116 اختبار للوحدات الأساسية
└── ServerStorage/Tests/          # (في Rojo) مجموعة الاختبارات
```

---

## 3. تدفق البيانات

### 3.1 بدء المباراة
1. العميل ينضم إلى اللوب عبر `JoinLobby`
2. الخادم يعيّن فريقاً للاعب (Player / AI1 / AI2)
3. العميل يضبط حالة "جاهز" عبر `SetReady`
4. عند الجاهزية، العميل يبدأ المباراة عبر `StartMatch`
5. الخادم يُنشئ `GameState` جدید، يُهيئ لاعبي AI للفرق الفارغة، يبث الحالة الأولية

### 3.2 دور اللاعب
1. العميل يختار لوناً عبر `SelectColor`
2. الخادم يتحقق: اللعبة نشطة، دور هذا اللاعب، لون صالح، معدل الطلبات مقبول
3. الخادم ينفذ `CaptureSystem.capture()` على اللوحة الحقيقية
4. الخادم يضيف موارد `baseYield` لفريق اللاعب
5. الخادم يتحقق من شرط الفوز
6. إذا لم ينتهِ، الخادم يرفع دور، يولد إنتاج الموارد لكل الفرق، يطبق أحداث عالمية، يُبث الحالة لجميع العملاء
7. إذا كان الدور التالي لـ AI، يُنفّذ دور الذكاء الاصطناعي بعد تأخير 1.2 ثانية

### 3.3 دور الذكاء الاصطناعي
1. الخادم يستنسخ `GameState` بالكامل (`gameState:clone()`)
2. AI يقيّم كل لون على النسخة المستنسخة (لا تؤثر على اللوحة الحقيقية)
3. AI يختار أفضل لون وفقاً لأوزان شخصيته (Warlord/Merchant/Guardian/Trickster)
4. الخادم يطبق الاختيار على اللوحة الحقيقية عبر `CaptureSystem`
5. يتحقق من الفوز ويرفع الدور

### 3.4 استخدام القوة (Power)
1. العميل يرسل `UsePower` مع اسم القوة وخلية الهدف (اختياري)
2. الخادم يتحقق: دور هذا الفريق، تكلفة القوة متاحة، غير على تبريد
3. الخادم يخصم التكلفة، يُفعّل التبريد العالمي، ينفذ التأثير على اللوحة
4. الخادم يُبث حالة القوى لجميع العملاء

---

## 4. المكونات الأساسية

### 4.1 GameState (Source of Truth)
تحتوي على:
- `board`: شبكة الخلايا مع أنواع الأراضي والموارد
- `turnManager`: تسلسل الأدوار (Player → AI1 → AI2)
- `teamResources`: موارد كل فريق (Gold, Food, Wood, Relic)
- `gameActive`, `winner`: حالة المباراة
- `matchRecorded`: علم لمنع تسجيل التقدم مراراً

يدعم `clone()` آمناً للمحاكاة بواسطة AI بدون تأثير على الحالة الحقيقية.

### 4.2 Board
- شبكة ثنائية الأبعاد من خلايا `Cell`
- حساب الجيران عند الطلب (بدون مراجع حية بين الخلايا)
- دعم `clone()` و `serialize()` للإرسال للعميل
- أنواع الأراضي مع `baseYield` (مكافأة احتجاز)، `productionPerTurn` (إنتاج دوري)، `strategicValue`, `defenseModifier`

### 4.3 CaptureSystem
- يجد جميع الخلايا المجاورة لأراضي الفريق التي تحمل اللون المختار
- يزيل التكرارات عبر `cell.id`
- يطبق الاحتجاز على اللوحة (real أو clone)
- يعيد قائمة الخلايا المحتجزة ومجموع `baseYield` كموارد مكتسبة

### 4.4 ValidationSystem
- `validateColor()`, `validateMapSize()`, `validateTurn()`, `validateGameActive()`
- تُستدعى على السيرفر قبل كل إجراء من العميل

### 4.5 MultiplayerManager
- تعيين اللاعبين للفرق (Player فقط للإنسان، AI1/AI2 للذكاء الاصطناعي)
- حالة اللوب (Waiting / Ready / InMatch)
- مهلة الدور عبر `task.delay` مع إلغاء عبر `task.cancel()`
- تقييد معدل الطلبات (10 طلبات في الدقيقة لكل لاعب)
- معالجة قطع الاتصال: AI يستولي على فريق اللاعب المنقطع
- رؤية خاصة لكل لاعب: الموارد تُرسل فقط لمالك الفريق

### 4.6 PowerSystem
- 6 قوى مع تكلفة، تبريد، وتأثير فعلي
- تأثيرات عالمية (بالمدة) وتأثيرات خاصة بكل فريق (TeamEffects)
- `executePower()` ينفذ التأثير على اللوحة والسيرفر موثوق (server-authoritative)

### 4.7 EventSystem
- 5 أحداث عالمية مع مدة وتأثير على إنتاج الموارد
- `getProductionModifier()` يعيد معدل修正 لإنتاج كل نوع أرضية
- تُفعّل عشوائياً في نهاية كل دور مع احتمال basé على معدل المباراة

### 4.8 ProgressionSystem
- XP، مستويات (Bronze → Dominion)، إنجازات، إحصائيات
- تسجيل مرة واحدة فقط لكل مباراة عبر `matchRecorded`
- لا توجد معاملات مالية (No Pay-to-Win)

---

## 5. أمان (Security)

1. **Server Authority:** جميع الإجراءات تُتحقق منها على السيرفر قبل التنفيذ
2. **Per-Player Visibility:** موارد كل فريق تُرسل فقط لمالك هذا الفريق عبر `FireClient`
3. **Input Validation:** كل远程 إجراءات تُتحقق منها (اللون، حجم الخريطة، الدور، القوة)
4. **Rate Limiting:** 10 طلبات في الدقيقة لكل لاعب لمنع السبام
5. **No Secrets:** لا توجد كلمات مرور أو مفاتيح في المستودع (service.json محذوف، .gitignore مضاف)

---

## 6. الأداء (Performance)

1. **Diff-based UI Updates:** العميل يقارن سمات الخلايا (Owner, TerrainType) ويُحدّث ما تغير فقط، بدون إعادة بناء الخريطة بالكامل
2. **No JSON Encode/Decode في التحديثات:** السمات تُقرّر مباشرة عبر `GetAttribute`/`SetAttribute`
3. **GUI Instance Reuse:** أزرار الخلايا تُنشأ مرة واحدة وتُحدّث سماتها فقط
4. **AI Simulation Isolation:** المحاكاة تعمل على نسخة مستنسخة من الحالة، لا تخصيص للذاكرة على اللوحة الحقيقية

---

## 7. 확장性 (Extensibility)

1. **أنواع أراضي جديدة:** إضافة entrées في `MapData.TerrainTypes` و `MapData.MapThemes`
2. **قوى جديدة:** إضافة entrées في `PowerSystem.Powers` وتنفيذها في `executePower()`
3. **أحداث جديدة:** إضافة entrées في `EventSystem.Events`
4. **شخصيات AI جديدة:** إضافة entrées في `AIConfig.Personalities` مع أوزان مخصصة
5. **أحجام خرائط جديدة:** إضافة entrées في `MapData.AvailableSizes`

---

## 8. إدارة الحزم (Rojo)

`default.project.json` يحدد كافة الملفات ومساراتها في شجرة Roblox. للبناء:
```bash
rojo build
```
ينتج ملف `.rbxlx` يمكن فتحه في Roblox Studio.