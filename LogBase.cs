using System;
using System.IO;

namespace consolJson
{
    public enum LogTarget
    {
        File,
        Database,
        EventLog
    }

    public abstract class LogBase
    {
        protected readonly object lockObj = new object();
        protected readonly string logfile = Utility.GetConfig("logFile", AppDomain.CurrentDomain.BaseDirectory + "Log.txt");
        public abstract void Log(string Message);
    }

    public class FileLog : LogBase
    {
        public override void Log(string Message)
        {
            lock (lockObj)
            {
                using (StreamWriter streamWriter = new StreamWriter(logfile))
                {
                    streamWriter.WriteLine(Message);
                    streamWriter.Close();
                }
            }

        }
    }

    public class DBLogger : LogBase
    {
        string connectionString = string.Empty;
        public override void Log(string message)
        {
            lock (lockObj)
            {
                //Code to log data to the database
            }
        }
    }
}
