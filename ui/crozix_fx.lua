-- CrozixFX v1.0 — طبقة الحركة والإضاءة للوحة Crozix
-- -----------------------------------------------------------------------------
-- مكان اللصق: داخل CROZIX_BUILD، بعد تعريف helper الـ card() مباشرة (قسم HELPERS)،
-- لأن الكيت يقرأ نفس الـ upvalues: new / corner / stroke / tw / T / CROZIX.
-- نقاط النداء كلها في ui/FX_INTEGRATION.md — كل واحدة سطر أو سطرين في موضعها.
--
-- القواعد:
--   * صفر RenderStepped جديد — كل الحلقات TweenService (RepeatCount = -1).
--   * كل حلقة زخرفية مسجّلة في سجلّ محلي يعمل sync مع CROZIX.applyEffects،
--     فزر Glass الحالي يوقف/يشغّل كل شيء من غير سطر إضافي.
--   * press وripple وpop وstagger مش زخرفة — دي إجابة اللمس، فشغالة دايمًا.
--   * كل خاصية ممكن الـ engine يرفضها ملفوفة pcall (نفس أسلوب باقي الملف).

local FX = {}
CROZIX.FX = FX

local M = CROZIX.D.MOTION
local E = {
	out = Enum.EasingStyle.Quint,
	quart = Enum.EasingStyle.Quart,
	quad = Enum.EasingStyle.Quad,
	back = Enum.EasingStyle.Back,
	linear = Enum.EasingStyle.Linear,
}
local OUT, IN, INOUT = Enum.EasingDirection.Out, Enum.EasingDirection.In, Enum.EasingDirection.InOut

-- ================= سجلّ الحلقات (اللي يخلي Lite يشتغل) =================
local registry = {}
local function startRec(r)
	if not r.playing then
		r.start()
		r.playing = true
	end
end
local function stopRec(r)
	if r.playing then
		r.stop()
		r.playing = false
	end
end
local function register(startFn, stopFn)
	local r = { start = startFn, stop = stopFn, playing = false }
	registry[#registry + 1] = r
	if CROZIX.effectsOn() then
		startRec(r)
	end
	return r
end

function FX.sync()
	for _, r in ipairs(registry) do
		if CROZIX.effectsOn() then
			startRec(r)
		else
			stopRec(r)
		end
	end
end
if type(CROZIX.applyEffects) == "function" and not CROZIX.__fxPatched then
	local oldApply = CROZIX.applyEffects
	CROZIX.applyEffects = function()
		oldApply()
		FX.sync()
	end
	CROZIX.__fxPatched = true
end
function FX.shutdown()
	for _, r in ipairs(registry) do
		stopRec(r)
	end
end

-- ================= 1) ضغطة زنبركية (بديل الـ 0.96 المسطّح) =================
-- ينزل 0.95 بـ Quad ثم يرجع بـ Back overshoot خفيف — الإحساس اللي يفرق
-- بين "زر اتحرّك" و"زر اتضغط". دايمًا شغال (مش زخرفة).
function FX.springPress(b, face, sc)
	face = face or b
	sc = sc or b:FindFirstChildOfClass("UIScale")
	if not sc then
		pcall(function()
			sc = new("UIScale", { Scale = 1, Parent = b })
		end)
	end
	if not sc then
		return
	end
	pcall(function()
		b.MouseButton1Down:Connect(function()
			tw(sc, M.Press, { Scale = 0.95 }, E.quad, OUT)
		end)
		b.MouseButton1Up:Connect(function()
			tw(sc, M.Press + 0.09, { Scale = 1 }, E.back, OUT)
		end)
		b.MouseLeave:Connect(function()
			tw(sc, M.Press, { Scale = 1 }, E.quad, OUT)
		end)
	end)
	-- اللمس على الموبايل بيرفع Mouse events هنا أصلًا، فمفيش handler مزدوج
	return sc
end

-- ================= 2) موجة ripple من نقطة اللمس =================
-- دائرة بتتوسع وتختفي من مكان الصباع. زاوية القص بتتنسخ من زاوية الزر
-- نفسه عشان الموجة تعدي حافة الـ pill صح. التكلفة لحظة اللمس فقط.
function FX.ripple(b, color)
	local clip = b:FindFirstChild("FX_Clip")
	if not clip then
		clip = new("Frame", {
			Name = "FX_Clip",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ClipsDescendants = true,
			ZIndex = (b.ZIndex or 1) + 5,
			Parent = b,
		})
		local c = b:FindFirstChildOfClass("UICorner")
		if c then
			c:Clone().Parent = clip
		end
	end
	pcall(function()
		b.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch
				and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			local pos, size = b.AbsolutePosition, b.AbsoluteSize
			local dot = new("Frame", {
				BackgroundColor3 = color or T.Glow,
				BackgroundTransparency = 0.55,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(0, 0),
				Position = UDim2.fromOffset(input.Position.X - pos.X, input.Position.Y - pos.Y),
				ZIndex = clip.ZIndex,
				Parent = clip,
			})
			new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
			local d = math.max(size.X, size.Y) * 2.1
			tw(dot, 0.45, { Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1 }, E.out, OUT)
			task.delay(0.5, function()
				pcall(function() dot:Destroy() end)
			end)
		end)
	end)
end

-- ================= 3) ظهور متتابع لعناصر حاوية =================
-- كل GuiObject ابن بينزلق 10px من تحت + فيد، بتأخير متدرّج. ده اللي يخلي
-- تبديل الـ section يحس إن الصفحة "بتتبني" بدل ما تظهر فجأة.
function FX.stagger(container, per)
	per = per or 0.035
	local i = 0
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then
			i += 1
			local p0 = child.Position
			local bt = child.BackgroundTransparency
			local tt = nil
			pcall(function() tt = child.TextTransparency end)
			child.Position = UDim2.new(p0.X.Scale, p0.X.Offset, p0.Y.Scale, p0.Y.Offset + 10)
			child.BackgroundTransparency = 1
			pcall(function() child.TextTransparency = 1 end)
			task.delay((i - 1) * per, function()
				local props = { Position = p0, BackgroundTransparency = bt }
				if tt then
					props.TextTransparency = tt
				end
				tw(child, props, M.Section, E.out, OUT)
			end)
		end
	end
end

-- ================= 4) انتقال الـ panes المطوّر =================
-- بديل سطر الـ tween الواحد في showSection: نفس الانزلاق + stagger داخلي
-- للمحتوى. dirn = ±1 حسب اتجاه التبديل (زي ما هو محسوب عندك).
function FX.paneTransition(pane, dirn)
	pane.Position = UDim2.fromOffset(0, dirn * 16)
	tw(pane, 0.24, { Position = UDim2.fromOffset(0, 0) }, E.quart, OUT)
	FX.stagger(pane, 0.03)
end

-- ================= 5) دخول التوست برَفعة خفيفة =================
-- التوست الحالي بيعمل fade في مكانه؛ دي تضيف 6px صعود مع الفيد.
-- النداء جوه makeToast عند alpha(0, 0.16) — انظر دليل التركيب.
function FX.liftIn(obj, dist, dur)
	local p0 = obj.Position
	obj.Position = UDim2.new(p0.X.Scale, p0.X.Offset, p0.Y.Scale, p0.Y.Offset + (dist or 6))
	tw(obj, dur or 0.18, { Position = p0 }, E.quart, OUT)
end

-- ================= 6) نبضة القيمة (للـ stats) =================
-- لما FPS/Ping/Players تتحدث، الرقم يعمل pop صغير (1 -> 1.07 -> 1)
-- بدل ما يقفز نصّ فجأة.
function FX.pop(label)
	local sc = label:FindFirstChildOfClass("UIScale")
	if not sc then
		pcall(function()
			sc = new("UIScale", { Scale = 1, Parent = label })
		end)
	end
	if not sc then
		return
	end
	tw(sc, 0.08, { Scale = 1.07 }, E.quad, OUT)
	task.delay(0.08, function()
		tw(sc, 0.16, { Scale = 1 }, E.quart, OUT)
	end)
end

-- ================= 7) نقطة حالة بتتنفّس =================
-- لأي dot حالة (Attached / حماية شغالة): وميض بطيء.
-- مسجّل => بيقف في Lite.
function FX.pulseDot(dot)
	local tw0
	register(function()
		pcall(function()
			tw0 = TweenService:Create(dot,
				TweenInfo.new(0.9, E.linear, INOUT, -1, true),
				{ BackgroundTransparency = 0.7 })
			tw0:Play()
		end)
	end, function()
		if tw0 then
			tw0:Cancel()
		end
		dot.BackgroundTransparency = 0
	end)
	return dot
end

-- ================= 8) مسح ضوئي دوري على سطح =================
-- خط ضوء رفيع بيعبر الكارت بزاوية كل بضع ثواني (زجاج حي).
-- ClipsDescendants مطلوب على العنصر الأب لو عايد القص على حوافه هو.
function FX.sheenSweep(gui, interval)
	local wrap = new("Frame", {
		Name = "FX_Sheen",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = (gui.ZIndex or 1) + 3,
		Visible = CROZIX.effectsOn(),
		Parent = gui,
	})
	local streak = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.92,
		Rotation = 16,
		Size = UDim2.new(0.10, 0, 2, 0),
		Position = UDim2.fromScale(-0.3, -0.5),
		ZIndex = wrap.ZIndex,
		Parent = wrap,
	})
	local tw0
	register(function()
		wrap.Visible = true
		pcall(function()
			-- TweenService مباشر عشان ناخد RepeatCount + DelayTime بين المسحات
			tw0 = TweenService:Create(streak, TweenInfo.new(
				0.9, E.quad, OUT, -1, false, interval or 4),
				{ Position = UDim2.fromScale(1.3, -0.5) })
			tw0:Play()
		end)
	end, function()
		if tw0 then tw0:Cancel() end
		wrap.Visible = false
	end)
	return wrap
end

-- ================= 9) عدّاد رقمي (NumberValue => صفر تكلفة إطارات) =================
function FX.countUp(label, target, fmt, dur)
	local v
	pcall(function()
		v = Instance.new("NumberValue")
	end)
	if not v then
		label.Text = tostring(target)
		return
	end
	fmt = fmt or function(n)
		return tostring(math.floor(n + 0.5))
	end
	local conn = v.Changed:Connect(function(n)
		label.Text = fmt(n)
	end)
	v.Value = 0
	local tr = TweenService:Create(v, TweenInfo.new(dur or 0.8, E.out, OUT), { Value = target })
	tr:Play()
	task.delay((dur or 0.8) + 0.1, function()
		conn:Disconnect()
		pcall(function() v:Destroy() end)
	end)
end

-- ================= 10) إضافة جديدة: Sparkline للـ FPS =================
-- رسم تاريخي صغير (أعمدة) لقراءة الـ FPS جنب الرقم. 24 عمود، بيتحدث
-- من نفس tick الإحصاءات الموجود (كل 0.5 ثانية) => صفر حلقات جديدة.
-- النداء: بناء مرة واحدة بعد statCell، وupdate من جوه حلقة الـ stats.
function FX.sparkline(parent, pos, w, h, color, max)
	local holder = new("Frame", {
		Name = "CrozixSparkline",
		BackgroundTransparency = 1,
		Position = pos,
		Size = UDim2.fromOffset(w, h),
		Parent = parent,
	})
	local N = 24
	local gap = 1
	local bw = math.floor((w - (N - 1) * gap) / N)
	local bars, values = {}, {}
	for i = 1, N do
		values[i] = 0
		local bar = new("Frame", {
			BackgroundColor3 = color or T.Accent,
			BackgroundTransparency = 0.35,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromOffset((i - 1) * (bw + gap), h),
			Size = UDim2.fromOffset(bw, 1),
			Parent = holder,
		})
		bars[i] = bar
	end
	local ceil = max or 60
	return {
		Root = holder,
		push = function(v)
			table.remove(values, 1)
			values[N] = v
			for i = 1, N do
				local bh = math.clamp(values[i] / ceil, 0.04, 1) * (h - 2)
				tw(bars[i], 0.3, { Size = UDim2.fromOffset(bw, math.max(bh, 1)) }, E.quad, OUT)
			end
		end,
	}
end

return FX
