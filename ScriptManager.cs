﻿using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using MoonSharp.Interpreter;

namespace MoonSharpDemo
{
    /// <summary xml:lang="ko">
    /// 각 루아 파일이 담겨져 있는 클래스입니다.
    /// </summary>
    public class LuaFile
    {
        public LuaFile(string stream)
        {
            Stream = stream;
        }
        public bool IsModule { get; set; }
        public DynValue Cached { get; set; }
        public string Stream { get; set; }
    }

    public static class ScriptManager
    {
        private static Script _script;
        
        private static readonly string RootDir = Path.Combine(Directory.GetParent(Environment.CurrentDirectory).Parent.FullName, "src");

        /// <summary>
        /// .lua 지원 regex
        /// </summary>
        private static readonly string _pattern = "(.lua)[\"\'\\s]?[\\)\\s]?$";
        
        /// <summary>
        /// [파일이름][스크립트]
        /// </summary>
        private static readonly Dictionary<string, LuaFile> Modules = new Dictionary<string, LuaFile>();

        public static void Init()
        {
            _script = new Script();
            _script.Globals["require"] = (Func<string, DynValue>)Require;
        }

        /// <summary xml:lang="ko">
        /// require 함수 구현
        /// </summary>
        private static DynValue Require(string path)
        {
            var key = GetKeyFromLuaScript(path);

            if (Modules.TryGetValue(key, out var file))
            {
                if (file.Cached != null)
                    return file.Cached;
                
                return Run(file);
            }
            
            Console.WriteLine($"Error: module not found {path}");
            return null;
        }

        private static string GetKeyFromLuaScript(string path) 
            => Regex.Replace(path, _pattern, "").Replace('.', '/');

        private static string GetKey(string fullName)
        {
            return fullName
                .Replace(RootDir + "\\", string.Empty)
                .Replace(".lua", string.Empty)
                .Replace("\\","/");
        }

        public static DynValue Run(LuaFile file)
        {
            file.Cached =  _script.DoString(file.Stream);
            return file.Cached;
        }

        /// <summary>
        /// 모듈 로딩하여 딕셔너리에 적재
        /// </summary>
        public static void Load()
        {
            var files = Directory.GetFiles(RootDir, "*.lua", SearchOption.AllDirectories);
            foreach (var fullName in files)
            {
                Modules[GetKey(fullName)] = new LuaFile(File.ReadAllText(fullName));;
            }

            // 테스트용 엔트리 파일 실행 (main.lua)
            if (Modules.TryGetValue("main", out var file) && file != null) 
                _script.DoString(file.Stream);
        }
    }
}