using System;
using System.Text.RegularExpressions;
using MoonSharp.Interpreter;

namespace LuaScriptLoader.Plugin
{
    /// <summary>
    /// 문샤프 글로벌 함수
    /// </summary>
    public partial class MoonSharpScope
    {
        private const string RequirePattern = "(.lua)[\"\'\\s]?[\\)\\s]?$";

        private static string ReplacePath(string path) =>
            Regex.Replace(path, RequirePattern, "").Replace('.', '/');
        
        /// <summary>
        /// 문샤프 글로벌 함수 등록
        /// </summary>
        private void RegisterMoonSharpGlobals()
        {
            _script.Globals["require"] = (Func<string, DynValue>)Require;
            _script.Globals["wait"] = (Func<float, DynValue>)Wait;
        }

        private DynValue Require(string path)
        {
            var name = ReplacePath(path);

            if (_modules.TryGetValue(name, out var file))
            {
                return DoLuaFile(file);
            }

            _script.DoString($"error('module not found: {path}')");
            Console.WriteLine($"Error: module not found {path}");
            return null;
        }

        private DynValue Wait(float time)
        {
            //TODO:
            return null;
        }
    }
}