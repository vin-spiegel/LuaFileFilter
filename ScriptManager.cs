using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using MoonSharp.Interpreter;

namespace MoonSharpDemo
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

    public static class ScriptManager
    {
        private static readonly string RootDir = Path.Combine(Directory.GetParent(Environment.CurrentDirectory).Parent.FullName, "example");
        private const string Pattern = "(.lua)[\"\'\\s]?[\\)\\s]?$";
        private static readonly Dictionary<string, LuaFile> _modules = new Dictionary<string, LuaFile>();
        private static readonly HashSet<string> _requires = new HashSet<string>();
        private static Script _script;
        
        public static void Init()
        {
            _script = new Script();
            _script.Globals["require"] = (Func<string, DynValue>)Require;
        }
        
        private static string GetKeyFromLuaScript(string path) => Regex.Replace(path, Pattern, "").Replace('.', '/');
        
        // TODO: Replace -> Span 최적화
        private static string GetKey(string fullName)
        {
            return fullName
                .Replace(RootDir + "\\", string.Empty)
                .Replace(".lua", string.Empty)
                .Replace("\\", "/");
        }
        
        /// <summary xml:lang="ko">
        /// require 함수 구현
        /// </summary>
        private static DynValue Require(string path)
        {
            var key = GetKeyFromLuaScript(path);

            if (_modules.TryGetValue(key, out var file))
                return DoStringLuaFile(file);

            Console.WriteLine($"Error: module not found {path}");
            return null;
        }

        /// <summary>
        /// 모듈 export 패턴
        /// </summary>
        private static readonly string[] patterns =
        {
            "return\\s+[a-zA-Z0-9_-]+$",
            "return\\s+[a-zA-Z0-9_-]+([.,a-zA-Z0-9_-]+)",
            "return\\s+(return\\s+[a-zA-Z0-9-_]+\\s*=\\s*|){[\\w\\W]+}"
        };

        private static bool IsLibraryModule(string chunk)
        {
            return patterns.Any(pattern => Regex.IsMatch(chunk, pattern));
        }
        
        private static readonly Regex _requireRegex = new Regex("require[\\s+]?[\\(]?[\"\']([0-9\\/a-zA-Z_-]+)[\"\'][\\)]?");
        private static HashSet<string> GetRequireFileNames()
        {
            var list = new HashSet<string>();
            foreach (var file in _modules)
            {
                foreach (Match match in _requireRegex.Matches(file.Value.Context))
                {
                    var name = match.Groups[1].ToString();
                    if (!list.Contains(name))
                        list.Add(name);
                }
            }
            return list;
        }

        /// <summary xml:lang="ko">
        /// return 값이 있는 라이브러리 모듈은 한번만 실행합니다.
        /// </summary>
        public static DynValue DoStringLuaFile(LuaFile file)
        {
            if (file == null)
            {
                _script.DoString("print(has no file)");
                return null;
            }

            if (file.Cache != null && file.IsModule)
                return file.Cache;
            
            file.Cache = _script.DoString(file.Context);
            return file.Cache;
        }

        public static HashSet<string> GetUnusedFileNames()
        {
            var list = new HashSet<string>();
            var requires = GetRequireFileNames();
            foreach (var file in _modules)
            {
                if (!requires.Contains(file.Key) && file.Value.IsModule)
                    list.Add(file.Key);
            }

            return list;
        }

        /// <summary xml:lang="ko">
        /// 모듈 로딩하여 라이브러리 파일인지 확인 후 딕셔너리에 적재
        /// </summary>
        public static Dictionary<string,LuaFile> Load(string path = null)
        {
            var files = Directory.GetFiles(RootDir, "*.lua", SearchOption.AllDirectories);
            
            _modules.Clear();
            
            // 폴더내 모든 LuaFile 적재
            foreach (var fullName in files)
            {
                var context = File.ReadAllText(fullName);
                var isLibraryModule = IsLibraryModule(context);
                var key = GetKey(fullName);
                _modules[key] = new LuaFile(context, isLibraryModule);
            }

            var requires = GetRequireFileNames();

            var res = new Dictionary<string, LuaFile>();
            
            // Library 파일이 아닌건 require 만 적재, 비즈니스 파일은 require 없어도 적재
            foreach (var file in _modules)
            {
                if (requires.Contains(file.Key) || !file.Value.IsModule)
                    res.Add(file.Key, file.Value);
            }

            return res;
        }
    }
}