-- region readme
--[[
    作用：UI的基类 控制UI的生命周期 加载 显示 隐藏 卸载
    UI划分：可以通过表格来配置 并且后续不会改变
        UI根据层级来分
            1 固定层级UI 比如messageBox之类的弹出框
            2 动态层级UI 一些普通的界面UI
        UI根据类型划分
            1 主UI 影响UI的打开关闭流程       比如 打开一个UI前要关闭上一个UI 关闭一个UI后要打开上一个UI
            2 主UI 不影响UI的打开关闭流程
            0 子UI
    注意点：
        1 类型划分中1类型的UI只能存在一个 其他类型不限制
--]]
-- endregion
UIBaseView = class("UIBaseView");

-- region public
-- 打开UI
-- isReveal 是否属于被动打开UI
function UIBaseView:OpenWindow(isReveal)
    self.isReveal = isReveal;

    self:Init(function()
        self:Show();
    end)
end

-- 关闭UI
-- isUninit 关闭过程中是否卸载UI资源
function UIBaseView:CloseWindow(isUninit)
    if isUninit then
        self:Uninit();
    else
        self:Hide();
    end
end
-- endregion

-- region init
-- 构造
function UIBaseView:ctor(name)
    self._name                      = name;
    self._depthType                 = nil;      -- 层级类型 nil 表示动态层级
    self._showType                  = 2;        -- UI的显示类型 看头部解释
    self._initOkFlag                = false;    -- 是否加载
    self._resident                  = false;    -- 常驻内存
    self._isShow                    = false;    -- 是否显示了界面（面板已显示）
    self._isHide                    = false;    -- 是否隐藏
    self.ui_core                    = nil;      -- 当前绑定UICore
    self._csBaseView                = nil;      -- 当前baseView脚本
    self._currentDepth              = 0;        -- 界面深度值
    self._initOkDelegate            = nil;      -- 加载之后的回调
    self._isLoadUIAtlas             = false;    -- atlas 是否加载
    self._asyncRequest              = nil;      -- 异步加载请求
    self._loadingGameObjectCount    = 0;        -- 自定义加载
    self._isRegisterCallback        = false;    -- 是否已经注册消息
    self._notiList                  = nil;      -- 消息事件列表
    self.pre_luastepgc_mem          = 0;        -- 上次内存值
    self.pre_luastepgc_time         = 0;        -- 上次清理时间
    self.isReveal                   = false;    -- ui的打开方式分为两种 一种是主动打开 一种的被动打开
    self.params                     = nil;      -- 打开ui的参数

    if name and ViewPath[name] then
        self._abName = ViewPath[name][1];
        UIManager:RegisterUIScript(name, self);
    end
end
-- 加载UI
function UIBaseView:Init(initOkDelegateFunc)
    -- 是否已经加载
    if self._initOkFlag == true then
        if initOkDelegateFunc then
            initOkDelegateFunc();
        end
        return true;
    end

    -- 全屏事件屏蔽 如果加载后没有后续操作不需要屏蔽
    if initOkDelegateFunc ~= nil then
        self:ShowMainColliderBox();
    end

    if self:InitCore() then
        self._initOkDelegate = initOkDelegateFunc;
    end

    return true;
end
-- 加载UI核心
function UIBaseView:InitCore()
    -- 是否正在异步加载中
    if self._asyncRequest ~= nil then
        self:HideMainColliderBox();
        return false;
    end
    -- 异步加载
    self._asyncRequest = CreateUIPanelAsync(self._abName,
            function(name, instance)
                self._asyncRequest = nil;
                self:OnCreateInstance(instance);
            end
    );
    return true;
end
-- 加载UI成功之后的回调
function UIBaseView:OnCreateInstance(instance)
    if not instance then
        return;
    end

    self._initOkFlag = true;

    -- TODO WG 这里会将prefab中引用的gameObject绑定到当前的lua脚本中
    -- 除了绑定gameObject 也会绑定各种ui事件
    UIBaseCSView.Init(instance, self, self._abName)

    -- 消息事件注册
    self:OnRegisterCallback()

    -- 加载成功之后的操作
    self:BaseOnCreate()

    -- 有些图片在ui打开的时候加载会出现穿帮，所以需要等到需要的图片全部加载完之后再打开界面
    if self._loadingGameObjectCount ~= 0 then
        return
    end

    if not self._initOkDelegate then
        return
    end

    -- 加载图集 图集可以单独被卸载
    self:LoadUIAtlas(self._initOkDelegate);
end
-- 自定义加载 标志
function UIBaseView:AddLoadingGameObjectCount()
    self._loadingGameObjectCount = self._loadingGameObjectCount + 1;
end
-- 自定义加载完成时调用
function UIBaseView:ReduceLoadingGameObjectCount()
    if self._loadingGameObjectCount <= 0 then
        return
    end

    self._loadingGameObjectCount = self._loadingGameObjectCount - 1;
    if self._loadingGameObjectCount == 0 then
        local fun = self._initOkDelegate
        if fun then
            fun()
        end
    end
end
-- 加载完成之后 调用
function UIBaseView:BaseOnCreate()
    self:OnCreate();
end

-- 子类重写
function UIBaseView:OnCreate() end
function UIBaseView:OnRegisterCallback()
    -- 子类中调用 self:RegisterMessage() 来注册事件
end
-- endregion

-- region open
-- 显示
function UIBaseView:Show()
    self:CalcPanelDepth()
    -- 加载atlas 这里为何要加载atlas 由于atlas可以被单独卸载 但是ui被没有被卸载
    self:LoadUIAtlas(function()
        -- 设置显示状态
        self._isShow = true;
        self:SetBaseActiveCore(true);
        -- 子类重写 isReveal 代表ui的打开方式
        self:OnShow(self.isReveal);
    end);
end
-- 计算层级
function UIBaseView:CalcPanelDepth()
    local currentDepth = UIManager:GetOpeningCurrentUIDepth(self);
    -- 这里的计算规则是
    -- 取得panels panel.depth = currentDepth + panel.depth;
    -- 代码...
end
-- 子类重写
function UIBaseView:OnShow(isReveal) end
-- endregion

-- region hide
-- 隐藏
function UIBaseView:Hide(bSkipAnim)
    UIManager:RemoveOpeningUI(self);

    -- 正在加载时隐藏 需要取消异步加载
    if self._initOkFlag then
        self:CancelAsyncRequestPanel()
        return;
    end

    self._isHide = true;
    self:SetBaseActiveCore(false);

    self:OnHide();
end
-- 子类重写
function UIBaseView:OnHide()

end
-- endregion

-- region destroy
function UIBaseView:Uninit()
    -- 取消异步加载
    self:CancelAsyncRequestPanel()

    UIManager:AddOpeningUI(self);

    -- 没有加载
    if self._initOkFlag == false then
        return;
    end

    -- 防止多次卸载导致depth变化
    if self._isBaseUninit == true then
        return;
    end
    self._isBaseUninit = true;

    self._initOkFlag = false;
    self._initOkDelegate = nil;
    self.params = nil;
    self:RemoveProperties();

    self:SetBaseActiveCore(false);
    self:OnHide();
    self:UnRegisterCallback();

    -- atlas卸载
    self:UnInitUIAtlas();
    -- UI卸载
    if self:IsDestroy() then
        self:OnDestroy()
        DestroyUIPanel(self._gameObject);
    end

    -- GC
    self:UIGCCollect();
end
-- 子类重写
function UIBaseView:OnDestroy() end
-- 是否可以卸载
function UIBaseView:IsDestroy()
    -- 这里控制UI是否真的全部卸载
    return true;
end
-- endregion

-- region common
-- 显示UI
function UIBaseView:SetBaseActiveCore(flag)
    self._gameObject:SetActive(flag);
end
-- 加载 atlas
function UIBaseView:LoadUIAtlas(func)
    if (self._isLoadUIAtlas) then
        self:HideMainColliderBox();
        func(self)
        return;
    end
    self._isLoadUIAtlas = true;
    -- 图集的加载接口
    GameLua.LoadUIAtlas(self._gameObject, function()
        self:HideMainColliderBox();
        if func then
            func(self)
        end
    end );
end
-- 卸载 atlas
function UIBaseView:UnInitUIAtlas()
    if not self._isLoadUIAtlasthen then
        return;
    end

    -- 卸载atlas
    GameLua.ReleaseUIAtlas(self._gameObject);

    self._isLoadUIAtlas = false;
end
-- 消息事件移除 UI生命周期中没有必要单独移除某个事件
function UIBaseView:UnRegisterCallback()
    if not self._notiList then
        return;
    end

    for k, v in pairs(self._notiList) do
        -- TODO WG
        RemoveMessageHandler(k, self, v.func);
    end
    self._notiList = nil;
end
-- 消息事件注册 子类调用
function UIBaseView:RegisterMessage(msgName, func)
    if not self._notiList then
        self._notiList = {}
    end
    if not self._notiList[msgName] then
        self._notiList[msgName] = {}
    end

    self._notiList[msgName].func = func;
    -- TODO WG
    SetMessageHandler(msgName, func , self);
end
-- 是否正在异步加载
function UIBaseView:IsAsyncRequestLoading()
    if self._asyncRequest then
        return true
    else
        return false
    end
end
-- 取消异步加载
function UIBaseView:CancelAsyncRequestPanel()
    if self._asyncRequest ~= nil and self._asyncRequest ~= 0 then
        -- 取消异步加载
        CancelInstanceCreateRequest(self._asyncRequest, self._abName);
        UIManager:RemoveAsyncPanelInit(self);
        self._asyncRequest = nil;
    end
end
-- 属性清理 这里的属性主要是通过uiCore绑定到lua中的
function UIBaseView:RemoveProperties()
    if self._properties then
        for i,v in pairs(self._properties) do
            self[v] = nil;
        end
    end
    self._properties = nil;
end
-- 加入属性
function UIBaseView:insertPropertyList(pro_name)
    if not self._properties then
        self._properties = {};
    end
    table.insert(self._properties, pro_name);
end
-- GC
function UIBaseView:UIGCCollect()
    local now = GetTime();
    if UIManager.pre_luastepgc_time == 0 or now - UIManager.pre_luastepgc_time > 1000 then
        UIManager.pre_luastepgc_time = now;
        local memadd = 0;
        ---@type number
        local curmem = CalcLuaUsedMemory();
        if UIManager.pre_luastepgc_mem > 0 then
            memadd = curmem - UIManager.pre_luastepgc_mem;
        else
            UIManager.pre_luastepgc_mem = curmem;
        end
        if memadd > 0 then
            -- step size越大耗时越大，这里限制一下step上限
            if memadd > 1000000 then
                memadd = 1000000;
            end
            if memadd > 0 then
                LogInfo("start to UI GC, memadd: ", memadd);
                GCCollect(false, false, true, memadd);
                UIManager.pre_luastepgc_mem = CalcLuaUsedMemory();
            end
        end
    end
end

-- UI在加载过程中全屏事件屏蔽
-- 1 屏蔽UI事件
-- 2 加载过程中是否显示黑屏
function UIBaseView:ShowMainColliderBox()
    -- 代码...
end
function UIBaseView:HideMainColliderBox()
    -- 代码...
end
-- 具体看头部显示类型解释
function UIBaseView:IsFullUI()
    return self._showType == 1;
end
function UIBaseView:IsFullUIIgnoreFlow()
    return self._showType == 2;
end
function UIBaseView:IsSonUI()
    return self._showType == 0;
end
-- endregion