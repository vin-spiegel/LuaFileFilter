using System;
using System.Collections.Generic;
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
        
        public LuaFile(string context)
        {
            Context = context;
        }
        
        public DynValue Cache { get; set; }
        
        public bool IsModule
        {
            get
            {
                if (Cache == null)
                    return false;
                
                return Cache.Type == DataType.Table || Cache.Type == DataType.Function;
            }
        }
    }

    public static class ScriptManager
    {
        private static readonly string RootDir = Path.Combine(Directory.GetParent(Environment.CurrentDirectory).Parent.FullName, "example");
        private const string Pattern = "(.lua)[\"\'\\s]?[\\)\\s]?$";
        private static readonly Regex _requireRegex = new Regex("require[\\(]?[\"\']([0-9\\/a-zA-Z_-]+)[\"\'][\\)]?");
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

        /// <summary xml:lang="ko">
        /// return 값이 있는 라이브러리 모듈은 한번만 실행합니다.
        /// </summary>
        private static DynValue DoStringLuaFile(LuaFile file)
        {
            if (file.IsModule)
                return file.Cache;

            file.Cache = _script.DoString(file.Context);
            return file.Cache;
        }

        /// <summary xml:lang="ko">
        /// require 예약어 걸린 파일 리스트 업데이트
        /// </summary>
        private static void RefreshRequires(string context)
        {
            foreach (Match match in _requireRegex.Matches(context))
            {
                var name = match.Groups[1].ToString();
                if (!_requires.Contains(name))
                    _requires.Add(name);
            }
        }

        /// <summary xml:lang="ko">
        /// 폴더 내에 안쓰는 루아 모듈 얻기
        /// </summary>
        private static IEnumerable<string> GetNoHasRequireFiles()
        {
            var list = new HashSet<string>();
            var names = _modules.Keys.ToArray();
            foreach(var name in names)
            {
                if (!_requires.Contains(name))
                {
                    list.Add(name);
                }
            }
            return list;
        }

        private static void RunScriptsSync(IEnumerable<string> hashSet)
        {
            foreach (var file in hashSet.Select(name => _modules[name]))
            {
                DoStringLuaFile(file);
            }
        }

        /// <summary>
        /// for case 1 & 4
        /// </summary>
        public static string pattern1 = "return\\s+[a-zA-Z0-9_-]+$";
        
        /// <summary>
        /// for case 3
        /// </summary>
        public static string pattern2 = "return\\s+[a-zA-Z0-9_-]+([.,a-zA-Z0-9_-]+)";
        
        /// <summary>
        /// for case 2
        /// </summary>
        public static string pattern3 = "return\\s+(return\\s+[a-zA-Z0-9-_]+\\s*=\\s*|){[\\w\\W]+}";
        
        // TODO: 쓰지 않는 모듈 파일(require 호출이 없는 DynValue.Table)은 로딩 안되게 해야함.
        // TODO: 마지막 `return` 예약어 해석 ?
        /// <summary xml:lang="ko">
        /// 모듈 로딩하여 딕셔너리에 적재
        /// </summary>
        public static void Load(string path = null)
        {
            var files = Directory.GetFiles(RootDir, "*.lua", SearchOption.AllDirectories);
            
            foreach (var fullName in files)
            {
                var context = File.ReadAllText(fullName);
                var key = GetKey(fullName);
                _modules[key] = new LuaFile(context);
                
                var result = Regex.IsMatch(context, pattern1) || Regex.IsMatch(context, pattern2) || Regex.IsMatch(context, pattern3);
                Console.WriteLine($"{key} : {result}");
                RefreshRequires(context);
            }
            
            // 모듈 먼저 임포팅
            RunScriptsSync(_requires);
            Console.WriteLine(@"Success: - ""Imported Require Modules""");
            
            // return 구문이 없는 일반 파일 실행
            RunScriptsSync(GetNoHasRequireFiles());
            Console.WriteLine(@"Success: - ""Imported Modules""");
        }
    }
}