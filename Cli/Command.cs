using System;
using System.Threading;

namespace LuaScriptLoader.Cli
{
    public static class Command
    {
        public const string Version = "lua filter version 1.0.1";

        public const string Usage = 
@"usage: lf [-version] [-load] [-load <path>] [-run] [-run <path]";

        public const string IsVersion = "lf -version";
        public const string IsLoad = "lf -load";
        public const string IsLoadPath = @"lf -load";
        public const string IsRun = @"lf -run";
        public const string IsRunPath = @"lf -load";
    }
}