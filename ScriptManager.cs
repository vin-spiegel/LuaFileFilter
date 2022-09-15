using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using MoonSharp.Interpreter;

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
        /// 모듈 로딩하여 딕셔너리에 적재
        /// </summary>
        public static Dictionary<string, LuaFile> Load(string path = null)
        {
            var files = Directory.GetFiles(RootDir, "*.lua", SearchOption.AllDirectories);
            foreach (var fullName in files)
            {
                modules[GetKey(fullName)] = new LuaFile(File.ReadAllText(fullName));;
            }

            return modules;
        }
    }
}