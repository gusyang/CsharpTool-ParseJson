
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;


namespace consolJson
{
    class Program
    {
        static void Main(string[] args)
        {
            using (SqlConnection conn = new SqlConnection(ConfigurationManager.AppSettings["conn"]))
            {
                SqlCommand com1 = new SqlCommand(ConfigurationManager.AppSettings["com1"]);
                com1.CommandType = CommandType.Text;
                com1.Connection = conn;
                conn.Open();
                SqlDataReader reader = com1.ExecuteReader();
                if (reader.HasRows)
                {
                    while (reader.Read())
                    {
                        int id = reader.GetInt32(0);
                        string delivery = "";
                        string json = reader.GetString(1);
                        List<Dv> dvs = Dv.FromJson(json);
                        if (dvs.Count > 0)
                        {
                            foreach(Dv dv in dvs)
                            {
                                if (dv.Name.Equals("#DV_DeliveryDate#", StringComparison.CurrentCultureIgnoreCase))
                                    delivery = dv.Value.Substring(15, dv.Value.Length - 15);
                                DateTime tmp;
                                if (DateTime.TryParse(delivery, out tmp))
                                {
                                    SqlCommand update = new SqlCommand(ConfigurationManager.AppSettings["com2"]);
                                    update.CommandType = CommandType.Text;
                                    update.Connection = conn;
                                    SqlParameter pid = new SqlParameter();
                                    pid.ParameterName = "@ID";
                                    pid.SqlDbType = SqlDbType.Int;
                                    pid.Direction = ParameterDirection.Input;
                                    pid.Value = id;


                                    SqlParameter deliveryValue = new SqlParameter();
                                    deliveryValue.ParameterName = "@DeliveryTime";
                                    deliveryValue.SqlDbType = SqlDbType.DateTime;
                                    deliveryValue.Direction = ParameterDirection.Input;
                                    deliveryValue.Value = delivery;

                                    update.Parameters.Add(pid);
                                    update.Parameters.Add(deliveryValue);
                                    update.ExecuteNonQuery();                                    
                                }
                            }
                        }
                    }
                }
                else
                {
                    Console.WriteLine("No rows found.");
                }
                reader.Close();
                if(conn.State == ConnectionState.Open)
                {
                    conn.Close();
                }
                Console.Read();
            }

        }
    }
}
