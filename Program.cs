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
            LuaProcess.Init();
            
            var modules = LuaProcess.Load(RootDir);

            // 스크립트 실행
            foreach (var unused in LuaProcess.GetUnusedFileNames())
            {
                Console.WriteLine($"Warn: Unused file - {unused}.lua");
            }
            
            // Unused logging
            foreach (var file in modules)
            {
                LuaProcess.DoStringLuaFile(file.Value);
            }
            
            //
        }
    }
}