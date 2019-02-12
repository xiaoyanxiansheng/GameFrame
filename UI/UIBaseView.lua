-- 加载lua脚本时的构造
function UIBaseView:ctor(name)
    self._initOkFlag                = false;    -- 是否加载
    self._name                      = name; 
    self._isOpen                    = false;    -- 是否打开了界面（异步加载，有可能还没有显示面板,隐藏也算打开，只有销毁才算false）
    self._isShow                    = false;    -- 是否显示了界面（面板已显示）
    self._resident                  = false;    -- 常驻内存
    self._panel                     = nil;      -- 当前管理panel
    self._transform                 = nil;      -- 当前管理transform
    self._gameObject                = nil;      -- 当前管理gameObject
    self.ui_core                    = nil;      -- 当前绑定UICore
    self._csBaseView                = nil;      -- 当前baseView脚本
    self._currentDepth              = 0;        -- 界面深度值
    self._initOkDelegate            = nil;      -- 加载之后的回调
    self._asyncRequest              = nil;      -- 异步加载请求
    self._loadingGameObjectCount    = 0;        -- 自定义加载
    self._isRegisterCallback        = false;    -- 是否已经注册消息
    self._isHide                    = false;    -- 是否隐藏
    self.pre_luastepgc_mem          = 0;        -- 上次内存值
    self.pre_luastepgc_time         = 0;        -- 上次清理时间
    self.isReveal                   = false;    -- ui的打开方式分为两种 一种是主动打开 一种的被动打开
    self.params                     = nil;      -- 打开ui的参数
end
-- 加载UI
-- initOkDelegateFunc 加载之后的操作
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

function UIBaseView:InitCore()
    -- 是否正在异步加载中
    if self._asyncRequest ~= nil then
        self:HideMainColliderBox();
        return false;
    end
    self._asyncRequest = CreateUIPanelAsync(self._abName,
            function(name, instance)
                self._asyncRequest = nil;
                UIManager:RemoveAsyncPanelInit(self);
                self:OnCreateInstance(instance);
            end
    );
    -- 收集正在加载的UI 等到切换场景的时候需要取消异步加载
    UIManager:AddAsyncPanelInit(self);
    return true;
end

function UIBaseView:OnCreateInstance(instance)
    if not instance then
        LogError("[ERROR]->no ", self._abName);
        return;
    end

    self._initOkFlag = true;

    -- 这里会将prefab中引用的gameObject绑定到当前的lua脚本中
    -- 除了绑定gameObject 也会绑定各种ui事件
    UIBaseCSView.Init(instance, self, self._abName)

    -- 消息事件注册
    self:BaseRegisterCallback()

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

function UIBaseView:AddLoadingGameObjectCount()
    self._loadingGameObjectCount = self._loadingGameObjectCount + 1;
end

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

function UIBaseView:BaseRegisterCallback()
    if self._isRegisterCallback then
        return
    end
    self._isRegisterCallback = true
    self:RegisterCallback()
end
function UIBaseView:BaseOnCreate()
    self:OnCreate();
end

-- 子类重写
function UIBaseView:OnCreate()end
-- 子类重写
function UIBaseView:RegisterCallback()end