-- region readme
--[[
    UI集合打开顺序为 先关闭 后 打开
    卸载UI时只在卸载UI集合时生效 比如单独是没有办法卸载一个子UI的 也没有必要

    eg
        UIManager:InitWindow(nil,nil,ViewConst.UIPanel_MessageBox1,ViewConst.UIPanel_MessageBox2);
        UIManager:OpenWindow(nil,ViewConst.UIPanel_MessageBox1,ViewConst.UIPanel_MessageBox2);
        UIManager:CloseWindow(ViewConst.UIPanel_MessageBox1);
-- ]]
-- endregion
UIManager = {
    _ui_view_scripts    = {};   -- 已经加载的lua脚本
    _init_window_stack  = {};   -- 已经加载的UI集合
    _open_window_stack  = {};   -- 记录打开过的UI集合路径，用于返回
    _opening_ui_list    = {};   -- 记录已经打开的ui列表，用来动态计算层级
};

-- region public
-- 加载UI列表
function UIManager:InitWindow(params,callback,...)
    local windowStack = nil;

    local views = self:GetViews({...});

    -- UI列表中是否存在主UI
    if not self:IsAllSonView(views) then
        windowStack = self:GetWindowStack(views[1]) or WindowStack.New();
    else
        if #self._open_window_stack > 0 then
            windowStack = self._open_window_stack[#self._open_window_stack];
        else
            -- error: 当前全部是子UI并且当前没有主UI在打开状态
            return;
        end
    end

    windowStack:SetInitView(views):SetParams(params);
    self:InitWindowStack(callback,windowStack);
end
-- 打开UI
function UIManager:OpenWindow(params,...)
    local views = {...};

    -- 加载完成之后的回调
    local initCall = function(stack,views)
        -- 当前UI集合打开状态
        local curWindowStack = self._open_window_stack[#self._open_window_stack];
        if stack == curWindowStack then
            self:OpenWindowStack(stack);
        else
            -- 当前UI集合不进入UI流程
            if stack:GetMain():IsFullUIIgnoreFlow() then
                self:OpenWindowStack(stack);
            else
                -- 当前存在已经打开的UI集合 需要先关闭当前UI集合 然后打开新的UI集合
                if curWindowStack then
                    curWindowStack:SetManu(true)  -- 将当前UI集合设置成被动关闭 后续也会被动打开
                                  :SetDestroy(false);   -- 由于后续还会打开 所以这里强行不卸载UI集合
                    self:CloseWindowStack(curWindowStack,function()
                        self:OpenWindowStack(stack);
                    end);
                else
                    self:OpenWindowStack(stack);
                end
            end
        end
    end;

    -- 加载UI列表
    self:InitWindow(params,function(stack,views)
        initCall(stack,views)
    end,...);
end
-- 关闭UI
function UIManager:CloseWindow(viewName,isDestroy)
    local view = self:GetView(viewName);
    if not view then
        return;
    end

    -- error 当前关闭的界面没有依赖于UI集合
    local windowStack = self:GetWindowStack(view);
    if not windowStack then
        return;
    end

    -- 如果关闭的是子UI
    if self:IsSonView(view) then
        windowStack:CloseView(view);
    else
        -- 是否是显示类型为2的UI
        if windowStack:GetMain():IsFullUIIgnoreFlow() then
            self:CloseWindowStack(windowStack,nil,isDestroy);
        else
            self:CloseWindowStack(windowStack,function()
                local preWindowStack = self._open_window_stack[#self._open_window_stack];
                if preWindowStack then
                    self:OpenWindowStack(preWindowStack,true);
                end
            end,isDestroy);
        end
    end
end

-- region 一些其他接口
-- 返回主界面
-- 卸载所有UI集合
-- 关闭所有UI集合
-- ...
-- endregion

-- endregion

-- region private
-- 加载UI集合
function UIManager:InitWindowStack(callback,windowStack)
    self:AddInitWindowStack(windowStack);
    windowStack:InitViews(function()
        if callback then
            callback(windowStack)
        end
    end);
end
-- 打开UI集合
function UIManager:OpenWindowStack(windowStack,isReveal)
    if not windowStack then
        return;
    end

    self:AddOpenWindowStack(windowStack);
    windowStack:OpenStack(isReveal);
end
-- 关闭UI集合
function UIManager:CloseWindowStack(windowStack,closeCall,isDestroy)
    if not windowStack then
        return;
    end

    self:RemoveOpenWindowStack(windowStack);
    if isDestroy then
        self:RemoveInitWindowStack(windowStack);
    end

    -- 关闭
    windowStack:CloseView(windowStack:GetMain());
    -- 关闭之后的回调 这个回调需要在当前UI集合关闭完成之后调用。
    -- 如果UI存在动画，必须等到动画完成之后才能回调 (偷个懒)
    if closeCall then
        closeCall();
    end
end
-- 加载lua代码
function UIManager:GetViews(viewNames)
    local views = nil;
    if viewNames then
        for i, v in ipairs(viewNames) do
            if not views then
                views = {};
            end
            table.insert(views,self:GetView(v,true));
        end
    end
    return views;
end
function UIManager:GetView(viewName)
    local view = self._ui_view_scripts[viewName]
    if not view then
        view = ViewConst[viewName]
        if view and ViewPath[view] then
            -- 加载完成后会加入到_ui_view_scripts中
            require(ViewPath[view][2])
            view = self._ui_view_scripts[viewName]
        end
    end
    return view
end
-- 注册脚本 防止多次require
function UIManager:RegisterUIScript(name,uiScript)
    if not self._ui_view_scripts[name] then
        self._ui_view_scripts[name] = uiScript
    end

end
-- UI的分类 参考UIBaseView头部解释
function UIManager:IsAllSonView()
    -- 代码...
end
-- 已经加载列表
function UIManager:AddInitWindowStack(windowStack)
    self:RemoveInitWindowStack(windowStack);
    table.insert(self._init_window_stack,windowStack);
end
function UIManager:RemoveInitWindowStack(windowStack)
    table.RemoveValue(self._init_window_stack,windowStack,true);
end
function UIManager:AddOpenWindowStack(windowStack)
    self:RemoveOpenWindowStack(windowStack);
    table.insert(self._open_window_stack,windowStack);
end
function UIManager:RemoveOpenWindowStack(windowStack)
    table.RemoveValue(self._open_window_stack,windowStack,true);
end
function UIManager:GetWindowStack(view)
    local inIndex = table.ContainValue(self._init_window_stack,view);
    return inIndex ~= 0 and self._init_window_stack[inIndex] or nil;
end

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

-- endregion

