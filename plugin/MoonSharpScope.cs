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

        public void Print()
        {
            foreach (var pair in _dynValues)
            {
                Console.WriteLine($"{pair.Key} file is {pair.Value.Type}");
            }
        }

        /// <summary xml:lang="ko">
        /// return 값이 있는 라이브러리 모듈은 한번만 실행합니다.
        /// </summary>
        public DynValue DoLuaFile(TScript tScript)
        {
            if (tScript == null)
            {
                Console.WriteLine("error: has no file");
                return null;
            }

            if (!_dynValues.TryGetValue(tScript.name, out var dynValue))
            {
                // 첫 실행일 경우 파일 캐싱
                return _dynValues[tScript.name] = _script.DoString(tScript.context);
            }
            
            // return값이 Void 타입이 아닐 경우 라이브러리 모듈로 간주
            if (dynValue.Type != DataType.Void)
                return dynValue;
            
            dynValue.Function.Call();
            return null;
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