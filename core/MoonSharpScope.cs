using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using MoonSharp.Interpreter;

namespace LuaScriptLoader.Core
{
    public partial class MoonSharpScope : IDisposable
    {
        private const string Pattern = "(.lua)[\"\'\\s]?[\\)\\s]?$";
        private static string GetKeyFromLuaScript(string path) =>
            Regex.Replace(path, Pattern, "").Replace('.', '/');
        
        private Script _script = new Script();
        
        private Dictionary<string, LuaFile> _modules;

        public MoonSharpScope(Dictionary<string, LuaFile> modules)
        {
            _modules = modules;
            RegisterMoonSharpGlobals();
        }

        /// <summary xml:lang="ko">
        /// return 값이 있는 라이브러리 모듈은 한번만 실행합니다.
        /// </summary>
        public DynValue DoLuaFile(LuaFile file)
        {
            if (file == null)
            {
                _script.DoString("print(has no file)");
                return null;
            }

            // 파일에 캐시가 있지만, 라이브러리 모듈일때는 스크립트 실행 안하고 캐시만 넘겨줌
            if (file.Cache != null && file.IsModule)
                return file.Cache;

            // 파일에 캐시가 있고, 비즈니스 파일일때
            if (file.Cache != null && file.Cache.Type == DataType.Function)
            {
                file.Cache.Function.Call();
                return null;
            }

            // 첫 실행일 경우 파일 캐싱
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