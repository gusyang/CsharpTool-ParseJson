using System;
using System.Configuration;

namespace consolJson
{
    public static class Utility
    {
        public static string GetConfig(string name)
        {
            return ConfigurationManager.AppSettings[name];     
        }

        public static string GetConfig(string name, string defaultvalue)
        {
            string retValue = GetConfig(name);
            return String.IsNullOrEmpty(retValue) ? defaultvalue : retValue;
        }

        //Loger
        private static LogBase logger = null;
        public static void Log(LogTarget target,string message)
        {
            switch (target)
            {
                case LogTarget.File:
                    logger = new FileLog();
                    logger.Log(message);
                    break;
                case LogTarget.Database:
                    logger = new DBLogger();
                    logger.Log(message);
                    break;
                default:
                    return;
            }
        }
    }
}
