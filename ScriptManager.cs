using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using MoonSharp.Interpreter;
using MoonSharp.Interpreter.Loaders;

namespace MoonSharpDemo
{
    /// <summary xml:lang="ko">
    /// 각 루아 파일이 담겨져 있는 클래스입니다.
    /// </summary>
    public class LuaFile
    {
        public string Stream { get; }
        
        public LuaFile(string stream)
        {
            Stream = stream;
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
        private static Script _script;
        
        private static readonly string RootDir = Path.Combine(Directory.GetParent(Environment.CurrentDirectory).Parent.FullName, "src");

        /// <summary>
        /// [파일이름][스크립트]
        /// </summary>
        private static readonly Dictionary<string, LuaFile> modules = new Dictionary<string, LuaFile>();
        
        /// <summary>
        /// .lua 지원 regex
        /// </summary>
        private static readonly string _pattern = "(.lua)[\"\'\\s]?[\\)\\s]?$";
        private static readonly Regex _regexRequire = new Regex("require[\\(]?[\"\']([0-9\\/a-zA-Z_-]+)[\"\'][\\)]?");

        private static string GetKeyFromLuaScript(string path) => Regex.Replace(path, _pattern, "").Replace('.', '/');
        
        public static void Init()
        {
            _script = new Script();
            _script.Globals["require"] = (Func<string, DynValue>)Require;
        }

        private static string GetKey(string fullName)
        {
            return fullName
                .Replace(RootDir + "\\", string.Empty)
                .Replace(".lua", string.Empty)
                .Replace("\\","/");
        }

        private static readonly HashSet<string> _requires = new HashSet<string>();
        
        /// <summary xml:lang="ko">
        /// require 함수 구현
        /// </summary>
        private static DynValue Require(string path)
        {
            var key = GetKeyFromLuaScript(path);

            if (modules.TryGetValue(key, out var file)) 
                return Run(file);
            
            Console.WriteLine($"Error: module not found {path}");
            return null;
        }
        
        /// <summary xml:lang="ko">
        /// 스크립트 실행, return값이 있는 라이브러리 모듈은 한번만 실행합니다.
        /// </summary>
        public static DynValue Run(LuaFile file)
        {
            if (file.IsModule)
                return file.Cache;

            file.Cache = _script.DoString(file.Stream);
            return file.Cache;
        }
        
        /// <summary xml:lang="ko">
        /// require 예약어 걸린 파일 이름 리스트 얻기
        /// </summary>
        private static void GetRequireFileName(string file)
        {
            foreach (Match match in _regexRequire.Matches(file))
            {
                var name = match.Groups[1].ToString();
                if (!_requires.Contains(name))
                    _requires.Add(name);
            }
        }

        private static void GetAllFiles()
        {
            
        }

        private static void GetAllModules()
        {
            
        }

        // TODO: 쓰지 않는 모듈 파일은 로딩 하면 안됨 => 마지막 return 구문 분석?
        ///
        /// <summary xml:lang="ko">
        /// 모듈 로딩하여 딕셔너리에 적재
        /// </summary>
        public static void Load(string path = null)
        {
            var files = Directory.GetFiles(RootDir, "*.lua", SearchOption.AllDirectories);
            // foreach (var fullName in files)
            // {
            //     modules[GetKey(fullName)] = new LuaFile(File.ReadAllText(fullName));
            // }
            _script.Options.ScriptLoader = new EmbeddedResourcesScriptLoader();
            _script.
            foreach (var fullName in files)
            {
                var chunk = File.ReadAllText(fullName);
                GetRequireFileName(chunk);
            }
            Console.Write(""_script.SourceCodeCount);
            // return modules;
        }
    }

    public class ScriptLoader : ScriptLoaderBase
    {
        public override object LoadFile(string file, Table globalContext)
        {
            return string.Format("print ([[A request to load '{0}' has been made]])", file);
        }

        public override bool ScriptFileExists(string name)
        {
            return true;
        }
        
    }
}