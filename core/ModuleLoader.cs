using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using LuaScriptLoader.Utility;

namespace LuaScriptLoader.Core
{
    public class ModuleLoader
    {

        /// <summary>
        /// 모듈 export 패턴
        /// </summary>
        private readonly string[] _patterns =
        {
            "return\\s+[a-zA-Z0-9_-]+$",
            "return\\s+[a-zA-Z0-9_-]+([.,a-zA-Z0-9_-]+)",
            "return\\s+(return\\s+[a-zA-Z0-9-_]+\\s*=\\s*|){[\\w\\W]+}"
        };

        private static readonly Regex RequireRegex =
            new Regex("require[\\s+]?[\\(]?[\"\']([0-9\\/a-zA-Z_-]+)[\"\'][\\)]?");

        /// <summary xml:lang="ko">
        /// 모듈 로딩하여 라이브러리 파일인지 확인 후 딕셔너리에 적재
        /// </summary>
        public Dictionary<string, LuaFile> Load(string rootPath)
        {
            if (string.IsNullOrEmpty(rootPath)) return null;
            
            var files = Directory.GetFiles(rootPath, "*.lua", SearchOption.AllDirectories);

            var modules = new Dictionary<string, LuaFile>();
            
            // 폴더내 모든 LuaFile Get
            foreach (var fullName in files)
            {
                var context = File.ReadAllText(fullName);
                var fileName = GetKey(rootPath, fullName);
                modules[fileName] = new LuaFile(fileName, context, IsLibraryModule(context));
            }
            
            var requires = GetRequireFileNames(modules);

            var result = new Dictionary<string, LuaFile>();
            
            // Library 파일이 아닌건 require 만 적재, 비즈니스 파일은 require 없어도 적재
            foreach (var file in modules)
            {
                if (!requires.Contains(file.Key) && file.Value.IsLibrary)
                {
                    Logger.Warn($"Unloaded   {file.Key}.lua");
                }
                
                if (requires.Contains(file.Key) || !file.Value.IsLibrary)
                {
                    Logger.Success($"Loaded     {file.Key}.lua");
                    result.Add(file.Key, file.Value);
                }
            }
            Logger.Success($"Loaded Lua Files: {result.Count} / {modules.Count}");
            return result;
        }

        #region Private
        private string GetKey(string rootPath, string fullName)
        {
            // TODO: Replace -> Span 최적화
            return fullName
                .Replace(rootPath + "\\", string.Empty)
                .Replace(".lua", string.Empty)
                .Replace("\\", "/");
        }
        
        private bool IsLibraryModule(string chunk)
        {
            return _patterns.Any(pattern => Regex.IsMatch(chunk, pattern));
        }
        
        private static HashSet<string> GetRequireFileNames(Dictionary<string, LuaFile> modules)
        {
            var list = new HashSet<string>();
            foreach (var file in modules)
            {
                foreach (Match match in RequireRegex.Matches(file.Value.Context))
                {
                    var name = match.Groups[1].ToString();
                    if (!list.Contains(name))
                        list.Add(name);
                }
            }
            return list;
        }
        #endregion
    }
}