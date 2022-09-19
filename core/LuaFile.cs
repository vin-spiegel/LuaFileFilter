namespace LuaScriptLoader.Core
{
    /// <summary xml:lang="ko">
    /// 각 루아 파일이 담겨져 있는 클래스입니다.
    /// </summary>
    public class LuaFile
    {
        public string Name { get; }
        public string Context { get; }
        public string FullName { get; }
        public bool IsLibrary { get; }
        public bool IsPrimary { get; }
        
        public LuaFile(string name, string fullName, string context, bool isLibrary = false, bool isPrimary = false)
        {
            Name = name;
            Context = context;
            FullName = fullName;
            IsLibrary = isLibrary;
            IsPrimary = isPrimary;
        }
        public bool Cached { get; set; }
    }
}