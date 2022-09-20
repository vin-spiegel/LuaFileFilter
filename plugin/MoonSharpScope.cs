using System;
using System.Collections.Generic;
using LuaScriptLoader.Core;
using MoonSharp.Interpreter;

namespace LuaScriptLoader.Plugin
{
    public partial class MoonSharpScope : IDisposable
    {
        private Script _script = new Script();
        private Dictionary<string, TScript> _modules;
        private readonly Dictionary<string, DynValue> _dynValues = new Dictionary<string, DynValue>();
        
        public MoonSharpScope(Dictionary<string, TScript> modules)
        {
            _modules = modules;
            RegisterMoonSharpGlobals();
        }

        /// <summary xml:lang="ko">
        /// return 값이 있는 라이브러리 모듈은 한번만 실행합니다.
        /// </summary>
        public DynValue DoLuaFile(TScript file)
        {
            if (file == null)
            {
                _script.DoString("error('has no file')");
                return null;
            }
            
            // 라이브러리 모듈일때는 스크립트 실행 안하고 캐시만 넘겨줌
            if (file.cached && file.isLibrary)
                return _dynValues[file.name];

            if (file.cached && _dynValues[file.name].Type == DataType.Void)
            {
                Console.WriteLine($"void -> {file.name}");
                _dynValues[file.name].Function.Call();
                return null;
            }

            // 첫 실행일 경우 파일 캐싱
            _dynValues[file.name] = _script.DoString(file.context);
            file.cached = true;
            return _dynValues[file.name];
        }

        #region IDisposable
        
        public void Dispose()
        {
            _modules?.Clear();
            _modules = null;
            _dynValues?.Clear();
            _script = null;
        }

        #endregion
    }
}