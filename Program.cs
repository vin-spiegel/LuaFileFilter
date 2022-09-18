using System;
using System.Collections.Generic;
using System.IO;
using LuaScriptLoader.Cli;
using LuaScriptLoader.Core;
using LuaScriptLoader.Plugin;

namespace LuaScriptLoader
{
    internal class Program
    {
        private readonly ModuleLoader _moduleLoader = new ModuleLoader();
        private readonly Dictionary<string, LuaFile> _modules;
        
        public static void Main(string[] args)
        {
            new Program();
        }
        
        private static readonly string RootDir = Path.Combine(Directory.GetParent(Environment.CurrentDirectory).Parent.FullName, "example");

        private void RunScripts(Dictionary<string, LuaFile> modules)
        {
            using (var moonSharpScope = new MoonSharpScope(modules))
            {
                foreach (var file in modules)
                {
                    moonSharpScope.DoLuaFile(file.Value);
                }
            }
        }

        private Program()
        {
            Console.WriteLine(Command.Usage);
            while (true)
            {
                var res = Console.ReadLine();
                if (res == Command.IsVersion) ;
                    Console.WriteLine(Command.Version);
                if (res == Command.IsLoad) 
                    _modules = _moduleLoader.Load(RootDir);
                if (res == Command.IsRun)
                {
                    _modules = _moduleLoader.Load(RootDir);
                    RunScripts(_modules);
                }
            }
        }
    }
}