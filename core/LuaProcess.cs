using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using MoonSharp.Interpreter;

namespace LuaDivider.Core
{
    public static partial class LuaProcess
    {
        private static readonly Dictionary<string, LuaFile> _modules = new Dictionary<string, LuaFile>();
        private static string _rootDir;
        /// <summary>
        /// 모듈 export 패턴
        /// </summary>
        private static readonly string[] _libraryPatterns =
        {
            "return\\s+[a-zA-Z0-9_-]+$",
            "return\\s+[a-zA-Z0-9_-]+([.,a-zA-Z0-9_-]+)",
            "return\\s+(return\\s+[a-zA-Z0-9-_]+\\s*=\\s*|){[\\w\\W]+}"
        };
        private static readonly Regex _requireRegex = new Regex("require[\\s+]?[\\(]?[\"\']([0-9\\/a-zA-Z_-]+)[\"\'][\\)]?");

        #region Private Methods
        // TODO: Replace -> Span 최적화
        private static string GetKey(string fullName, string path)
        {
            return fullName
                .Replace(path + "\\", string.Empty)
                .Replace(".lua", string.Empty)
                .Replace("\\", "/");
        }
        private static bool IsLibraryModule(string chunk)
        {
            return _libraryPatterns.Any(pattern => Regex.IsMatch(chunk, pattern));
        }

        private static HashSet<string> GetRequireFileNames()
        {
            var list = new HashSet<string>();
            foreach (var file in _modules)
            {
                foreach (Match match in _requireRegex.Matches(file.Value.Context))
                {
                    var name = match.Groups[1].ToString();
                    if (!list.Contains(name))
                        list.Add(name);
                }
            }
            return list;
        }
        #endregion

        #region Public Methods
        public static HashSet<string> GetUnusedFileNames()
        {
            var list = new HashSet<string>();
            var requires = GetRequireFileNames();
            foreach (var file in _modules)
            {
                if (!requires.Contains(file.Key) && file.Value.IsModule)
                    list.Add(file.Key);
            }

            return list;
        }
        /// <summary xml:lang="ko">
        /// 모듈 로딩하여 라이브러리 파일인지 확인 후 딕셔너리에 적재
        /// </summary>
        public static Dictionary<string,LuaFile> Load(string path)
        {
            var files = Directory.GetFiles(path, "*.lua", SearchOption.AllDirectories);
            
            _modules.Clear();
            
            // 폴더내 모든 LuaFile 적재
            foreach (var fullName in files)
            {
                var context = File.ReadAllText(fullName);
                var isLibraryModule = IsLibraryModule(context);
                var key = GetKey(fullName, path);
                _modules[key] = new LuaFile(context, isLibraryModule);
            }

            var requires = GetRequireFileNames();

            var res = new Dictionary<string, LuaFile>();
            
            // Library 파일이 아닌건 require 만 적재, 비즈니스 파일은 require 없어도 적재
            foreach (var file in _modules)
            {
                if (requires.Contains(file.Key) || !file.Value.IsModule)
                    res.Add(file.Key, file.Value);
            }

            return res;
        }
        #endregion
    }
}