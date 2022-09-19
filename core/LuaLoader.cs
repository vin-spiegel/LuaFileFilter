using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

namespace LuaScriptLoader.Core
{
    public class LuaLoader
    {
        private readonly Dictionary<string, bool> _requires = new Dictionary<string, bool>();
        private Dictionary<string, LuaFile> _modules = new Dictionary<string, LuaFile>();
        private string _workDir = ".";
        private string _dirName;
        private static readonly Regex _regex = new Regex("[^-]require[\\s+]?[\\(]?[\"\']([0-9\\/a-zA-Z_-]+)[\"\'][\\)]?");
        
        /// <summary>
        /// 모듈 export 패턴
        /// </summary>
        private readonly string[] _patterns =
        {
            "return\\s+[a-zA-Z0-9_-]+$",
            // "return\\s+[a-zA-Z0-9_-]+([.,a-zA-Z0-9_-]+)",
            "return\\s+(return\\s+[a-zA-Z0-9-_]+\\s*=\\s*|){[\\w\\W]+}"
        };
        
        /// <summary xml:lang="ko">
        /// require 예약어 걸린 파일 이름 리스트 얻기
        /// </summary>
        private List<string> GetNewFileNames(string file)
        {
            var matches = _regex.Matches(file);
            
            // 중복 파일일 경우 Emit 하지 않기
            var newNames = new List<string>();
            foreach (Match match in matches)
            {
                var newName = match.Groups[1].ToString();
                if (_requires.ContainsKey(newName))
                {
                    _requires[newName] = false;
                }
                else
                {
                    newNames.Add(newName);
                }
            }
            return newNames;
        }
        
        /// <summary xml:lang="ko">
        /// 파일 여부 리턴
        /// </summary>
        private static bool CheckFileExist(string path)
        {
            var fi = new FileInfo(path).Exists;
            if (!fi)
                Console.WriteLine($"Error: File not found - {path}");
            return fi;
        }

        private string GetFullName(string workDir, string name)
        {
            var prime = new FileInfo(Path.Combine(workDir, name + ".lua"));

            var secondary = new FileInfo(prime.FullName.Replace(_dirName, "Shared"));
                
            if (prime.Exists)
                return prime.FullName;
            
            return secondary.Exists ? secondary.FullName : prime.FullName;
        }

        /// <summary xml:lang="ko">
        /// 루아 코드를 재귀적으로 생성합니다
        /// </summary>
        /// <param name="name"></param>
        private void RecurseFiles(string name)
        {
            if (_requires.ContainsKey(name) && _requires[name])
                return;
            
            var fullName = GetFullName(_workDir, name);

            if (!CheckFileExist(fullName))
                return;

            var context = File.ReadAllText(fullName);
            _requires[name] = true;
            var isPrimary = new FileInfo(fullName).Directory?.ToString() == _workDir;
            // 모듈 딕셔너리에 LuaFile 생성
            _modules.Add(name, new LuaFile(
                name, 
                fullName, 
                context, 
                IsLibraryModule(context), 
                isPrimary));
            
            // 뎁스 추적하며 require 예약어가 걸린 파일들 생성하기
            foreach (var newName in GetNewFileNames(context))
            {
                RecurseFiles(newName);
            }
        }
        
        public LuaFile[] LoadPrimaryModules()
        {
            if (_modules == null)
                return null;

            var list = new List<LuaFile>();
            foreach (var pair in _modules)
            {
                if(pair.Value.IsPrimary && !pair.Value.IsLibrary)
                    list.Add(pair.Value);
            }

            return list.ToArray();
        }

        public Dictionary<string, LuaFile> Load(string rootPath, string dir)
        {
            var mainPath = Path.Combine(rootPath, dir);
            var di = new DirectoryInfo(mainPath);
            
            if (!di.Exists) 
                return null;
            
            _dirName = dir;
            _workDir = di.FullName;
            
            foreach (var path in Directory.GetFiles(mainPath, "*.lua"))
            {
                var file = File.ReadAllText(path);
                if (!IsLibraryModule(file))
                    RecurseFiles(Path.GetFileNameWithoutExtension(path));
            }
            
            // _requires.Clear();
            return _modules;
        }

        private bool IsLibraryModule(string chunk)
        {
            return _patterns.Any(pattern => Regex.IsMatch(chunk, pattern));
        }
    }
}