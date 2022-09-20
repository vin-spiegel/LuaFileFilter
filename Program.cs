using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using LuaScriptLoader.Cli;
using LuaScriptLoader.Core;
using LuaScriptLoader.Plugin;
using LuaScriptLoader.Utility;
using MoonSharp.Interpreter;

namespace LuaScriptLoader
{
    internal class Program
    {
        private readonly Dictionary<string, TScript> _modules;
        
        public static void Main(string[] args)
        {
            new Program();
        }
        
        private static readonly string RootPath = Path.Combine(Directory.GetParent(Environment.CurrentDirectory).Parent.FullName, "example");

        private void RunScripts(Dictionary<string, TScript> modules)
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
            watcher.Path = RootPath;
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
                {
                // _modules = _moduleLoader.Load(RootPath);
                }
                else if (res == Command.IsRun)
                {
                    // _modules = _moduleLoader.Load(RootPath);
                    // RunScripts(_modules);
                }
                else
                {
                    var loader = new LuaLoader();
                    var modules = loader.Load(RootPath, "ServerScripts");
                    using (var moonSharpScope = new MoonSharpScope(modules))
                    {
                        var luaFiles = loader.LoadPrimaryModules().OrderBy(file => file.name);
                        foreach (var file in luaFiles)
                        {
                            moonSharpScope.DoLuaFile(file);
                        }
                    }
                    
                    Console.WriteLine("----------------------------");
                    var clientModules = loader.Load(RootPath, "Scripts");
                    using (var moonSharpScope = new MoonSharpScope(clientModules))
                    {
                        var luaFiles = loader.LoadPrimaryModules().OrderBy(file => file.name);
                        foreach (var file in luaFiles)
                        {
                            moonSharpScope.DoLuaFile(file);
                        }
                    }
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