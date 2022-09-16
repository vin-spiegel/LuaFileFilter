using System;
using System.IO;
using MoonSharp.Interpreter;

namespace LuaDivider.Core
{
    internal class Program
    {
        public static void Main(string[] args)
        {
            new Program();
        }
        
        private static readonly string RootDir = Path.Combine(Directory.GetParent(Environment.CurrentDirectory).Parent.FullName, "example");

        private Program()
        {
            var modules = LuaProcess.Load(RootDir);
            // Unused logging
            foreach (var unused in LuaProcess.GetUnusedFileNames())
            {
                Console.WriteLine($"Warn: Unused file - {unused}.lua");
            }
            
            LuaScript.Create(modules);
            // 스크립트 실행
            foreach (var file in modules)
            {
                LuaScript.DoLuaFile(file.Value);
            }
        }
    }
}