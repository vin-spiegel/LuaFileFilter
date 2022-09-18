using System;
using System.Collections.Generic;
using System.IO;
using LuaScriptLoader.Cli;
using LuaScriptLoader.Core;
using LuaScriptLoader.Plugin;
using LuaScriptLoader.Utility;

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
            var watcher = new FileSystemWatcher();
            watcher.Path = RootDir;
            watcher.Filter = "*.lua";
            watcher.NotifyFilter = NotifyFilters.FileName |
                                   NotifyFilters.DirectoryName |
                                   NotifyFilters.Size |
                                   NotifyFilters.LastAccess |
                                   NotifyFilters.CreationTime |
                                   NotifyFilters.LastWrite;
            watcher.IncludeSubdirectories = true;
            watcher.Changed += new FileSystemEventHandler(Changed);
            watcher.EnableRaisingEvents = true;
            
            Console.WriteLine(Command.Usage);
            while (true)
            {
                var res = Console.ReadLine();
                if (res == Command.IsVersion)
                    Console.WriteLine(Command.Version);
                else if (res == Command.IsLoad) 
                    _modules = _moduleLoader.Load(RootDir);
                else if (res == Command.IsRun)
                {
                    _modules = _moduleLoader.Load(RootDir);
                    RunScripts(_modules);
                }
                else
                {
                    Console.WriteLine(Command.Usage);
                }
            }
        }
        private void Changed(object source, FileSystemEventArgs e)
        {
            Logger.Warn($"File Changed {e.FullPath}");
            // var module = _moduleLoader.Load(RootDir);
            // RunScripts(module);
        }
    }
}