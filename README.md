# Island Dominion — Living Grid Strategy

لعبة استراتيجية سريعة تعتمد على شبكة مربعات (Color Flood-It style) مع طبقات استراتيجية عميقة:
اقتصاد، أنواع أراضي، قدرات سيادة، أحداث عالمية، ذكاء اصطناعي بشخصيات، ووضع Multiplayer.

---

## 📁 هيكل المشروع

```
IslandDominion/
├── default.project.json          # إعدادات Rojo للبناء
├── README.md                     # هذا الملف
├── shared/
│   ├── MapData.lua               # بيانات الخريطة، الألوان، أنواع الأراضي، السمات
│   └── Engine/                   # محرك اللعبة (plain data + logic)
│       ├── Cell.lua
│       ├── Board.lua
│       ├── GameState.lua
│       ├── TurnManager.lua
│       ├── ResourceSystem.lua
│       ├── WinSystem.lua
│       ├── CaptureSystem.lua
│       ├── ValidationSystem.lua
│       ├── PowerSystem.lua       (M5)
│       ├── EventSystem.lua       (M5)
│       ├── MatchModifierSystem.lua (M5)
│       ├── ProgressionSystem.lua (M5)
│       ├── MultiplayerManager.lua (M6)
│       ├── AIConfig.lua          (M3)
│       └── AIPlayer.lua          (M3)
├── server/
│   ├── RemoteSetup.server.lua    # إنشاء RemoteEvents بشكل آمن
│   └── GameManager.server.lua    # مدير اللعبة (server authority)
├── client/
│   └── ClientController.client.lua # واجهة المستخدم (LocalScript)
└── tests/
    └── CoreTests.lua             (M7) اختبارات انعكاسية للوحدات الأساسية
```

---

## 🚀 طريقة التشغيل

### باستخدام Rojo (مستحسن)

1. تأكد أن لديك [Rojo](https://rojo.space/) مثبتاً.
2. في مجلد المشروع، شغّل:
   ```bash
   rojo build
   ```
3. سيولد ملف `.rbxlx` يمكن فتحه في **Roblox Studio**.
4. اضغط **Play** لبدء اللعبة.

### بدون Rojo (نسخ ولصق يدوي)

إذا لم تستخدم Rojo، أنجب الملفات التالية في Roblox Studio يدوياً:

| المسار في Studio | نوع الملف | الملف المصدر |
|------------------|-----------|-------------|
| `ReplicatedStorage/Shared/MapData` | ModuleScript | `shared/MapData.lua` |
| `ReplicatedStorage/Shared/Engine/*` | ModuleScript | `shared/Engine/*.lua` |
| `ReplicatedStorage/GameRemotes` | Folder (تُنشأ تلقائياً) | — |
| `ServerScriptService/RemoteSetup` | Script | `server/RemoteSetup.server.lua` |
| `ServerScriptService/GameManager` | Script | `server/GameManager.server.lua` |
| `StarterPlayer/StarterPlayerScripts/ClientController` | LocalScript | `client/ClientController.client.lua` |
| `ServerStorage/Tests/CoreTests` | ModuleScript | `tests/CoreTests.lua` |

---

## 🎮 قواعد اللعب

1. تبدأ كل لعبة على شبكة 10×10 (أو 15×15، 20×20).
2. كل خلية لها نوع أرضية (سهل، غابة، منجم، آثار، حصن، عاصمة، ميناءً) ولون تضاريس.
3. في دورك، اختر لوناً واحداً؛ تُحتجز جميع الخلايا المجاورة لأراضيك التي تحمل ذلك اللون وت become ملكك.
4. عند احتجاز خلية، تحصل على مكافأة一次ية (baseYield) وتضيف إنتاجها الدوري إلى مواردك.
5. ثم يلعب الخصوم (AI أو لاعبين آخرين) بنفس المنطق.
6. تربح عندما تسيطر على **جميع** خلايا الخريطة (100%).

---

## 🧠 أنواع الأراضي

| النوع | الرمز | المكافأة عند الاحتجاز | الإنتاج لكل دور | القيمة الاستراتيجية | الدفاع |
|-------|-------|----------------------|-----------------|-------------------|--------|
| سهل | 🌾 | Food +8 | Food +2 | 1 | 0% |
| غابة | 🌲 | Wood +8 | Wood +2 | 2 | 0% |
| منجم | ⛏️ | Gold +10 | Gold +3 | 3 | 0% |
| آثار | 🏛️ | Relic +1 | — | 4 | 0% |
| حصن | 🏰 | Gold +5, Wood +5 | Gold +1, Wood +1 | 5 | 30% |
| عاصمة | 🏛️ | Gold +15, Food +10, Wood +10 | Gold +3, Food +2, Wood +2 | 10 | 50% |
| ميناءً | ⚓ | Gold +7 | Gold +2 | 3 | 0% |

---

## ⚡ قوى السيادة (Powers)

| القوة | التكلفة | التبريد | التأثير |
|-------|--------|---------|--------|
| كشّاف (Scout) | 50 Gold | 3 أدوار | كشف منطقة مؤقتاً |
| حصاد (Harvest) | 30 Gold, 20 Food, 10 Wood | 4 أدوار | مضاعفة إنتاج إقليم لدورين |
| تحصين (Fortify) | 40 Gold, 10 Food, 20 Wood | 3 أدوار | رفع دفاع إقليم ally |
| تخريب (Sabotage) | 60 Gold, 30 Food | 5 أدوار | خفض إنتاج إقليم خصم لدور واحد |
| تغيير لون (Color Shift) | 80 Gold, 40 Food, 40 Wood | 6 أدوار | إعادة رول محدود للألوان |
| موجة صدمية (Shockwave) | 100 Gold, 50 Food, 50 Wood | 8 أدوار | توسع من نقطة معينة مرة استثنائية |

---

## 🌍 أحداث عالمية (World Events)

| الحدث | المدة | التأثير |
|-------|-------|---------|
| زخّات النيازك (Meteor Shower) | 2 أدوار | المناجم تصبح أغلى (تكلفة مضاعفة) |
| الأمطار الغزيرة (Great Rain) | 2 أدوار | إنتاج الطعام +30% |
| حريق غابات (Wildfire) | 2 أدوار | الغابات إنتاج أقل بنسبة 50% |
| المد العالي (High Tide) | 3 أدوار | الموانئ تصبح أكثر استراتيجية (+50% القيمة) |
| القافلة المفقودة (Lost Caravan) | 1 دور | مكافأة نادرة تظهر في منطقة عشوائية |

---

## ⚙️ معدلات المباراة (Match Modifiers)

| المعدل | التأثير |
|--------|---------|
| كلاسيكي (Classic) | الوضع القياسي |
| جزر غنية (Rich Islands) | موارد ابتدائية مضاعفة |
| شتاء قاسٍ (Harsh Winter) | إنتاج أقل، أحداث أكثر تكراراً |
| سباق القطع النادرة (Relic Rush) | فرص أعلى للحصول على Relics |
| فوضى (Chaos) | أحداث متكررة وتغيرات سريعة |

---

## 🤖 الذكاء الاصطناعي

### شخصيات AI:
- **Warlord**: يركز على التوسع والهجوم
- **Merchant**: يركز على الموارد والاقتصاد
- **Guardian**: يركز على الدفاع والرأس المال
- **Trickster**: يركز على قطع خطوط الخصوم

### مستويات الصعوبة:
- **Easy**: تقييم خطوتين واحدة، 30% عشوائية
- **Normal**: تقييم تكتيكي، 15% عشوائية
- **Hard**: تقييم خطوتين، 5% عشوائية

---

## 🧪 تشغيل الاختبارات (M7)

تحتوي وحدة `tests/CoreTests.lua` على اختبارات للوحدات الأساسية:
- Board (الخلايا والجيران والتسلسل والعزل)
- Capture System (الاحتجاز والعزل عن الحالة الحقيقية)
- Win System (شرط الفوز)
- Validation System (التحقق من المدخلات)
- AI System (الشخصيات والمستويات والعزل)
- Power System (التكلفة والتبريد)
- Event System (الأحداث والمدة)
- Match Modifier System (المعدلات والموارد الابتدائية)
- Progression System (XP، الرتب، الإنجازات)
- GameState Clone Isolation (أهم اختبار للذكاء الاصطناعي)

لتشغيل الاختبارات في Roblox Studio:
```lua
local Tests = game.ServerStorage.Tests.CoreTests
local result = require(Tests):run()
print("All passed:", result)
```

---

## 🔐 الأمان

- 모든 الإجراءات من العميل تمر عبر تحقق من صحة على السيرفر (اللون، حجم الخريطة، الدور، القوة).
- لا يمكن للعميل تغيير: المالك، الموارد، الدور، حالة الفوز، حالة الذكاء الاصطناعي.
- تقييد معدل الطلبات (Rate Limiting): 10 طلبات في الدقيقة لكل لاعب.
- موارد كل لاعب خاصة به فقط (لا تُرسل موارد الخصوم للعميل).

---

## 📊 مراحل التطوير (مُنَفَّذة)

| المرحلة | الاسم | الحالة |
|---------|-------|--------|
| M0 | Foundation / Boot Repair | ✅ مكتمل |
| M1 | Core Strategy Engine | ✅ مكتمل |
| M2 | Living Map + Economy | ✅ مكتمل |
| M3 | Smart AI + Personalities | ✅ مكتمل |
| M4 | Premium UI/UX + Game Feel | ✅ مكتمل |
| M5 | World Events + Powers + Progression | ✅ مكتمل |
| M6 | Multiplayer + Fairness | ✅ مكتمل |
| M7 | Polish + Performance + Content | ✅ مكتمل |

---

## 🛠️ تحسينات مقترحة للمراحل القادمة

- حفظ البيانات (DataStore) للتقدم والإنجازات.
- دعم لاعبين حقيقيين متعددين عبر Roblox Multiplayer.
- تأثيرات بصرية متقدمة (جسيمات، توهج، تقطيع).
- أصوات حقيقية بدلاً من Placeholders.
- متجر ترقيات داخل اللعبة.
- أLeaderboard عالمي.

---

## 📄 ترخيص

هذا المشروع لأغراض تعليمية وتطويرية. يمكن تعديله وتوزيعه freely.