# Architecture — WorldDominion World PvP

## 1. Runtime authority

`default.project.json` يربط فقط المسار الحالي:

- `client_worldpvp/` → `StarterPlayerScripts`
- `server_worldpvp/` → `ServerScriptService`
- `shared/` → `ReplicatedStorage.Shared`
- `tests/` → `ServerStorage.Tests`
- `Workspace.Lobby` → اللوبي ثلاثي الأبعاد.

نظام Island Dominion القديم أزيل من ملفات runtime، ولا يوجد ClientController قديم أو GameManager قديم داخل المشروع الحالي.

## 2. Server

`server_worldpvp/WorldPvPGame.server.lua` مسؤول عن:

- lifecycle المباراة.
- 3D lobby gate.
- RemoteEvent boundaries.
- إرسال snapshots/chunks.
- التحقق من membership والحالة.
- حماية من spam.
- الربط مع `PixelWorldState`.

الخادم هو مصدر الحقيقة الوحيد للقتال والاقتصاد والملكية.

## 3. Shared domain

### PixelWorldState
المحرك الفعلي للمباراة:
- spawn
- connected expansion
- combat
- naval attacks
- buildings
- AI
- gold/troops
- nukes
- victory condition
- metadata/diff snapshots

### TileMap
ينشئ الخريطة النقطية انطلاقًا من الـmap registry والبيانات الجغرافية.

### MapRegistry
يحدد World / Europe / Asia / MENA كخرائط جغرافية مستقلة.

### Rules
مصدر قواعد المباراة والأسعار والـAI والـrender.

### RateLimiter
وحدة pure Luau لتقييد العمليات حسب user/action.

### RemoteValidation
وحدة pure Luau للتحقق من integers والخيارات المسموحة عند حدود RemoteEvents.

## 4. Client

`WorldPvPClient.client.lua` مسؤول عن presentation/input فقط:

- EditableImage rendering.
- camera-like pan/zoom على الخريطة.
- touch/mouse input.
- HUD.
- ranking.
- build/nuke controls.
- عرض notices والنتائج.

العميل لا يملك:
- owner state.
- troop authority.
- gold authority.
- combat outcome.
- building costs.
- victory state.

## 5. Data flow

```
Input
  ↓
WorldPvPClient
  ↓ RemoteEvent
WorldPvPGame
  ↓ validation + rate limit + authorization
PixelWorldState
  ↓
Snapshot / MapChunk
  ↓
WorldPvPClient
```

## 6. Performance

الخريطة 1024×512 كحد أساسي.

الخادم يرسل chunks عند الدخول، ثم diff snapshots على فترات قصيرة.

العميل:
- يحتفظ بـ EditableImage واحدة.
- يكتب تغييرات البكسلات فقط.
- يجمع التغييرات المتجاورة قبل `WritePixelsBuffer`.
- لا يعيد بناء جميع عناصر الخريطة لكل snapshot.
- يتجنب إنشاء UI جديدة لكل click.

## 7. Security boundaries

كل RemoteEvent يمر عبر:

1. type validation.
2. range/choice validation.
3. per-player rate limit.
4. world/match membership.
5. domain validation داخل PixelWorldState.

لا يوجد اعتماد على أن العميل "صادق".

## 8. Persistence

Persistence غير موجود عمدًا في هذه المرحلة. لا يوجد DataStore في مسار المباراة الحالي.

الخطوة المناسبة لاحقًا هي إضافة طبقة persistence مستقلة عن `PixelWorldState` بعد تثبيت gameplay وmultiplayer.

## 9. Testing strategy

`tests/WorldPvPTests.lua` هو test suite النشط.

يجب أن تغطي أي إضافة جديدة:
- valid flow.
- invalid input.
- boundary values.
- exploit-like repeated requests.
- state consistency.
