using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using MoonSharp.Interpreter;

namespace MoonSharpDemo
{
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
        private static readonly Dictionary<string, string> Modules = new Dictionary<string, string>();

        public static void Init()
        {
            _script = new Script();
            _script.Globals["require"] = (Func<string, DynValue>)Require;
        }

        /// <summary xml:lang="ko">
        /// require 함수 구현
        /// </summary>
        private static DynValue Require(string path)
        {
            var key = GetKeyFromLuaScript(path);
            
            if (Modules.TryGetValue(key, out var res))
                return _script.DoString(res);

            Console.WriteLine($"Error: module not found {path}");

            return null;
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

        /// <summary>
        /// 모듈 로딩하여 딕셔너리에 적재
        /// </summary>
        public static void Load()
        {
            var files = Directory.GetFiles(RootDir, "*.lua", SearchOption.AllDirectories);
            foreach (var fullName in files)
            {
                Modules[GetKey(fullName)] = File.ReadAllText(fullName);;
            }

            // 테스트용 엔트리 파일 실행
            var mainFile = Modules.TryGetValue("main", out var stream);
            _script.DoString(stream);
        }
    }
}