using System;
using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using LuaInterface;
using System.Runtime.InteropServices;
using System.Text;
using SoftStar.Scripts.UI;

public class UICore : UITimer
{

    // Use this for initialization
    public delegate void OnAnimEvent(int param0, float param1, string param2, float param3);

    public enum ComponentType
    {
        Transform,
        Panel,
        Label,
        Input,
        Button,
        Texture,
        Sprite,
        Animator,
        Progressbar,
        Toggle,
        SpringPanel,
        BoxCollider,
        GameObject,
        LuaTable,
        UIWrapContent,
        ExtendContent,
        AudioSource,
        AudioLoader,
        ScrollView,
        UILoopGrid,
        UICore,
        UIGrid,
        UICenterOnChild,
        UIWidget,
        UIPolygonBar,
        UIMainMapJoyStick,
        UIPlayTween,
        TweenScale,
        UITable,
        UISlider,
        TweenAlpha,
        TweenWidth,
        TweenRotation,
        TweenPosition,
        UIPopupList,
        UIToggledObjects,
    }

    public enum InteractType
    {
        Null,
        Click,
        DragStart,
        DragEnd,
        DragIn,
        Select,
        MonoDragStart,
        MonoDragEnd,
        MonoDragIn,
        ContentInitlaizeItem,
        ExpandItems,
        DragSourceStart,
        DragSourceEnd,
        DragTargetEnd,
        AnimationEnd,
        ExtendGetItemSize,
        ExtendInitializeItem,
        AnimationEvent,
        OnInputSubmit,//文本框输入完成（回车或手机上的完成键）
        OnFocusChange,//组件焦点变化
        OnFocusChangeTo,//组件焦点变化为（由监听组件变成了其他的）
        LongPress,
        Press,
        sliderValueChange,
        popupListOnChange,
    }

    public enum UIDepth
    {
        Normal,
        Top1,
        Bottom1,
        Top2,
        Bottom2,
        Top3,
        Bottom3,
    }

    [System.Serializable]
    public class ParamEvent
    {
        public string EventCallback;
        public InteractType eventType = InteractType.Null;
    }

    [System.Serializable]
    public class Param
    {
        public string name;
        public Transform transform;
        public ComponentType type = ComponentType.Transform;
        public string localText;
        public List<ParamEvent> events = new List<ParamEvent>();
        private string local_path;

        public string LocalPath
        {
            set { local_path = value; }
            get { return local_path; }
        }

        public bool IsValid()
        {
            return name != "";
        }

        public Param Clone()
        {
            return (Param)MemberwiseClone();
        }
    }


    [System.Serializable]
    public class ParamArray
    {
        public string name;
        public Param parent;
        public ParamArrayEle first;
    }

    [System.Serializable]
    public class ParamArrayEle
    {
        public Param root;
        public List<Param> childs;
    }

    [System.Serializable]
    public class LocalText
    {
        public string local_str;
        public UILabel label;

    }

    public UIDepth depth = UIDepth.Normal;

    public List<Param> param = new List<Param>();

    public List<ParamArray> paramArray = new List<ParamArray>();

    public List<LocalText> local = new List<LocalText>();

    public List<Param> allParam = new List<Param>();

    private OnAnimEvent onAnimEvent;

    private bool isPaused;

    private LuaTable mLuaTable;

    private LuaFunction mPauseFunc;

    private Transform mainTransform;

    private Vector3 mainVec3;

    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {

    }

    public void Init(LuaTable t)
    {
        EnableDisable();
        InitCore(t);
        InitLocal();
        InitMainTransForm();
    }

    public void SetPauseFunction(LuaFunction luaFun) {
        mPauseFunc = luaFun;
    }

    public void InitMainTransForm()
    {
        mainTransform = this.transform.Find("main");
        if (null != mainTransform)
        {
            mainVec3 = mainTransform.localPosition;
        }
    }

    public void RelocateMainTransForm()
    {
        if(mainTransform != null)
        {
            mainTransform.localPosition = mainVec3;
        }
    }

    void InitLocal()
    {
        int len = local.Count;
        for (int i = 0; i < len; ++i)
        {
            LocalText lt = local[i];
            if (lt.label != null)
            {
                lt.label.text = StringManager.GetLocalString(lt.local_str);
            }
        }
    }


    void InitCore(LuaTable t)
    {
        if (t == null)
        {
            if (GameLogger.IsEnable) GameLogger.Error("initcore failed, lua table is null");
        }
        mLuaTable = t;
        mPauseFunc = t.RawGetFunc("OnAppPause");
        int len = allParam.Count;
        for (int i = 0; i < len; ++i)
        {
            Param v = allParam[i];
            if (v.IsValid())
            {
                AssginWidget(t, v);
            }
        }
        t["ui_core"] = transform.GetComponent<UICore>();
        t["_gameObject"] = gameObject;
    }

    void AssginWidget(LuaTable t, Param param)
    {
        ComponentType e = param.type;
        Transform transform = param.transform;
        string name = param.name;
        if (transform == null) {
            Debugger.LogError("[big error]transform not found key:"+ name+",uiCoreName:"+gameObject.name);
            return;
        }
        if (ComponentType.Transform == e)
        {
            t[name] = transform;
        }
        else if (ComponentType.Label == e)
        {
            UILabel label = transform.GetComponent<UILabel>();
            t[name] = label;
            if (param.localText != "")
            {
                label.text = StringManager.GetLocalString(param.localText);
            }
        }
        else if (ComponentType.Button == e)
        {
            t[name] = transform.GetComponent<UIButton>();
        }
        else if (ComponentType.Input == e)
        {
            t[name] = transform.GetComponent<UIInput>();
        }
        else if (ComponentType.Panel == e)
        {
            t[name] = transform.GetComponent<UIPanel>();
        }
        else if (ComponentType.Progressbar == e)
        {
            t[name] = transform.GetComponent<UIProgressBar>();
        }
        else if (ComponentType.SpringPanel == e)
        {
            t[name] = transform.GetComponent<SpringPanel>();
        }
        else if (ComponentType.Sprite == e)
        {
            t[name] = transform.GetComponent<UISprite>();
        }
        else if (ComponentType.Texture == e)
        {
            t[name] = transform.GetComponent<UITexture>();
        }
        else if (ComponentType.Toggle == e)
        {
            t[name] = transform.GetComponent<UIToggle>();
        }
        else if (ComponentType.Animator == e)
        {
            t[name] = transform.GetComponent<Animator>();
        }
        else if (ComponentType.BoxCollider == e)
        {
            t[name] = transform.GetComponent<BoxCollider>();
        }
        else if (ComponentType.GameObject == e)
        {
            t[name] = transform.gameObject;
        }
        else if (ComponentType.UIWrapContent == e)
        {
            t[name] = transform.GetComponent<UIWrapContent>();
        }
        else if (ComponentType.ExtendContent == e)
        {
            t[name] = transform.GetComponent<UIExtendContent>();
        }
        else if (ComponentType.AudioSource == e)
        {
            t[name] = transform.GetComponent<AudioSource>();
        }
        else if (ComponentType.AudioLoader == e)
        {
            t[name] = transform.GetComponent<AudioLoader>();
        }
        else if (ComponentType.ScrollView == e)
        {
            t[name] = transform.GetComponent<UIScrollView>();
        }
        else if (ComponentType.UILoopGrid == e)
        {
            t[name] = transform.GetComponent<UILoopGrid>();
        }
        else if (ComponentType.UICore == e)
        {
            t[name] = transform.GetComponent<UICore>();
        }
        else if (ComponentType.UIGrid == e)
        {
            t[name] = transform.GetComponent<UIGrid>();
        }
        else if (ComponentType.UICenterOnChild == e)
        {
            t[name] = transform.GetComponent<UICenterOnChild>();
        }
        else if (ComponentType.UIWidget == e)
        {
            t[name] = transform.GetComponent<UIWidget>();
        }
        else if (ComponentType.UIPolygonBar == e)
        {
            t[name] = transform.GetComponent<UIPolygonBar>();
        }
        else if (ComponentType.UIMainMapJoyStick == e)
        {
            t[name] = transform.GetComponent<UIMainMap>();
        }
        else if (ComponentType.UIPlayTween == e)
        {
            t[name] = transform.GetComponent<UIPlayTween>();
        }
        else if (ComponentType.TweenScale == e)
        {
            t[name] = transform.GetComponent<TweenScale>();
        }
        else if (ComponentType.UITable == e)
        {
            t[name] = transform.GetComponent<UITable>();
        }
        else if (ComponentType.UISlider == e)
        {
            t[name] = transform.GetComponent<UISlider>();
        }
        else if (ComponentType.LuaTable == e)
        {
            IntPtr L = LuaScriptMgr.Instance.lua.L;
            t.push(L);
            LuaDLL.lua_pushstring(L, name);
            LuaDLL.lua_createtable(L, 0, 0);
            LuaDLL.lua_settable(L, -3);
            LuaDLL.lua_pop(L, 1);
        }
        else if (ComponentType.TweenAlpha == e)
        {
            t[name] = transform.GetComponent<TweenAlpha>();
        }
        else if (ComponentType.TweenWidth == e)
        {
            t[name] = transform.GetComponent<TweenWidth>();
        }
        else if (ComponentType.TweenRotation == e)
        {
            t[name] = transform.GetComponent<TweenRotation>();
        }
        else if (ComponentType.TweenPosition == e)
        {
            t[name] = transform.GetComponent<TweenPosition>();
        }
        else if (ComponentType.UIToggledObjects == e)
        {
            t[name] = transform.GetComponent<UIToggledObjects>();
        }

        if (param.events.Count > 0)
        {
            for (int i = 0; i < param.events.Count; ++i)
            {
                if (InteractType.Null != param.events[i].eventType)
                {
                    RegisterCallback(t, transform.gameObject, param.events[i].eventType, param.events[i].EventCallback);
                }

            }
        }

        LuaFunction func = t.RawGetFunc("insertPropertyList");
        if (func != null)
        {
            func.Call(t, name);
        }

        if (t[name] == null) {
            Debug.LogError("uicore里的"+ name+"为null"+"  uicoreName:"+gameObject.name);
        }
    }

    void RegisterCallback(LuaTable t, GameObject go, InteractType e, string funcName)
    {
        if (funcName == "")
        {
            if (GameLogger.IsEnable) GameLogger.Error("[UICore.RegisterCallback] UI: " + this.transform.parent.name + " func is null, target name: " + go.name);
            return;
        }


        LuaFunction func = t.RawGetFunc(funcName);
        if (func != null)
        {
            if (InteractType.Click == e)
            {
                UIEventListenerCSWrap.RegisterOnClick(go, t, func);
            }
            else if (InteractType.Press == e)
            {
                UIEventListenerCSWrap.RegisterOnPress(go, t, func);
            }
            else if (InteractType.LongPress == e)
            {
                UIEventListenerCSWrap.RegisterOnLongPress(go, t, func);
            }
            else if (InteractType.DragStart == e)
            {
                UIEventListenerCSWrap.RegisterOnDragStart(go, t, func);
            }
            else if (InteractType.DragEnd == e)
            {
                UIEventListenerCSWrap.RegisterOnDragEnd(go, t, func);
            }
            else if (InteractType.DragIn == e)
            {
                UIEventListenerCSWrap.RegisterOnDrag(go, t, func);
            }
            else if (InteractType.Select == e)
            {
                UIEventListenerCSWrap.RegisterOnSelect(go, t, func);
            }
            else if (InteractType.MonoDragStart == e)
            {
                UIEventListenerCSWrap.RegisterOnMonoStartDrag(go, t, func);
            }
            else if (InteractType.MonoDragEnd == e)
            {
                UIEventListenerCSWrap.RegisterOnMonoEndDrag(go, t, func);
            }
            else if (InteractType.MonoDragIn == e)
            {
                UIEventListenerCSWrap.RegisterOnMonoInDrag(go, t, func);
            }
            else if (InteractType.ContentInitlaizeItem == e)
            {
                UIEventListenerCSWrap.RegisterUIWrapContentOnInitializeItem(go, t, func);
            }
            else if (InteractType.ExpandItems == e)
            {
                UIEventListenerCSWrap.RegisterUIWrapContentOnExpandItems(go, t, func);
            }
            else if (InteractType.DragSourceStart == e)
            {
                UIEventListenerCSWrap.RegisterUIDragDropSourceOnDragSource(go, t, func);
            }
            else if (InteractType.DragSourceEnd == e)
            {
                UIEventListenerCSWrap.RegisterUIDragDropSourceOnDragSourceEnd(go, t, func);
            }
            else if (InteractType.DragTargetEnd == e)
            {
                UIEventListenerCSWrap.RegisterUIDragDropTargetOnDragTargetEnd(go, t, func);
            }
            else if (InteractType.AnimationEnd == e)
            {
                Animator anim = go.transform.GetComponent<Animator>();
                if (anim)
                {
                    AnimEvent.RegisterAnimationEnd(anim.GetInstanceID(), func);
                }
            }
            else if (InteractType.ExtendGetItemSize == e)
            {
                UIEventListenerCSWrap.RegisterUIExtendOnGetItemSize(go, t, func);
            }
            else if (InteractType.ExtendInitializeItem == e)
            {
                UIEventListenerCSWrap.RegisterUIExtendOnInitializeItem(go, t, func);
            }
            else if (InteractType.AnimationEvent == e)
            {

                onAnimEvent = (param0, param1, param2, param3) =>
                {
                    IntPtr L = LuaScriptMgr.Instance.lua.L;
                    int top = func.BeginPCall();
                    LuaScriptMgr.Push(L, t);
                    LuaScriptMgr.Push(L, param0);
                    LuaScriptMgr.Push(L, param1);
                    LuaScriptMgr.Push(L, param2);
                    LuaScriptMgr.Push(L, param3);
                    func.PCall(top, 5);
                    func.EndPCall(top);
                };
            }
            else if (InteractType.OnInputSubmit == e)
            {
                UIEventListenerCSWrap.RegisterOnUIInputSubmit(go, t, func);
            }
            else if (InteractType.OnFocusChange == e)
            {
                UIEventListenerCSWrap.RegisterOnForcusChange(go, t, func);
            }
            else if (InteractType.OnFocusChangeTo == e)
            {
                UIEventListenerCSWrap.RegisterOnForcusChangeTo(go, t, func);
            }
            else if (InteractType.sliderValueChange == e)
            {
                UIEventListenerCSWrap.RegisterUIProgress(go,t, func);
            }
            else if (InteractType.popupListOnChange == e)
            {
                UIEventListenerCSWrap.RegisterOnPopupListOnChange(go, t, func);
            }
        }
        else
        {
            if (GameLogger.IsEnable) GameLogger.Error("[UICore.RegisterCallback] UI: " + this.transform.parent.name + " cb func: " + funcName + " is null");
        }
    }

    string GetChildPath(string root_name, Transform trans)
    {
        string path = trans.name;
        Transform child = trans;
        int counter = 0;
        while (child.parent != null && child.parent.name != root_name && counter < 10)
        {
            path = child.parent.name + "/" + path;
            child = child.parent;
            ++counter;
        }

        return path;
    }

    public void BindAllWidgets()
    {
        for (int i = param.Count - 1; i >= 0; i--) {
            if (param[i].transform == null) {
                Debug.LogError("找不到name:"+param[i].name);

                param.RemoveAt(i);
            }
        }

        allParam.Clear();
        foreach (Param v in param) {
            allParam.Add(v);
        }

        foreach (ParamArray arr in paramArray)
        {
            Param first = arr.first.root;
            //string first_name = first.name;
            /*if (first_name == "")
            {
                first_name = first.transform.name;
            }
            */

            Transform parent = arr.parent.transform;

            if (parent)
            {
                allParam.Add(arr.parent);

                int count = parent.childCount;
                //if (GameLogger.IsEnable) GameLogger.Error("array count: " + count);
                for (int i = 0; i < count; ++i)
                {
                    string root_name = first.name + (i + 1);
                    //现将第一个child完整加入
                    if (0 == i)
                    {
                        Param first_clone = first.Clone();
                        //firstName1
                        first_clone.name = root_name;
                        allParam.Add(first_clone);
                        //if (GameLogger.IsEnable) GameLogger.Error("add param name: " + first_clone.name);
                        foreach (Param child in arr.first.childs)
                        {
                            string local_path = GetChildPath(first.transform.name, child.transform);
                            child.LocalPath = local_path;
                            Param child_clone = child.Clone();
                            //firstName1_chilName
                            child_clone.name = root_name + "_" + child_clone.name;
                            allParam.Add(child_clone);
                            //if (GameLogger.IsEnable) GameLogger.Error("add param name: " + child_clone.name);
                        }
                    }
                    else
                    {
                        string path = "";
                        if (i < 9)
                        {
                            path = "00" + (i + 1);
                        }
                        else
                        {
                            path = "0" + (i + 1);
                        }
                        Transform trans = parent.Find(path);
                        if (trans)
                        {
                            Param param2 = first.Clone();
                            //firstName2..n
                            param2.name = root_name;
                            param2.transform = trans;
                            allParam.Add(param2);
                            //if (GameLogger.IsEnable) GameLogger.Error("add param name: " + param2.name);
                            foreach (Param child2 in arr.first.childs)
                            {
                                string child2_trans_name = child2.transform.name;
                                Transform child2_trans = trans.Find(child2.LocalPath);
                                if (child2_trans)
                                {
                                    Param child2_clone = child2.Clone();
                                    child2_clone.transform = child2_trans;
                                    child2_clone.name = root_name + "_" + child2_clone.name;
                                    allParam.Add(child2_clone);
                                    //if (GameLogger.IsEnable) GameLogger.Error("add param name: " + child2_clone.name);
                                }
                                else
                                {
                                    if (GameLogger.IsEnable) GameLogger.Error("[UICore:BindAllWidgets] UI: " + this.transform.parent.name + ", " + trans.name + " miss child, path: " + child2_trans_name);
                                }
                            }

                        }
                        else
                        {
                            if (GameLogger.IsEnable) GameLogger.Error("[UICore:BindAllWidgets] UI: " + this.transform.parent.name + ", " + parent.name + " miss child, path: " + path);
                        }
                    }

                }
            }
            else
            {
                if (GameLogger.IsEnable) GameLogger.Error("[UICore:BindAllWidgets] array miss parent, widget: " + first.transform.name);
            }
        }

        StringBuilder sb = new StringBuilder();
        foreach (Param v in allParam) {
            sb.AppendLine(GenLuaApiString(v));
        }
        print(sb.ToString());

        //if (GameLogger.IsEnable) GameLogger.Log("[UICore:BindAllWidgets] success");
    }

    private string GenLuaApiString(Param v){
        string result = string.Format("---@field public {0} {1}", v.name, GetTypeName(v));
        return result;
    }
    private static string GetTypeName(Param param) {
        ComponentType e = param.type;
        string result = "";
        if (ComponentType.Transform == e)
        {
            result = typeof(Transform).Name;
        }
        else if (ComponentType.Label == e)
        {
            result = typeof(UILabel).Name;
        }
        else if (ComponentType.Button == e)
        {
            result = typeof(UIButton).Name;
        }
        else if (ComponentType.Input == e)
        {
            result = typeof(UIInput).Name;
        }
        else if (ComponentType.Panel == e)
        {
            result = typeof(UIPanel).Name;
        }
        else if (ComponentType.Progressbar == e)
        {
            result = typeof(UIProgressBar).Name;
        }
        else if (ComponentType.SpringPanel == e)
        {
            result = typeof(SpringPanel).Name;
        }
        else if (ComponentType.Sprite == e)
        {
            result = typeof(UISprite).Name;
        }
        else if (ComponentType.Texture == e)
        {
            result = typeof(UITexture).Name;
        }
        else if (ComponentType.Toggle == e)
        {
            result = typeof(UIToggle).Name;
        }
        else if (ComponentType.Animator == e)
        {
            result = typeof(Animator).Name;
        }
        else if (ComponentType.BoxCollider == e)
        {
            result = typeof(BoxCollider).Name;
        }
        else if (ComponentType.GameObject == e)
        {
            result = typeof(GameObject).Name;
        }
        else if (ComponentType.UIWrapContent == e)
        {
            result = typeof(UIWrapContent).Name;
        }
        else if (ComponentType.ExtendContent == e)
        {
            result = typeof(UIExtendContent).Name;
        }
        else if (ComponentType.AudioSource == e)
        {
            result = typeof(AudioSource).Name;
        }
        else if (ComponentType.AudioLoader == e)
        {
            result = typeof(AudioLoader).Name;
        }
        else if (ComponentType.ScrollView == e)
        {
            result = typeof(UIScrollView).Name;
        }
        else if (ComponentType.UILoopGrid == e)
        {
            if (!Application.isPlaying)
            {
                param.transform.GetComponent<UILoopGrid>().Execute();
            }
            result = typeof(UILoopGrid).Name;
        }
        else if (ComponentType.UICore == e)
        {
            result = typeof(UICore).Name;
        }
        else if (ComponentType.UIGrid == e)
        {
            result = typeof(UIGrid).Name;
        }
        else if (ComponentType.UICenterOnChild == e)
        {
            result = typeof(UICenterOnChild).Name;
        }
        else if (ComponentType.UIWidget == e)
        {
            result = typeof(UIWidget).Name;
        }
        else if (ComponentType.UIPolygonBar == e)
        {
            result = typeof(UIPolygonBar).Name;
        }
        else if (ComponentType.UIMainMapJoyStick == e)
        {
            result = typeof(UIMainMap).Name;
        }
        else if (ComponentType.UIPlayTween == e)
        {
            result = typeof(UIPlayTween).Name;
        }
        else if (ComponentType.TweenScale == e)
        {
            result = typeof(TweenScale).Name;
        }
        else if (ComponentType.UISlider == e)
        {
            result = typeof(UISlider).Name;
        }
        else if (ComponentType.UITable == e)
        {
            result = typeof(UITable).Name;
        }
        else if (ComponentType.UIToggledObjects == e)
        {
            result = typeof(UIToggledObjects).Name;
        }
        return result;
    }
    public void OnAnimationEvent(AnimationEvent e)
    {
        //LuaScriptMgr.Instance.CallLuaFunction("SendAnimEventHandler", param);
        if (onAnimEvent != null)
        {
            onAnimEvent(e.intParameter, e.floatParameter, e.stringParameter, e.time);
        }
    }

    void OnApplicationFocus(bool hasFocus)
    {
        isPaused = !hasFocus;
        if (mLuaTable != null && mPauseFunc != null)
        {
            mPauseFunc.Call(mLuaTable, isPaused);
        }
    }

    void OnApplicationPause(bool pauseStatus)
    {
        isPaused = pauseStatus;
        if (mLuaTable != null && mPauseFunc != null)
        {
            mPauseFunc.Call(mLuaTable, isPaused);
        }
    }

    protected override void OnDestroy()
    {
        if (StaticConfig.isReleaseInactiveWhenDestroyUICore)
        {
            UIDrawCall.ReleaseInactive();
        }        
        if (GameMgr.Instance != null)
        {
            //GameMgr.Instance.GCCollect(false, false, true);
        }
        base.OnDestroy();
    }
}
