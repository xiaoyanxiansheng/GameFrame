-- region readme
-- 功能 UI集合加载 显示 隐藏 卸载
-- 流程 设置数据 -> 加载UI列表 -> 显示UI列表 -> 隐藏UI集合 -> 卸载UI集合
-- endregion
WindowStack = class("WindowStack")

-- region public
-- 加载
-- params ： UI打开的参数 #params == #views
function WindowStack:InitViews(initFinishFunc)
    local views = self.initingViews;
    if not views then
        return;
    end

    local allInitCount = #views;
    if allInitCount == 0 then
        return;
    end

    self:AddOpeningViews(views) -- 默认加载时需要显示的ui 后续可以更改

    local initCount = 0;
    for i = 1, allInitCount do
        self:AddInitView(views[i]);
        self:RemoveInitView(views[1]);
        views[i]:Init(function()
            initCount = initCount + 1;
            if allInitCount == initCount then
                if initFinishFunc then
                    initFinishFunc();
                end
            end
        end);
    end
    return self;
end
-- 打开
function WindowStack:OpenStack(isReveal)
    self:OpenView(isReveal);
end
-- 关闭 如果关闭的是主UI则关闭所有已经打开的UI
function WindowStack:CloseView(view)
    -- 主UI被关闭
    if view == self:GetMain() then
        self:CloseViewStack();
    else
        self:CloseViewCore(view);
    end
end
-- endregion

-- region private
function WindowStack:ctor()

    self.initingViews = {};         -- 将要加载的UI
    self.initViews = {};            -- 所有加载UI
    self.openedViews = {};          -- 显示过的UI
    self.openingViews = {};         -- 将要打开UI

    self.params = nil;              -- UI的打开参数

    self.isManuAuto = false;        -- 当前是否是返回操作
end

function WindowStack:OpenView(isReveal)
    local openingViews = self.openingViews;
    if openingViews then
        for i, v in  ipairs(openingViews) do
            self:AddOpenedView(v);
            v:OpenWindow(self.isSkipOpenAim,nil,isReveal);
        end
        table.clear(openingViews);
    end
end
function WindowStack:CloseViewStack()
    -- 是否需要返回 则将需要打开的界面保存到将要打开的列表中
    local openedViews = nil;
    if self:GetManu() then
        self.isManuAuto = false;
        openedViews = {};
        for i, v in ipairs(self.openedViews) do
            table.insert(openedViews,v);
        end
        self:AddOpeningViews(openedViews);
    end

    -- 关闭
    local views = nil;
    if self:GetDestroy() then
        -- 卸载已经加载的UI
        views = self.initViews;
    else
        -- 关闭已经打开的UI
        views = self.openedViews;
    end
    if views then
        -- 关闭的时候会动态删除views列表 所以这里需要使用一个临时的表
        local tempViews = {};
        for i, v in ipairs(views) do
            table.insert(tempViews,v);
        end
        for k,v in pairs(tempViews) do
            self:CloseViewCore(v);
        end
    end
end
function WindowStack:CloseViewCore(view)
    self:RemoveOpenedView(view);
    if self:GetDestroy() then
        self:RemoveInitView(view);
    end
    view:CloseWindow(self:GetDestroy());
end
-- endregion

-- region set get
-- UI参数设置 UI打开的时候可能需要一些数据
function WindowStack:SetParams(params)
    for i, v in ipairs(self.openingViews) do
        local param = params and params[i] or nil;
        v:SetOpenParam(param);
    end
    return self;
end
-- 得到UI集合的主UI 每个UI集合只有一个主UI
function WindowStack:GetMain()
    return self.initViews[1];
end
-- 将要加载列表
function WindowStack:SetInitView(views)
    if views and self.initViews then
        for i, v in pairs(self.initViews) do
            self:RemoveInitView(v);
        end
    end
    self.initingViews = views;
end
function WindowStack:RemoveInitView(view)
    table.RemoveValue(self.initingViews,view,true);
end
-- 已加载列表
function WindowStack:AddInitView(view)
    if table.ContainValue(self.initViews,view) == 0 then
        table.insert(self.initViews,view);
    end
    return self;
end
function WindowStack:RemoveInitView(view)
    table.RemoveValue(self.initViews,view,true);
end
-- 已显示列表
function WindowStack:AddOpenedView(view)
    if table.ContainValue(self.openedViews,view) ~= 0 then
        table.RemoveValue(self.openedViews,view,true);
    end
    table.insert(self.openedViews,view);
    return self;
end
function WindowStack:RemoveOpenedView(view)
    table.RemoveValue(self.openedViews,view,true);
end
-- 将要显示的列表
function WindowStack:AddOpeningViews(views)
    self:SetOpeningViews(views);
    return self;
end
function WindowStack:SetOpeningViews(views)
    self.openingViews = views;
end
-- 卸载设置
function WindowStack:SetDestroy(isDestory)
    self.isDestory = isDestory;
    return self;
end
function WindowStack:GetDestroy()
    return self.isDestory;
end
-- 是否需要自动返回
function WindowStack:SetManu(manu)
    self.isManuAuto = manu;
    return self;
end
function WindowStack:GetManu()
    return self.isManuAuto;
end
-- 当前UI集合是否属于显示状态
function WindowStack:IsShow()
    return self:GetMain():IsShow();
end
-- endregion