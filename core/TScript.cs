namespace LuaScriptLoader.Core
{
    /// <summary xml:lang="ko">
    /// 각 루아 파일이 담겨져 있는 클래스입니다.
    /// </summary>
    public class TScript
    {
        public string name { get; }
        public byte data { get; }
        public string context { get; }
        public string fullName { get; }
        public bool isLibrary { get; }
        public bool isPrimary { get; }
        
        public TScript(string name, string fullName, string context, bool isLibrary = false, bool isPrimary = false)
        {
            this.name = name;
            this.context = context;
            this.fullName = fullName;
            this.isLibrary = isLibrary;
            this.isPrimary = isPrimary;
        }
    }
}