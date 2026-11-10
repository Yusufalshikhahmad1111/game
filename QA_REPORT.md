# QA Report — WorldDominion World PvP

**الحالة:** Active development / security hardening

## تم تنفيذه

### Architecture cleanup
- حذف ClientController القديم.
- حذف GameManager/RemoteSetup/WorldBootstrap القديم.
- حذف MapData ومحرك Island Dominion القديم.
- حذف CoreTests القديمة التي كانت تعتمد على المحرك المحذوف.
- حذف WorldMap/WorldSeed/WorldState القديمة غير المستخدمة.
- أبقي فقط PixelWorldState + TileMap + MapRegistry كمسار World PvP الفعلي.

### Security hardening
- Server-authoritative gameplay.
- RateLimiter لكل لاعب ولكل نوع إجراء.
- RemoteValidation مشترك.
- رفض tile IDs غير الصحيحة.
- رفض attack amounts غير الصحيحة.
- whitelist للبناء.
- whitelist للأسلحة النووية.
- whitelist لأنماط اللعب.
- RequestSnapshot لم يعد قادرًا على إدخال لاعب للمباراة دون ENTER WORLD.
- تنظيف limiter عند PlayerRemoving.

### UI / UX
- responsive World PvP HUD.
- touch-friendly controls.
- horizontal scrolling action rows.
- mouse/touch pan.
- responsive map panel/ranking.
- automatic map fit.
- troop input normalization.
- current earth-tone visual language.

### Performance
- EditableImage واحدة.
- delta updates.
- grouped contiguous pixel writes.
- لا يوجد update دوري 60fps للخريطة نفسها.

## Tests

تمت إضافة حالات جديدة إلى `WorldPvPTests.lua` لـ:
- RemoteValidation.
- RateLimiter.

لا أصف اختبارات Roblox Studio runtime بأنها ناجحة من هذه البيئة؛ تشغيل Roblox Studio وRojo المحلي يجب التحقق منه على جهاز التطوير.

## Remaining verification

1. تشغيل `rojo build` محليًا بعد التنظيف.
2. Play test داخل Roblox Studio.
3. Mobile Device Emulator.
4. اختبار spam للـRemoteEvents.
5. اختبار لاعب ثانٍ يدخل نفس المباراة.
6. اختبار end-to-end لـ Teams / FFA / Solo.
7. اختبار الأداء على خريطة World الكاملة.

## Persistence

DataStore غير مضاف حاليًا. هذا مقصود حتى لا نخلط persistence مع تثبيت gameplay الأساسي.

