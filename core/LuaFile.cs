using MoonSharp.Interpreter;

namespace LuaScriptLoader.Core
{
    /// <summary xml:lang="ko">
    /// 각 루아 파일이 담겨져 있는 클래스입니다.
    /// </summary>
    public class LuaFile
    {
        public string Context { get; }
        public bool IsModule { get; }
        public DynValue Cache { get; set; }
        public LuaFile(string context, bool isModule = false)
        {
            Context = context;
            IsModule = isModule;
        }
    }
}