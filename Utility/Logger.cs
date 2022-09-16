using System;

namespace LuaScriptLoader.Utility
{
    public static class Logger
    {
        public static void Warn(object str)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine($"Warning: {str}");
            Console.ResetColor();
        }
        
        public static void Success(object str)
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine($"Success: {str}");
            Console.ResetColor();
        }
        
        public static void Error(object str)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"Error: {str}");
            Console.ResetColor();
        }
    }
}