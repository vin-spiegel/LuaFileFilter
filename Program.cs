using System;
using System.IO;
using MoonSharp.Interpreter;

namespace MoonSharpDemo
{
    internal class Program
    {
        private readonly ModuleLoader _moduleLoader = new ModuleLoader();
        public static void Main(string[] args)
        {
            new Program();
        }
        
        private static readonly string RootDir = Path.Combine(Directory.GetParent(Environment.CurrentDirectory).Parent.FullName, "example");

        private Program()
        {
            var modules = _moduleLoader.Load(RootDir);
            
            using (var moonSharpScope = new MoonSharpScope(modules))
            {
                foreach (var file in modules)
                {
                    moonSharpScope.DoLuaFile(file.Value);
                }
            }
        }
    }
}