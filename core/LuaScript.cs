using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using MoonSharp.Interpreter;

namespace LuaScriptLoader.Core
{
    public static class LuaScript
    {
        private static Script _script;
        private const string Pattern = "(.lua)[\"\'\\s]?[\\)\\s]?$";
        private static Dictionary<string, LuaFile> _modules;
        public static void Create(Dictionary<string,LuaFile> files)   
        {
            _script = new Script();
            _script.Globals["require"] = (Func<string, DynValue>)Require;
            _modules = files;
        }
        private static string GetKeyFromLuaScript(string path) => Regex.Replace(path, Pattern, "").Replace('.', '/');

        /// <summary xml:lang="ko">
        /// require 함수 구현
        /// </summary>
        private static DynValue Require(string path)
        {
            var key = GetKeyFromLuaScript(path);

            if (_modules.TryGetValue(key, out var file))
                return DoLuaFile(file);

            Console.WriteLine($"Error: module not found {path}");
            return null;
        }
        /// <summary xml:lang="ko">
        /// return 값이 있는 라이브러리 모듈은 한번만 실행합니다.
        /// </summary>
        public static DynValue DoLuaFile(LuaFile file)
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
    }
}