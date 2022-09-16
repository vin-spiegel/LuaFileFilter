using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using MoonSharp.Interpreter;

namespace MoonSharpDemo
{
    public class MoonSharpScope : IDisposable
    {
        private const string Pattern = "(.lua)[\"\'\\s]?[\\)\\s]?$";
        
        private Script _script = new Script();
        
        private Dictionary<string, LuaFile> _modules;

        private static string GetKeyFromLuaScript(string path) =>
            Regex.Replace(path, Pattern, "").Replace('.', '/');
        
        public MoonSharpScope(Dictionary<string, LuaFile> modules)
        {
            _modules = modules;
            _script.Globals["require"] = (Func<string, DynValue>)Require;
        }

        private DynValue Require(string path)
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
        public DynValue DoStringLuaFile(LuaFile file)
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

        #region IDisposable
        
        public void Dispose()
        {
            _modules?.Clear();
            _modules = null;
            _script = null;
        }

        #endregion
    }
}