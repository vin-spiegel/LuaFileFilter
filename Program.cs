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
            
            // ScriptRunSync
            var modules = ScriptManager.Load();
            foreach (var file in modules)
            {
                ScriptManager.Run(file.Value);
            }
        }
    }
}