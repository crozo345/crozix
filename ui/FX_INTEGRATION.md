# CrozixFX — دليل التركيب

`ui/crozix_fx.lua` طبقة حركة/إضاءة drop-in مكتوبة على أسماء الـ helpers الموجودة فعلًا في `crozix.lua`
(`new` / `corner` / `stroke` / `tw` / `T` / `CROZIX.trackEffect` / `CROZIX.D.MOTION`).

## التركيب

الملف معمول عشان يتلصق **كتلة داخل `CROZIX_BUILD`** بعد تعريف `card()` في قسم HELPERS
(لأنه يقرأ نفس الـ upvalues). الأنظف: يتضمّن في `ui/crozix_ui_reference.lua` عبر الـ generator،
لأن `crozix.lua` نفسه مولّد (`Do not hand-edit`).

```lua
local FX = (function()
    -- ... محتوى crozix_fx.lua ...
    return FX
end)()
```

## نقاط النداء (كل واحدة سطر في موضعها الحالي)

| # | المكان الحالي في crozix.lua | الاستبدال/الإضافة |
|---|---|---|
| 1 | `styleButton` — سطور `MouseButton1Down/Up` بتاعة الـ scale | `FX.springPress(b, face, sc)` بدل tween الـ 0.96 |
| 2 | `styleButton` بعد الـ spring | `FX.ripple(b)` — موجة لمس على كل زر (تلقائي مع أي زر) |
| 3 | `showSection` — سطر `tween(nextPane, 0.24, {...})` | `FX.paneTransition(nextPane, dirn)` — انزلاق + المحتوى يظهر متتابع |
| 4 | `makeToast` — بعد `alpha(0, 0.16)` | `FX.liftIn(Host, 6, 0.18)` — التوست بيطلع برَفعة بدل fade ساكن |
| 5 | حلقة الـ stats — بعد كل `fpsLabel.Text = ...` (وكذلك ping/players) | `FX.pop(fpsLabel)` — نبضة صغيرة مع كل تحديث |
| 6 | بعد `statCell`: `local spark = FX.sparkline(Info, UDim2.fromOffset(14, 118), 186, 16)` ثم في حلقة الـ stats | `spark.push(fps)` — رسم تاريخي متحرك للـ FPS (إضافة جديدة) |
| 7 | بعد بناء `EditorCard` | `FX.sheenSweep(EditorCard, 6)` — مسح ضوئي دوري (بيقف في Lite) |
| 8 | `makeSwitch` — داخل `sw.set` بعد tween الـ knob | الـ knob يتمدد لـ 24×20 وهو بيسافر ثم يرجع 20×20 |
| 9 | أي dot حالة (dot التوست، dots الحماية) | `FX.pulseDot(dot)` — نقطة بتتنفّس |
| 10 | أي رقم فوري محتاج عدّاد (شاشة المفاتيح مثلًا) | `FX.countUp(label, target)` — اختياري |

## ليه كده؟

- **صفر حلقات جديدة**: كل التكرارات `TweenService` بـ `RepeatCount = -1`، والعدّادات على `NumberValue`.
- **Lite شغال تلقائيًا**: كل حلقة زخرفية (sheen/pulse) مسجّلة في سجلّ بيعمل `sync` مع `CROZIX.applyEffects`
  — زر Glass الحالي يوقفها كلها من غير تعديل تاني.
- **اللمس مش زخرفة**: `springPress` و`ripple` و`pop` و`stagger` بيفضلوا شغالين دايمًا،
  بنفس منطق الـ press scale الموجود عندك بالفعل.
- **مفيش تعديل على الـ layout**: كل الإضافات layer فوق العناصر الموجودة أو tween عليها —
  مش بتلمس هندسة الـ 700×380 ولا الـ touch floor ولا أسماء الـ widgets المسجلة (`CROZIX.register`).
- كل خاصية ممكن الـ engine يرفضها ملفوفة `pcall` (UIStroke/UIGradient/NumberValue/ClipsDescendants).
