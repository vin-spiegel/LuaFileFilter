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
            ScriptManager.Load();
        }
    }
}