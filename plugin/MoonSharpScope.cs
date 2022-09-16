using System;
using System.Collections.Generic;
using LuaScriptLoader.Core;
using MoonSharp.Interpreter;

namespace LuaScriptLoader.Plugin
{
    public partial class MoonSharpScope : IDisposable
    {
        private Script _script = new Script();
        private Dictionary<string, LuaFile> _modules;
        private readonly Dictionary<string, DynValue> _collection = new Dictionary<string, DynValue>();
        
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
                _script.DoString("error(has no file)");
                return null;
            }
            
            // 라이브러리 모듈일때는 스크립트 실행 안하고 캐시만 넘겨줌
            if (file.Cached && file.IsLibrary)
                return _collection[file.Name];

            if (file.Cached && _collection[file.Name].Type == DataType.Function)
            {
                _collection[file.Name].Function.Call();
                return null;
            }

            // 첫 실행일 경우 파일 캐싱
            _collection[file.Name] = _script.DoString(file.Context);
            file.Cached = true;
            return _collection[file.Name];
        }

        #region IDisposable
        
        public void Dispose()
        {
            _modules?.Clear();
            _modules = null;
            _collection?.Clear();
            _script = null;
        }

        #endregion
    }
}