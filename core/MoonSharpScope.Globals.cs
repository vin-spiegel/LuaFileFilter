using System;
using MoonSharp.Interpreter;

namespace LuaScriptLoader.Core
{
    /// <summary>
    /// 문샤프 글로벌 함수
    /// </summary>
    public partial class MoonSharpScope
    {
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
            var key = GetKeyFromLuaScript(path);

            if (_modules.TryGetValue(key, out var file))
                return DoLuaFile(file);

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