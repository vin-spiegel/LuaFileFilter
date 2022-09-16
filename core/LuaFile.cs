namespace LuaScriptLoader.Core
{
    /// <summary xml:lang="ko">
    /// 각 루아 파일이 담겨져 있는 클래스입니다.
    /// </summary>
    public class LuaFile
    {
        public string Name { get; }
        public string Context { get; }
        public bool IsLibrary { get; }
        public bool Cached { get; set; }
        public LuaFile(string name, string context, bool isLibrary = false)
        {
            Name = name;
            Context = context;
            IsLibrary = isLibrary;
        }
    }
}