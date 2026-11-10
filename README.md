# WorldDominion — World PvP

لعبة Roblox استراتيجية لحظية مبنية حول خريطة عالمية/إقليمية بكسلات، توسع متصل، اقتصاد، مبانٍ، أسلحة نووية، وذكاء اصطناعي.

المشروع انتقل نهائيًا من نظام **Island Dominion** القديم إلى مسار **World PvP**. نظام Island Dominion القديم لم يعد جزءًا من شجرة Rojo runtime وتم تنظيف ملفاته غير المستخدمة.

## Runtime الحالي

```
WorldDominion/
├── default.project.json
├── client_worldpvp/
│   └── WorldPvPClient.client.lua
├── server_worldpvp/
│   └── WorldPvPGame.server.lua
├── shared/
│   └── WorldPvP/
│       ├── CountryMapData.lua
│       ├── MapRegistry.lua
│       ├── PixelWorldState.lua
│       ├── RateLimiter.lua
│       ├── RemoteValidation.lua
│       ├── Rules.lua
│       └── TileMap.lua
└── tests/
    └── WorldPvPTests.lua
```

## تدفق اللعب

1. اللاعب يظهر في لوبي 3D عند بيت **404 FOUND**.
2. يختار Teams أو FFA أو Solo.
3. يختار World أو Europe أو Asia أو Middle East.
4. يدخل من **ENTER WORLD**.
5. بعد الدخول تصبح خريطة البكسلات هي مساحة اللعب الرئيسية.
6. يختار نقطة بداية، ثم يهاجم الأراضي المجاورة ويطور الاقتصاد والمباني.

## Server Authority

العميل لا يقرر نتيجة أي عملية استراتيجية.

العميل يرسل فقط نية اللاعب عبر RemoteEvent:
- Spawn
- Attack
- Build
- Nuke
- SelectMode
- SelectMap
- RequestSnapshot

الخادم يتحقق من:
- حالة المباراة وعضوية اللاعب فيها.
- صحة أنواع المدخلات.
- حدود رقم الخلية.
- صحة نوع البناء والسلاح.
- الحد الأدنى للهجوم.
- من يملك الخلية ومن يمكن مهاجمته.
- الحماية، التحالفات، الأرض والملاحة.
- الموارد والتكاليف والتبريد والنتيجة النهائية.

## Remote Security

يوجد الآن:
- `RateLimiter.lua`: حد مستقل لكل لاعب ولكل نوع إجراء.
- `RemoteValidation.lua`: تحقق موحد من integers والخيارات المسموحة.
- منع `RequestSnapshot` من إدخال اللاعب إلى المباراة دون المرور من **ENTER WORLD**.
- تنظيف حالة الـrate limiter عند مغادرة اللاعب.
- رفض payloads غير الصالحة قبل وصولها إلى محرك المباراة.

التزامات التقريبية الحالية:
- Attack: 0.15s
- Build: 0.25s
- Spawn: 0.5s
- SelectMode/SelectMap: 0.35s
- EnterWorld: 0.75s
- Nuke: 1.0s
- Snapshot request: 1.0s

## Client Performance / Mobile

الواجهة الجديدة:
- Mobile-first touch targets.
- أزرار رئيسية بحجم يقارب 44px أو أكثر.
- صفوف تحكم أفقية قابلة للتمرير على الشاشات الضيقة.
- Pan بالماوس واللمس.
- Zoom متدرج مع fit تلقائي للخريطة.
- تحديثات EditableImage event-driven بدل إعادة بناء الخريطة كاملة.
- تجميع tile changes المتجاورة في runs قبل الكتابة للصورة.

## الاختبارات

الاختبارات النشطة في:
`tests/WorldPvPTests.lua`

وتغطي:
- الخرائط الإقليمية.
- spawn.
- الهجوم والاتصال.
- حماية spawn.
- retreat/refund.
- buildings.
- RemoteValidation.
- RateLimiter.

## التشغيل

بعد سحب آخر نسخة:

```bat
git pull --ff-only
rojo build -o IslandDominion.rbxlx
```

ثم افتح الملف الناتج في Roblox Studio واختبر:
- Edit mode: لوبي 404 FOUND ظاهر.
- Play: اختيار mode/map ثم ENTER WORLD.
- Desktop.
- Mobile Device Emulator.

مهم: نجاح/فشل أمر Rojo المحلي يجب التحقق منه من نفس جهاز التطوير لأن هذا المستودع لا يقوم بتشغيل Roblox Studio محليًا.

## Persistence

لا يوجد DataStore/اقتصاد دائم حاليًا. حالة المباراة والجيش والذهب تعيش داخل جلسة الخادم فقط. لن تتم إضافة persistence قبل تثبيت gameplay الأساسي واختبار multiplayer الحقيقي.

## التصميم

الهوية الحالية تستخدم:
forest green / olive / earth brown / gold / clay / ivory

ولا تعتمد على واجهات زرقاء أو blue gradients.

## ملاحظات الملكية

هذا تنفيذ Roblox أصلي مستوحى من بنية ألعاب السيطرة على الأراضي في هذا النوع، ولا يعتمد على source code خاص أو assets خاصة بلعبة أخرى.
