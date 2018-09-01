using System;
using System.Diagnostics;
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


    public class EventLogger : LogBase
    {
        /// <summary>
        /// Add Event log
        /// </summary>
        /// <param name="message"></param>
        public override void Log(string message)
        {
            lock (lockObj)
            {
                EventLog m_EventLog = new EventLog("");
                m_EventLog.Source = "IDGEventLog";
                m_EventLog.WriteEntry(message);
            }
        }
    }

    public class DBLogger : LogBase
    {
        string connectionString = string.Empty;
        /// <summary>
        /// TBD: Add Log to Database
        /// </summary>
        /// <param name="message"></param>
        public override void Log(string message)
        {
            lock (lockObj)
            {
                //Code to log data to the database
            }
        }
    }
}
