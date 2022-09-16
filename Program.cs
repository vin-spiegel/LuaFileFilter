using System;
using MoonSharp.Interpreter;

namespace MoonSharpDemo
{
    internal class Program
    {
        public static void Main(string[] args)
        {
            new Program();
        }

        private Program()
        {
            ScriptManager.Init();
            
            var modules = ScriptManager.Load();

            // 스크립트 실행
            foreach (var file in modules)
            {
                ScriptManager.DoStringLuaFile(file.Value);
            }
            
            //
            foreach (var unused in ScriptManager.GetUnusedFileNames())
            {
                Console.WriteLine($"Warn: Unused file - {unused}.lua");
            }
        }
    }
}