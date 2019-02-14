UIManager = {
    _ui_view_scripts    = {};   -- 已经加载的lua脚本
    _init_window_stack  = {};   -- 已经加载的UI集合
    _open_window_stack  = {};   -- 记录打开过的UI集合路径，用于返回
    _opening_ui_list    = {};   -- 记录已经打开的ui列表，用来动态计算层级
};

-- region delete
USE_NEW_UI = true;
DEBUG_UI_LOG_FLAG = true;
DEBUG_MODEL_LOG_FLAG = false;
DEBUG_TUT_LOG_FLAG = true;

---@type UIManager
UIManager = {
    asynui_ = {};
    is_uninit_all = false;
--全部UI界面脚本
    _ui_view_scripts = {};
    _init_window_stack = {};--加载的ui
    _open_window_stack = {};--记录打开界面路径 用于智能返回{index,WindowStack}
    _opening_ui_list   = {};--记录已经打开的ui列表，用来动态计算层级

-- 通用背板
    common_bkg_res = "scene/pref/factory/bigbkg.bytes";
    common_bkg_requestId = nil;
    common_bkg_instanceId = nil;
    pre_luastepgc_time = 0;
    pre_luastepgc_mem = 0;
};

-- region init
-- 创建一个新的stack
function UIManager:InitWindow(params,callback,...)
    local views = self:GetViewsByNames({...});
    local windowStack = nil;

    local isAllSonView = self:IsAllSonView(views);
    if not isAllSonView then
        windowStack = self:GetWindowStack(views[1]);
    else
        windowStack = self:GetCurFullScreenWindowStack();
        if not windowStack then
            if views then
                DEBUG_UI_LOG("[error UI_FLOW WindowStack:OpenWindowNew] detail: not mainup and openui not mainui " , views[1]._abName);
            end
            return;
        end
    end

    windowStack = windowStack or WindowStack.New();
    self:InitWindowStack(params,callback,windowStack,views);
end
-- 在现有windowstack中加入
function UIManager:InitWindowStack(params,callback,windowStack,views)
    self:AddInitWindowStack(windowStack);
    windowStack:InitViews(params,views,function()
        if callback then
            callback(windowStack,views)
        end
    end);
end
-- endregion

-- region open
function UIManager:OpenWindow(name,bSkipAnim,params)
    self:OpenWindowAim(params,false,bSkipAnim,name);
end
function UIManager:OpenWindowByNames(params,...)
    UIManager:OpenWindowAim(params,false,false,...);
end
function UIManager:OpenWindowAim(params,isSkipCloseAim,isSkipOpenAim,...)
    self:InitWindow(params,function(stack,views)
        stack:SetSkipOpenAim(isSkipOpenAim);
        local curWindowStack = self:GetCurFullScreenWindowStack();
        if stack == curWindowStack or (curWindowStack and not curWindowStack:IsShow()) then
            self:OpenWindowStack(stack);
        else
            if self:CheckUIPanelIgnoerFullScreen(stack:GetMain()) then
                self:OpenWindowStack(stack);
            else
                if curWindowStack then
                    curWindowStack:SetSkipCloseAim(isSkipCloseAim);
                    curWindowStack:SetManu(true);
                    curWindowStack:SetDestroy(false);
                    self:CloseWindowStack(curWindowStack,function()
                        self:OpenWindowStack(stack);
                    end);
                else
                    self:OpenWindowStack(stack);
                end
            end
        end
    end,...);
end

function UIManager:OpenWindowStack(windowStack,isReveal)
    -- 处理来源
    self:HandleSourceView(windowStack);
    self:AddOpenWindowStack(windowStack);
    DEBUG_UI_LOG("[UI_FLOW UIManager:OpenWindowStack] name " , windowStack:GetMain():GetName());
    windowStack:OpenStack(isReveal);
end
-- endregion

-- region close
function UIManager:CloseWindow(name,bSkipAnim,isNotDestroy)
    local isDestroy = not isNotDestroy;
    if USE_NEW_UI then
        self:CloseWindowAim(name,bSkipAnim,false,isDestroy);
        return;
    end
end
function UIManager:CloseWindowAim(windowName,isSkipCloseAim,isSkipOpenAim,isDestroy)
    local view = self:GetView(windowName);
    if not view then
        return;
    end
    local windowStack = self:GetWindowStack(view);
    if not windowStack then
        return;
    end
    windowStack:SetSkipCloseAim(isSkipCloseAim):SetSkipOpenAim(isSkipOpenAim):SetDestroy(isDestroy);
    if self:IsSonView(view) then
        if isDestroy then
            windowStack:CloseView(view);
        else
            local lastShowWindowStack = self:GetLastShowWindowStack(view);
            if lastShowWindowStack then
                lastShowWindowStack:CloseView(view);
            end
        end
    else
        if windowStack then
            self:RemoveOpenWindowStack(windowStack);
            if isDestroy then
                self:RemoveInitWindowStack(windowStack);
            end
            if self:CheckUIPanelIgnoerFullScreen(windowStack:GetMain()) then
                self:CloseWindowStack(windowStack);
            else
                self:CloseWindowStack(windowStack,function()
                    local tempWinStack = self:GetCurFullScreenWindowStack();
                    if tempWinStack then
                        self:OpenWindowStack(tempWinStack,true);
                    end
                end);
            end
        end
    end
end

function UIManager:CloseWindowStack(windowStack,closeFinishFunc)
    if windowStack then
        windowStack:CloseView(windowStack:GetMain(),closeFinishFunc);
    else
        DEBUG_UI_LOG("[UI_FLOW UIManager:CloseWindowStack] error!!! detail windowStack is nil");
    end
end

function UIManager:UninitAll(includeResident)

    self.is_uninit_all = true;
    local temp = {nil,nil}
    for k,v in pairs(self._init_window_stack) do
        table.insert(temp,v)
    end
    if not includeResident then
        for k,v in pairs(temp) do
            if not v:GetMain():IsResident() then
                self:CloseWindow(v:GetMain():GetName());
            end
        end
    else
        if #self._init_window_stack > 0 then
            self:CloseWindow(self._init_window_stack[1]:GetMain():GetName());
        end
    end
    UIManager.is_uninit_all = false;
    -- 取消所有正在加载ui
    self:CancelAsyncPanelInitAll();

    -- 卸载大背板
    self:HideCommonBkg();

    -- 清理角标
    CornerIconUtil:ClearCornerPool();
end
function UIManager:CloseAll(isNotDestroy)
    local temp = {nil,nil}
    for k,v in pairs(self._init_window_stack) do
        table.insert(temp,v)
    end
    for k,v in pairs(temp) do
        self:CloseWindow(v:GetMain():GetName(),false,isNotDestroy);
    end
end
-- 关闭所有弹窗(2)
function UIManager:CloseAllBox()
    local count = #self._open_window_stack;
    for i = 1, count do
        local index = count - i + 1;
        local stack = self._open_window_stack[index];
        if stack and self:CheckUIPanelIgnoerFullScreen(stack:GetMain()) then
            stack:SetSkipCloseAim(true);
            stack:SetDestroy(not stack:GetMain():IsResident());
            self:CloseWindowStack(stack);
            self:RemoveOpenWindowStack(stack);
            self:RemoveInitWindowStack(stack);
        end
    end
end
function UIManager:AddAsyncPanelInit(panel)
    if not panel then
        LogError("UIManager:AsyncPanel AddAsyncPanelInit panel is nil");
        return;
    end
    -- LogInfo("UIManager:AsyncPanel AddAsyncPanelInit " .. panel._abName);
    self.asynui_[panel._abName] = panel;
end
function UIManager:RemoveAsyncPanelInit(panel)
    if not panel then
        LogError("UIManager:AsyncPanel RemoveAsyncPanelInit panel is nil");
        return;
    end
    -- LogInfo("UIManager:AsyncPanel RemoveAsyncPanelInit " .. panel._abName);
    self.asynui_[panel._abName] = nil;
end
function UIManager:CancelAsyncPanelInitAll()
    local uiList = shallow_copy(self.asynui_)
    for k,v in pairs(uiList) do
        self:RemoveAsyncPanelInit(v)
    end
    self.asynui_ = {};
end
-- 返回大厅
function UIManager:BackMainHall()
    --for index,stack in pairs(self._open_window_stack) do
    --    if not self:BackMainHallIgnoreStack(stack) then
    --        stack:SetSkipCloseAim(true);
    --        stack:SetDestroy(not stack:GetMain():IsResident());
    --        self:CloseWindowStack(stack);
    --    end
    --end
    local count = #self._open_window_stack;
    for i = 1, count do
        local index = count - i + 1;
        local stack = self._open_window_stack[index];
        if stack and not self:BackMainHallIgnoreStack(stack) then
            stack:SetSkipCloseAim(true);
            stack:SetDestroy(not stack:GetMain():IsResident());
            self:CloseWindowStack(stack);
            self:RemoveOpenWindowStack(stack);
            self:RemoveInitWindowStack(stack);
        end
    end
    self:OpenWindow(ViewConst.UIPanel_Mainmap);
end
-- 返回天书主界面
function UIManager:BackBookMainHall()
    --for index,stack in pairs(self._open_window_stack) do
    --    if not self:BackMainHallIgnoreStack(stack) then
    --        stack:SetSkipCloseAim(true);
    --        self:CloseWindowStack(stack);
    --    end
    --end
    local count = #self._open_window_stack;
    for i = 1, count do
        local index = count - i + 1;
        local stack = self._open_window_stack[index];
        if stack and not self:BackMainHallIgnoreStack(stack) then
            stack:SetSkipCloseAim(true);
            stack:SetDestroy(not stack:GetMain():IsResident());
            self:CloseWindowStack(stack);
            self:RemoveOpenWindowStack(stack);
            self:RemoveInitWindowStack(stack);
        end
    end
    self:OpenWindow(ViewConst.UIPanel_HeavenBook_Mainmap);
end
function UIManager:BackMainHallIgnoreStack(windowStack)
    if windowStack:IsMainHallView() then
        return true;
    end
    return false;
end
-- endregion

--region  Add Load UI for loading
function UIManager:AddLoadUI(name,params,ignoreShow)
    local view = self:GetView(name,true)
    if not view then
        return
    end
    if not self._uiPanelToLoad then
        self._uiPanelToLoad = {nil,nil};
    end
    for _, v in ipairs(self._uiPanelToLoad) do
        if v.stack:GetMain():GetName() == name then
            return v.stack;
        end
    end

    local stack = WindowStack.New()
    stack:AddOpeningViews({view}):SetParams(params)
    table.insert(self._uiPanelToLoad, {stack = stack,ignoreShow = ignoreShow});
    return stack;
end
function UIManager:initLoadUI(callback)
    if not self._uiPanelToLoad then
        return
    end
    for k,v in pairs(self._uiPanelToLoad) do
        self:InitWindowStack(nil,callback,v.stack,v.stack:GetOpeningViews());
    end
end
function UIManager:ClearLoadUI()
    if self._uiPanelToLoad then
        table.clear(self._uiPanelToLoad)
    end
end
function UIManager:GetLoadUICount()
    if not self._uiPanelToLoad then
        return 0
    end
    return #self._uiPanelToLoad
end
function UIManager:ShowLoadUI()
    if not self._uiPanelToLoad then
        return
    end
    for k,v in pairs(self._uiPanelToLoad) do
        self:InitWindowStack(nil,function()
            if not v.ignoreShow then
                self:OpenWindowStack(v.stack);
            end
        end,v.stack,v.stack:GetOpeningViews());
    end
    self:ClearLoadUI();
end
--endregion

-- region helper function
-- 这里需要在列表中寻找当前往上的全屏ui
function UIManager:GetCurFullScreenWindowStack()
    local winStack = nil;
    if self._open_window_stack then
        local winStackCount = #self._open_window_stack;
        for i = 1, winStackCount do
            local index = winStackCount - i + 1;
            local tempWinStack = self._open_window_stack[index];
            if self:CheckUIPanelIsFullScreen(tempWinStack:GetMain()) then
                winStack = tempWinStack;
                break;
            end
        end
    end
    return winStack;
end
-- 得到最后一个显示界面
function UIManager:RemoveOpenWindowStack(windowStack)
    local index = 0;
    if self._open_window_stack then
        for i, v in pairs(self._open_window_stack) do
            if v:GetMain() == windowStack:GetMain() then
                index = i;
                break;
            end
        end
    end
    if index ~= 0 then
        table.remove(self._open_window_stack,index);
    end
end
function UIManager:AddOpenWindowStack(windowStack)
    self:RemoveOpenWindowStack(windowStack);
    table.insert(self._open_window_stack,windowStack);
end
function UIManager:RemoveInitWindowStack(windowStack)
    table.RemoveValue(self._init_window_stack,windowStack,true);
end
function UIManager:AddInitWindowStack(windowStack)
    self:RemoveInitWindowStack(windowStack);
    table.insert(self._init_window_stack,windowStack);
end
function UIManager:GetWindowStack(view)
    for i, stack in pairs(self._init_window_stack) do
        local views = stack:GetInitView();
        if views then
            for k, v in pairs(views) do
                if v == view then
                    return stack;
                end
            end
        end
    end
    return nil;
end
function UIManager:GetWindowStackByName(viewName)
    for i, stack in pairs(self._init_window_stack) do
        local views = stack:GetInitView();
        if views then
            for k, v in pairs(views) do
                if v:GetName() == viewName then
                    return stack;
                end
            end
        end
    end
    return nil;
end
-- 同一个view可能出现在多个stack中
function UIManager:GetLastShowWindowStack(view)
    local stack = nil;
    local stackCount = #self._open_window_stack;
    for i = 1, stackCount do
        local stack = self._open_window_stack[stackCount-i+1];
        local views = stack:GetInitView();
        if views then
            for k, v in pairs(views) do
                if v == view then
                    return stack;
                end
            end
        end
    end
    return stack;
end
function UIManager:IsAllSonView(views)
    local isAllSonView = true;
    for i, v in ipairs(views) do
        if not self:IsSonView(v) then
            isAllSonView = false;
            break;
        end
    end
    return isAllSonView;
end
function UIManager:IsSonView(view)
    return not self:CheckUIPanelIsFullScreen(view) and not self:CheckUIPanelIgnoerFullScreen(view);
end
function UIManager:GetViewsByNames(windowNames)
    local views = nil;
    if windowNames then
        for i, v in ipairs(windowNames) do
            if not views then
                views = {};
            end
            table.insert(views,self:GetView(v,true));
        end
    end
    return views;
end
-- 特殊处理来源 如果 来源已经在之前显示了 后面再次显示的时候 要从上次的列表中删除
function UIManager:HandleSourceView(windowStack)
    if not windowStack then
        return;
    end
    if not self._open_window_stack then
        return;
    end
    local isRemove = false;
    for i, v in pairs(windowStack:GetOpeningViews()) do
        if v._name == ViewConst.UIPanel_Source then
            isRemove = true;
            break;
        end
    end
    if isRemove then
        for k, v in pairs(self._open_window_stack) do
            if v ~= windowStack then
                local openingViews = v:GetOpeningViews();
                local openingInIndex = table.ContainValue(openingViews,ViewConst.UIPanel_Source,"_name");
                if openingInIndex ~= 0 then
                    table.remove(openingViews,openingInIndex);
                    local initingViews = v:GetInitView();
                    local initingInIndex = table.ContainValue(initingViews,ViewConst.UIPanel_Source,"_name");
                    if initingInIndex ~= 0 then
                        table.remove(initingViews,initingInIndex);
                    end
                    break;
                end
            end
        end
    end
end
-- 子ui可以转移 不过需要瘦身
function UIManager:TrimWinsowStack(windowStack,views)
    if windowStack and views then
        for i, tempWindowStack in ipairs(self._open_window_stack) do
            if tempWindowStack ~= windowStack then
                for j, view in ipairs(views) do
                    tempWindowStack:RemoveInitView(view);
                    tempWindowStack:RemoveOpenedView(view);
                end
            end
        end
    end
end

function UIManager:GetResidentRefBundle()
    local remain_list = {};
    for i,v in pairs(self._ui_view_scripts) do
        if v:IsResident() then
            table.insert(remain_list, v._abName);
            if v:GetGameObject() then
                local refBundles = GameLua.GetUIRefBundles(v:GetGameObject());
                if refBundles then
                    for i = 0, refBundles.Length - 1 do
                        table.insert(remain_list, refBundles[i]);
                    end
                end
            end
        end
    end
    return remain_list
end
-- 注册所有的ui脚本
function UIManager:RegisterUIScript(name,uiScript)
    ---@type string
    name = StringManager.GetString(name)
    if self._ui_view_scripts[name] then
        --LogError("[repeat register ui view:]",name)
    else
        self._ui_view_scripts[name] = uiScript
    end

end

--获得界面lua view
--bLoadFile:未加载是否加载
---@return UIBaseView
function UIManager:GetView(name,bLoadFile)
    local view = self._ui_view_scripts[name]
    if view then
        return view
    else
        --if bLoadFile then
        view = ViewConst[name]
        if view and ViewPath[view] then
            require(ViewPath[view][2])
            return self._ui_view_scripts[name]
        end
        -- end
    end
    return nil
end
--ui相关配置 传入view
function UIManager:GetUIPanelSetting(uipanel)
    if(uipanel == nil) then
        return nil;
    end
    local uipanelSetting = GetUIPanelSettingTable();
    local inputname = string.lower(ExtendCSharp.FromABNameToRaw(uipanel:GetABName()));

    return uipanelSetting[inputname];
end
-- 是否全屏ui
function UIManager:CheckUIPanelIsFullScreen(uipanel)
    local setting = self:GetUIPanelSetting(uipanel);
    if setting and setting.is_fullscreen == 1 then
        return true;
    end
    return false;
end
-- 是否全屏但是忽略流程
function UIManager:CheckUIPanelIgnoerFullScreen(uipanel)
    local setting = self:GetUIPanelSetting(uipanel);
    if setting and setting.is_fullscreen == 2 then
        return true;
    end
    return false;
end
function UIManager:IsUIPanelAnimEffect(uipanel)
    if(uipanel == nil) then
        return 0;
    end
    local uipanelSetting = GetUIPanelSettingTable();
    local inputname = string.lower(ExtendCSharp.FromABNameToRaw(uipanel._abName));
    if(uipanelSetting[inputname] ~= nil) then
        return uipanelSetting[inputname].anim_effect == 1;
    end
    return false;
end
-- 某个ui是否是显示状态
function UIManager:IsShow(viewName)
    local view = self:GetView(viewName);
    if view then
        return view:IsShow();
    end
    return false;
end
-- region levelback
-- 用于返回 这里需要保存列表数据(这里只保存数据)
UIManager.sourceLevelBackWindowStackListData = nil;
function UIManager:SaveLevelBackWindowStackListData(isSaveToSource)
    if LevelManager.enterGameSceneType ~= EnterGameSceneType.Lobby
            and LevelManager.enterGameSceneType ~= EnterGameSceneType.Building then
        return;
    end
    local toViewName = "";
    if isSaveToSource then
        toViewName = ViewConst.UIPanel_Source;
    else
        local topWindowStack = self._open_window_stack[#self._open_window_stack];
        toViewName = topWindowStack:GetMain():GetName();
    end
    self.sourceLevelBackWindowStackListData = nil;
    if self._open_window_stack then
        local inIndex = 0;
        for i, vi in ipairs(self._open_window_stack) do
            local isBreak = false;
            for j, vj in ipairs(vi.initViews) do
                if vj._name == toViewName then
                    isBreak = true;
                    break;
                end
            end
            if isBreak then
                inIndex = i;
                break;
            end
        end
        if inIndex > 0 then
            for i = 1, inIndex do
                local v = self._open_window_stack[i];
                -- 去除UI实例部分 保存数据部分
                local windowStackData = {};
                windowStackData.initViews,windowStackData.initParams        = self:GetWindowStackViewData(v.initViews);
                windowStackData.openedViews,windowStackData.opendedParams   = self:GetWindowStackViewData(v.openedViews);
                windowStackData.openingViews,windowStackData.openingParams  = self:GetWindowStackViewData(v.openingViews);
                windowStackData.isSkipCloseAim  = v.isSkipCloseAim;
                windowStackData.isSkipOpenAim   = v.isSkipOpenAim;
                if not self.sourceLevelBackWindowStackListData then
                    self.sourceLevelBackWindowStackListData = {};
                end
                table.insert(self.sourceLevelBackWindowStackListData,windowStackData);
            end
        end
    end
end
function UIManager:ChangeLevelBackWindowStackListDataParam(viewName,param)
    for k,v in pairs(self.sourceLevelBackWindowStackListData) do
        for index,name in pairs(v.initViews) do
            if name == viewName then
                v.initParams[index] = param
                break
            end
        end
        for index,name in pairs(v.openedViews) do
            if name == viewName then
                v.opendedParams[index] = param
                break
            end
        end
        for index,name in pairs(v.openingViews) do
            if name == viewName then
                v.openingParams[index] = param
                break
            end
        end
    end
end

function UIManager:InitLevelBackWindowStackList()
    local levelBacks = self.sourceLevelBackWindowStackListData;
    if levelBacks then
        for i, data in ipairs(levelBacks) do
            local initViews = data.initViews;
            local params = data.initParams;
            local stack = self:AddLoadUI(initViews and initViews[1] or nil,params and params[1] or nil,true);
            if stack then
                local views = {};
                stack:AddOpeningViews(views);
                for j, viewName in ipairs(initViews) do
                    local view = self:GetView(viewName);
                    if view then
                        stack:AddInitView(view);
                        view:SetOpenParam(params and params[j]);
                        table.insert(views,view);
                    end
                end
            end
        end
    end
end
UIManager.FilterBackViewList = {ViewConst.UIPanel_WaitRoom,
                                ViewConst.UIPanel_MessageBox,
                                ViewConst.UIPanel_CommonSelectPetReal,
                                ViewConst.UIPanel_ChapterRealDetail};
--进入下一关要显示UIPanel_ChapterRealDetail，不屏蔽
UIManager.notFilterBackViewList = {}
function UIManager:SetNotFilterBackViewList(viewName)
    UIManager.notFilterBackViewList[viewName] = true
end
function UIManager:ClearNotFilterBackViewList()
    table.clear(UIManager.notFilterBackViewList)
end
function UIManager:ShowLevelBackWindowStackList()
    local levelBacks = self.sourceLevelBackWindowStackListData;
    self.sourceLevelBackWindowStackListData = nil;
    if not levelBacks then
        return;
    end
    local topLevelBack = nil;
    -- 1 将ui加入返回流程 并不是所有ui都能加入返回流程
    for i, v in ipairs(levelBacks) do
        local initViews = v.initViews;
        local openedViews = v.openedViews;
        local openingViews = v.openingViews;
        if initViews then
            for j, vj in ipairs(initViews) do
                -- 屏蔽UI
                local inIndex = table.ContainValue(self.FilterBackViewList,vj);
                local inIndex2 = self.notFilterBackViewList[vj]
                if inIndex ~= 0 and not inIndex2 then
                    if openedViews then
                        local inIndex = table.ContainValue(openedViews,vj);
                        if  inIndex ~= 0 then
                            table.remove(openedViews,inIndex);
                        end
                    end
                    if openingViews then
                        local inIndex = table.ContainValue(openingViews,vj);
                        if inIndex ~= 0 then
                            table.remove(openingViews,inIndex);
                        end
                    end
                end
            end
            if (openedViews and openedViews[1]) or (openingViews and openingViews[1]) then
                local windowStack = self:GetWindowStackByName(initViews[1]);
                if windowStack then
                    self:AddOpenWindowStack(windowStack);
                    topLevelBack = v;
                end
            end
        end
    end
    -- 2 显示最上层ui
    -- 分两种情况 1 当前界面是打开状态 2 当前界面不是打开状态
    local openedViews = topLevelBack.openedViews;
    local opendedParams = topLevelBack.opendedParams;
    local views = (openedViews and #openedViews > 0) and openedViews or topLevelBack.openingViews;
    local params = (openedViews and #openedViews > 0) and opendedParams or topLevelBack.openingParams;
    if views then
        for i, v in ipairs(views) do
            local param = params and params[i] or nil;
            UIManager:OpenWindow(v,false,param);
        end
    end
end
function UIManager:GetWindowStackViewData(views)
    local datas = nil;
    local params = nil;
    if views then
        datas = {};
        params = {};
        for i, v in ipairs(views) do
            datas[i] = v:GetName();
            params[i] = v:GetParams();
        end
    end
    return datas , params;
end
function UIManager:GetLevelBackWindowStackListData()
    local sources = self.sourceLevelBackWindowStackListData;
    return sources;
end
function UIManager:CheckLevelBackWindowStackList()
    return self.sourceLevelBackWindowStackListData ~= nil;
end
function UIManager:ClearLevelBackWindowStackList()
    self.sourceLevelBackWindowStackListData = nil;
end
-- endregion
-- endregion

-- region 通用背板的处理
function UIManager:InitCommonBkg(rotation,call)
    if self.common_bkg_instanceId then
        local go = GetGameObjectByID(self.common_bkg_instanceId);
        if go then
            return;
        end
        self.common_bkg_instanceId = nil;
    end

    -- 是否在加载中
    self:CancelRequstCommonBkg();

    -- 开始加载
    self.common_bkg_requestId = CreateInstanceAsync(nil,self.common_bkg_res,false,function(res,instance)
        self.common_bkg_requestId = nil;
        if instance then
            instance.gameObject:SetActive(false);
            instance.transform.localPosition = Vector3.New(1000,0,0);
            self.common_bkg_instanceId = instance:GetInstanceID();
            self:RepositionCommonBkgCamera(rotation);
            if call then
                call();
            end
        end
    end);
end
function UIManager:ShowCommonBkg(rotation)
    -- 如果存在直接显示
    if self.common_bkg_instanceId == nil then
        self:InitCommonBkg(rotation,function()
            self:ShowCommonBkg(rotation);
        end);
    else
        local go = GetGameObjectByID(self.common_bkg_instanceId);
        if go then
            self:RepositionCommonBkgCamera(rotation);
            go:SetActive(true);
            if self.addPlayerRootTrans then
                self:AddInPlayerRoot(self.addPlayerRootTrans);
                self.addPlayerRootTrans = nil;
            end
        end
    end
end
function UIManager:AddInPlayerRoot(trans)
    local uiFocusCamera = nil;

    self.addPlayerRootTrans = trans;
    if self.common_bkg_instanceId == nil then
        return;
    end
    self.addPlayerRootTrans = nil;
    local go = GetGameObjectByID(self.common_bkg_instanceId);
    if go then
        local playerRoot = go.transform:FindChild("player_root");
        if playerRoot then
            trans.parent = playerRoot.transform;
            trans.localPosition = Vector3.New(0,0,0);
        end
    end

    local mainLight = go.transform:FindChild("main_light");
    local camera = go.transform:FindChild("bigbkg_Camera");
    self:ChangeCameraTag(camera);
    if mainLight and camera then
        uiFocusCamera = UIFocusCamera.New();
        uiFocusCamera:BindTransform(camera,trans,mainLight);
    end

    return uiFocusCamera;
end
function UIManager:HideCommonBkg(isDestroy)
    self.addPlayerRootTrans = nil;
    self:CancelRequstCommonBkg();

    if self.common_bkg_instanceId == nil then
        return;
    end

    local go = GetGameObjectByID(self.common_bkg_instanceId);
    if go then
        if isDestroy then
            DestroyInstance(self.common_bkg_instanceId);
            self.common_bkg_instanceId = nil;
        else
            go:SetActive(false);
        end
    end
end
function UIManager:CancelRequstCommonBkg()
    self.addPlayerRootTrans = nil;
    if self.common_bkg_requestId == nil then
        return;
    end
    CancelInstanceCreateRequest(self.common_bkg_requestId,self.common_bkg_res);
end
function UIManager:GetCommonBkgGo()
    if not self.common_bkg_instanceId then
        return nil
    end
    return GetGameObjectByID(self.common_bkg_instanceId);
end
function UIManager:RepositionCommonBkgCamera(rotation)
    if not rotation then
        local go = self:GetCommonBkgGo()
        local tongyong =  go.transform:Find("tongyong")
        if tongyong then
            local camera = go.transform:FindChild("bigbkg_Camera");
            if camera then
                self:ChangeCameraTag(camera);
                camera.localPosition = tongyong.localPosition;
                camera.localRotation = tongyong.localRotation
            else
                LogError("UIManager:RepositionCommonBkgCamera bigbkg_Camera is nil");
            end
        end
        --LogError("UIManager:RepositionCommonBkgCamera pos is nil");
        return;
    end
    if self.common_bkg_instanceId == nil then
        return;
    end
    local go = GetGameObjectByID(self.common_bkg_instanceId);
    if go then
        local camera = go.transform:FindChild("bigbkg_Camera");
        if camera then
            self:ChangeCameraTag(camera);
            camera.localRotation = Quaternion.Euler(rotation.x,rotation.y,rotation.z);
        else
            LogError("UIManager:RepositionCommonBkgCamera bigbkg_Camera is nil");
        end
    else
        LogError("UIManager:RepositionCommonBkgCamera GetGameObjectByID is nil");
    end
end
function UIManager:GetCommonBkgCamera()
    local camera = nil;

    if self.common_bkg_instanceId then
        local go = GetGameObjectByID(self.common_bkg_instanceId);
        if go then
            camera = go.transform:FindChild("bigbkg_Camera");
            self:ChangeCameraTag(camera);
        else
            LogError("UIManager:RepositionCommonBkgCamera GetGameObjectByID is nil");
        end
    end

    return camera;
end
-- 通用背景灯光控制
function UIManager:CommonBkgMainLightActive(flag)
    if self.common_bkg_instanceId then
        local go = GetGameObjectByID(self.common_bkg_instanceId);
        if go then
            local mainLight = go.transform:FindChild("main_light");
            if mainLight then
                mainLight.gameObject:SetActive(flag)
            end
        else
            LogError("UIManager:MainLightActive GetGameObjectByID is nil");
        end
    end
end

--
function UIManager:ChangeCameraTag(cameraTrans)
    if not cameraTrans then
        return;
    end
    GetComponent(cameraTrans,"Camera").enabled = true;
end
-- endregion
-- endregion

-- region depth 相关
-- 加入到打开列表中
function UIManager.AddOpeningUI(view)
    if(view == nil) then
        return ;
    end

    if(view._isTop == true
            or view._isTop2 == true
            or view._isTop3 == true
            or view._isBottom == true
            or view._isBottom2 == true) then
        return;
    end

    -- 如果已经存在则删除
    self:RemoveOpeningUI(view);

    -- 加入
    local maxIndex = self:GetOpeningUIDepthMaxIndex();
    self._opening_ui_list[maxIndex + 1] = view;
end
-- 从列表中删除
function UIManager.RemoveOpeningUI(view)
    if(view == nil) then
        return ;
    end

    local inIndex = table.ContainValue(self._opening_ui_list,view);
    if inIndex ~= 0 then
        table.remove(self._opening_ui_list,inIndex);
    end
end
-- 获取UI的初始深度值
function UIManager.GetOpeningCurrentUIDepth(view)
    if(view == nil) then
        return 0;
    end
    if(view._isTop3 == true) then
        return 2500;
    end
    if(view._isTop2 == true) then
        return 3000;
    end
    if(view._isTop1 == true) then
        return 3500;
    end
    if(view._IsBottom == true) then
        return -2500;
    end
    if(view._IsBottom2 == true) then
        return -3000;
    end

    return self:GetOpeningUIDepthMaxIndex() * 100;
end
-- 获取UI的索引
function UIManager:GetOpeningUIDepthMaxIndex()
    local maxIndex = 0;

    for i, v in pairs(self._opening_ui_list) do
        if i > maxIndex then
            maxIndex = i;
        end
    end

    return maxIndex;
end
-- endregion