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
        public LuaFile(string stream)
        {
            Stream = stream;
        }
        public bool IsModule { get; set; }
        public bool Inited { get; set; }
        public DynValue CachedDynValue { get; set; }
        public string Stream { get; set; }
    }

    public static class MoonSharpExtensions
    {
        public static bool IsModule(this DynValue value) => value != null && (value.Type == DataType.Table || value.Type == DataType.Function);
    }

    public static class ScriptManager
    {
        private static Script _script;
        
        private static readonly string RootDir = Path.Combine(Directory.GetParent(Environment.CurrentDirectory).Parent.FullName, "src");

        /// <summary>
        /// .lua 지원 regex
        /// </summary>
        private static readonly string _pattern = "(.lua)[\"\'\\s]?[\\)\\s]?$";
        
        /// <summary>
        /// [파일이름][스크립트]
        /// </summary>
        private static readonly Dictionary<string, LuaFile> modules = new Dictionary<string, LuaFile>();

        public static void Init()
        {
            _script = new Script();
            _script.Globals["require"] = (Func<string, DynValue>)Require;
        }

        

        private static string GetKeyFromLuaScript(string path) 
            => Regex.Replace(path, _pattern, "").Replace('.', '/');

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

            if (!modules.TryGetValue(key, out var file))
            {
                Console.WriteLine($"Error: module not found {path}");
                return null;
            }

            // Dynamic Value가 모듈일땐 캐시 데이터 리턴
            if (file.CachedDynValue.IsModule())
                return file.CachedDynValue;

            return Run(file);
        }
        
        public static DynValue Run(LuaFile file)
        {
            if (file.CachedDynValue == null)
                file.Inited = true;

            if (file.Inited && file.CachedDynValue != null && file.CachedDynValue.IsModule())
                return file.CachedDynValue;
            
            file.CachedDynValue = _script.DoString(file.Stream);
            return file.CachedDynValue;
        }

        /// <summary>
        /// 모듈 로딩하여 딕셔너리에 적재
        /// </summary>
        public static void Load(string path = null)
        {
            var files = Directory.GetFiles(RootDir, "*.lua", SearchOption.AllDirectories);
            foreach (var fullName in files)
            {
                modules[GetKey(fullName)] = new LuaFile(File.ReadAllText(fullName));;
            }

            // ScriptRunSync
            foreach (var file in modules)
            {
                Run(file.Value);
            }
        }
    }
}