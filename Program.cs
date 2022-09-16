using System;
using System.IO;
using MoonSharp.Interpreter;

namespace MoonSharpDemo
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
            ScriptManager.Init(RootDir);
            
            var modules = ScriptManager.Load();

            // 스크립트 실행
            foreach (var unused in ScriptManager.GetUnusedFileNames())
            {
                Console.WriteLine($"Warn: Unused file - {unused}.lua");
            }
            
            foreach (var file in modules)
            {
                ScriptManager.DoStringLuaFile(file.Value);
            }
            
            //
        }
    }
}