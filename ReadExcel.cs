using System;
using System.IO;
using System.Data;
using System.Data.SqlClient;
using ExcelDataReader;
using System.Collections.Generic;
//packages: ExcelDataReader, ExcelDataReader.DataSet,System.Text.Encodeing.CodePages;
namespace ExcelRead
{
    class Program
    {
        private static List<string> lst = new List<string>();
        static void Main(string[] args)
        {
            // required because of known issue when running on .NET Core
            System.Text.Encoding.RegisterProvider(System.Text.CodePagesEncodingProvider.Instance);
            string path = @"D:\tmpfolder\1.xlsx";
            string sheetname = "";

            string[] col;


            using (var stream = File.Open(path, FileMode.Open, FileAccess.Read))
            using (var reader = ExcelReaderFactory.CreateReader(stream))
            {
                DataTableCollection sheets = reader.AsDataSet(GetDataSetConfig()).Tables;
                DataTable sheet = sheets[0];
                sheetname = sheet.TableName;

                foreach (DataRow row in sheet.Rows)
                {
                    for (int j = 0; j < sheet.Columns.Count; j++)
                    {
                        Console.Write(row[j]);
                    }
                    Console.WriteLine();
                }

            }
            //Console.WriteLine("Hello World!");

        }

        private static ExcelDataSetConfiguration GetDataSetConfig()
        {
            return new ExcelDataSetConfiguration
            {
                ConfigureDataTable = _ => new ExcelDataTableConfiguration()
                {
                    UseHeaderRow = true,
                    ReadHeaderRow = rowReader =>
                    {
                        for (int i = 0; i < rowReader.FieldCount; i++)
                        {
                            Console.Write("{0}", rowReader[i]);
                            lst.Add(rowReader[i].ToString());
                        }
                        Console.WriteLine();
                    }
                }
            };
        }
    }
}
