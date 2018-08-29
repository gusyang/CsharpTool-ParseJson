// To parse this JSON data, add NuGet 'Newtonsoft.Json' then do:
//
//    using consolJson;
//
//    var dv = Dv.FromJson(jsonString);

namespace consolJson
{
    using System;
    using System.Collections.Generic;

    using System.Globalization;
    using Newtonsoft.Json;
    using Newtonsoft.Json.Converters;

    public partial class Dv
    {
        [JsonProperty("Name")]
        public string Name { get; set; }

        [JsonProperty("Value")]
        public string Value { get; set; }
    }

    public partial class Dv
    {
        public static List<Dv> FromJson(string json) => JsonConvert.DeserializeObject<List<Dv>>(json, consolJson.Converter.Settings);
    }

    public static class Serialize
    {
        public static string ToJson(this List<Dv> self) => JsonConvert.SerializeObject(self, consolJson.Converter.Settings);
    }

    internal static class Converter
    {
        public static readonly JsonSerializerSettings Settings = new JsonSerializerSettings
        {
            MetadataPropertyHandling = MetadataPropertyHandling.Ignore,
            DateParseHandling = DateParseHandling.None,
            Converters = {
                new IsoDateTimeConverter { DateTimeStyles = DateTimeStyles.AssumeUniversal }
            },
        };
    }
}
