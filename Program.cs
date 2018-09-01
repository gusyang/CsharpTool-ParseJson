
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;


namespace consolJson
{
    class Program
    {
        static void Main(string[] args)
        {
            int id = 0;
            SqlConnection conn = null;
            try
            {
                using ( conn = new SqlConnection(Utility.GetConfig("conn")))
                {
                    SqlCommand com1 = new SqlCommand(Utility.GetConfig("com1"));
                    com1.CommandType = CommandType.Text;
                    com1.Connection = conn;
                    conn.Open();
                    SqlDataReader reader = com1.ExecuteReader();
                    if (reader.HasRows)
                    {
                        while (reader.Read())
                        {
                            id = reader.GetInt32(0);
                            string delivery = "";
                            string json = reader.GetString(1);
                            List<Dv> dvs = Dv.FromJson(json);
                            if (dvs.Count > 0)
                            {
                                foreach (Dv dv in dvs)
                                {
                                    if (dv.Name.Equals("#DV_DeliveryDate#", StringComparison.CurrentCultureIgnoreCase))
                                        delivery = dv.Value.Substring(15, dv.Value.Length - 15);
                                    DateTime tmp;
                                    if (DateTime.TryParse(delivery, out tmp))
                                    {
                                        try
                                        {
                                            SqlCommand update = new SqlCommand(Utility.GetConfig("com2"));
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
                                        }catch(Exception ex)
                                        {
                                            //do not jump out even have exception data, continue to update next record;
                                            Utility.Log(LogTarget.File, String.Format("ID:{0}, Ex:{1}", id, ex.Message));
                                            continue;
                                        }
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
                    if (conn.State == ConnectionState.Open)
                    {
                        conn.Close();
                    }
                }
            }catch(Exception e)
            {
                Utility.Log(LogTarget.File, String.Format("ID:{0}, Ex:{1}", id, e.Message));
            }
            finally
            {
                if (conn.State == ConnectionState.Open)
                {
                    conn.Close();
                }
            }
        }
    }
}
