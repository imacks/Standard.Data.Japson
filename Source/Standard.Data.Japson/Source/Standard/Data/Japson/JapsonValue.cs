using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Threading;

namespace Standard.Data.Japson
{
    /// <summary>
    /// This class represents the root type for a JAPSON configuration object.
    /// </summary>
    public class JapsonValue : IPossibleJapsonObject
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="JapsonValue"/> class.
        /// </summary>
        public JapsonValue()
        {
            Values = new List<IJapsonElement>();
        }

        /// <summary>
        /// Returns true if this JAPSON value doesn't contain any elements
        /// </summary>
        public bool IsEmpty
        {
            get { return Values.Count == 0; }
        }

        /// <summary>
        /// The list of elements inside this JAPSON value.
        /// </summary>
        public List<IJapsonElement> Values { get; private set; }

        /// <summary>
        /// Wraps this <see cref="JapsonValue"/> into a new <see cref="JapsonContext"/> object at the specified key.
        /// </summary>
        /// <param name="key">The key designated to be the new root element.</param>
        /// <returns>
        /// A <see cref="JapsonContext"/> with the given key as the root element.
        /// </returns>
        public JapsonContext AtKey(string key)
        {
            JapsonObject o = new JapsonObject();
            o.GetOrCreateKey(key);
            o.Items[key] = this;
            JapsonValue r = new JapsonValue();
            r.Values.Add(o);
            return new JapsonContext(new JapsonRoot(r));
        }

        /// <summary>
        /// The list of keys for a JAPSON value that is a JapsonObject.
        /// </summary>
        /// <exception cref="InvalidOperationException">This <see cref="JapsonValue" /> is not a Japson Object.</exception>
        public List<string> GetKeys()
        {
            JapsonObject jObject = GetObject();
            if (jObject == null)
                throw new InvalidOperationException(RS.Err_GetKeysFromNonJapsonObject);

            return jObject.Items.Keys.ToList();
        }

        /// <summary>
        /// Retrieves the <see cref="JapsonObject"/> from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>
        /// The <see cref="JapsonObject"/> that represents this <see cref="JapsonValue"/>.
        /// </returns>
        public JapsonObject GetObject()
        {
            //TODO: merge objects?
            IJapsonElement raw = Values.FirstOrDefault();
            JapsonObject o = raw as JapsonObject;
            IPossibleJapsonObject sub = raw as IPossibleJapsonObject;
            if (o != null) 
                return o;
            if (sub != null && sub.IsObject()) 
                return sub.GetObject();
            return null;
        }

        /// <summary>
        /// Determines if this <see cref="JapsonValue"/> is a <see cref="JapsonObject"/>.
        /// </summary>
        /// <returns>
        /// <c>true</c> if this value is a <see cref="JapsonObject"/>, <c>false</c> otherwise.
        /// </returns>
        public bool IsObject()
        {
            return GetObject() != null;
        }

        /// <summary>
        /// Adds the given element to the list of elements inside this <see cref="JapsonValue"/>.
        /// </summary>
        /// <param name="value">The element to add to the list.</param>
        public void AppendValue(IJapsonElement value)
        {
            Values.Add(value);
        }

        /// <summary>
        /// Clears the list of elements inside this <see cref="JapsonValue"/>.
        /// </summary>
        public void Clear()
        {
            Values.Clear();
        }

        /// <summary>
        /// Creates a fresh list of elements inside this <see cref="JapsonValue"/> and adds the given value to the list.
        /// </summary>
        /// <param name="value">The element to add to the list.</param>
        public void NewValue(IJapsonElement value)
        {
            Values.Clear();
            Values.Add(value);
        }

        /// <summary>
        /// Determines whether all the elements inside this <see cref="JapsonValue"/> are a string.
        /// </summary>
        /// <returns>
        /// <c>true</c>if all elements inside this <see cref="JapsonValue"/> are a string; otherwise <c>false</c>.
        /// </returns>
        public bool IsString()
        {
            return Values.Any() && Values.All(v => v.IsString());
        }

        private string ConcatString()
        {
            string concat = string.Join(string.Empty, Values.Select(l => l.GetString())).Trim();

            if (concat == "null")
                return null;

            return concat;
        }

        /// <summary>
        /// Retrieves the child object located at the given key.
        /// </summary>
        /// <param name="key">The key used to retrieve the child object.</param>
        /// <returns>The element at the given key.</returns>
        public JapsonValue GetChildObject(string key)
        {
            return GetObject().GetKey(key);
        }

        /// <summary>
        /// Retrieves the boolean value from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>The boolean value represented by this <see cref="JapsonValue"/>.</returns>
        /// <exception cref="System.NotSupportedException">
        /// This exception occurs when the <see cref="JapsonValue"/> does not conform to the standard boolean values: "on", "off", "true", or "false"
        /// </exception>
        public bool GetBoolean()
        {
            string v = GetString();
            switch (v)
            {
                case "on":
                    return true;
                case "off":
                    return false;
                case "true":
                    return true;
                case "false":
                    return false;
                case "yes":
                    return true;
                case "no":
                    return false;
                default:
                    throw new NotSupportedException(string.Format(RS.BadBooleanName, v));
            }
        }

        /// <summary>
        /// Retrieves the string value from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>The string value represented by this <see cref="JapsonValue"/>.</returns>
        public string GetString()
        {
            if (IsString())
                return ConcatString();

            return null; //TODO: throw exception?
        }

        /// <summary>
        /// Retrieves the decimal value from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>The decimal value represented by this <see cref="JapsonValue"/>.</returns>
        public decimal GetDecimal()
        {
            return decimal.Parse(GetString(), NumberFormatInfo.InvariantInfo);
        }

        /// <summary>
        /// Retrieves the float value from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>The float value represented by this <see cref="JapsonValue"/>.</returns>
        public float GetSingle()
        {
            return float.Parse(GetString(), NumberFormatInfo.InvariantInfo);
        }

        /// <summary>
        /// Retrieves the double value from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>The double value represented by this <see cref="JapsonValue"/>.</returns>
        public double GetDouble()
        {
            return double.Parse(GetString(), NumberFormatInfo.InvariantInfo);
        }

        /// <summary>
        /// Retrieves the long value from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>The long value represented by this <see cref="JapsonValue"/>.</returns>
        public long GetInt64()
        {
            return long.Parse(GetString(), NumberFormatInfo.InvariantInfo);
        }

        /// <summary>
        /// Retrieves the integer value from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>The integer value represented by this <see cref="JapsonValue"/>.</returns>
        public int GetInt32()
        {
            return int.Parse(GetString(), NumberFormatInfo.InvariantInfo);
        }

        /// <summary>
        /// Retrieves the byte value from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>The byte value represented by this <see cref="JapsonValue"/>.</returns>
        public byte GetByte()
        {
            return byte.Parse(GetString(), NumberFormatInfo.InvariantInfo);
        }

        /// <summary>
        /// Retrieves a list of byte values from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>A list of byte values represented by this <see cref="JapsonValue"/>.</returns>
        public IList<byte> GetByteList()
        {
            return GetArray().Select(v => v.GetByte()).ToList();
        }

        /// <summary>
        /// Retrieves a list of integer values from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>A list of integer values represented by this <see cref="JapsonValue"/>.</returns>
        public IList<int> GetInt32List()
        {
            return GetArray().Select(v => v.GetInt32()).ToList();
        }

        /// <summary>
        /// Retrieves a list of long values from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>A list of long values represented by this <see cref="JapsonValue"/>.</returns>
        public IList<long> GetInt64List()
        {
            return GetArray().Select(v => v.GetInt64()).ToList();
        }

        /// <summary>
        /// Retrieves a list of boolean values from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>A list of boolean values represented by this <see cref="JapsonValue"/>.</returns>
        public IList<bool> GetBooleanList()
        {
            return GetArray().Select(v => v.GetBoolean()).ToList();
        }

        /// <summary>
        /// Retrieves a list of float values from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>A list of float values represented by this <see cref="JapsonValue"/>.</returns>
        public IList<float> GetSingleList()
        {
            return GetArray().Select(v => v.GetSingle()).ToList();
        }

        /// <summary>
        /// Retrieves a list of double values from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>A list of double values represented by this <see cref="JapsonValue"/>.</returns>
        public IList<double> GetDoubleList()
        {
            return GetArray().Select(v => v.GetDouble()).ToList();
        }

        /// <summary>
        /// Retrieves a list of decimal values from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>A list of decimal values represented by this <see cref="JapsonValue"/>.</returns>
        public IList<decimal> GetDecimalList()
        {
            return GetArray().Select(v => v.GetDecimal()).ToList();
        }

        /// <summary>
        /// Retrieves a list of string values from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>A list of string values represented by this <see cref="JapsonValue"/>.</returns>
        public IList<string> GetStringList()
        {
            return GetArray().Select(v => v.GetString()).ToList();
        }

        /// <summary>
        /// Retrieves a list of values from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>A list of values represented by this <see cref="JapsonValue"/>.</returns>
        public IList<JapsonValue> GetArray()
        {
            IEnumerable<JapsonValue> x = from arr in Values
                where arr.IsArray()
                from e in arr.GetArray()
                select e;

            return x.ToList();
        }

        /// <summary>
        /// Determines whether this <see cref="JapsonValue"/> is an array.
        /// </summary>
        /// <returns>
        ///   <c>true</c> if this <see cref="JapsonValue"/> is an array; otherwise <c>false</c>.
        /// </returns>
        public bool IsArray()
        {
            IList<JapsonValue> array = GetArray();
            return (array != null) && (array.Count != 0);
        }

        /// <summary>
        /// Retrieves the time span value from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <param name="allowInfinite">A flag used to set infinite durations.</param>
        /// <returns>The time span value represented by this <see cref="JapsonValue"/>.</returns>
        public TimeSpan GetTimeSpan(bool allowInfinite = true)
        {
            string res = GetString();

            if (res.EndsWith("milliseconds") || res.EndsWith("millisecond") || res.EndsWith("millis") || res.EndsWith("milli"))
                res = "ms";
            else if (res.EndsWith("seconds") || res.EndsWith("second"))
                res = "s";
            else if (res.EndsWith("minutes") || res.EndsWith("minute"))
                res = "m";
            else if (res.EndsWith("hours") || res.EndsWith("hour"))
                res = "h";
            else if (res.EndsWith("days") || res.EndsWith("day"))
                res = "d";

            // #TODO: Add support for ns, us 
            // see https://github.com/typesafehub/config/blob/master/HOCON.md#duration-format
            if (res.EndsWith("ms"))
            {
                string v = res.Substring(0, res.Length - 2);
                return TimeSpan.FromMilliseconds(ParsePositiveValue(v));
            }

            if (res.EndsWith("s"))
            {
                string v = res.Substring(0, res.Length - 1);
                return TimeSpan.FromSeconds(ParsePositiveValue(v));
            }
            
            if (res.EndsWith("m"))
            {
                string v = res.Substring(0, res.Length - 1);
                return TimeSpan.FromMinutes(ParsePositiveValue(v));
            }
            
            if (res.EndsWith("h"))
            {
                string v = res.Substring(0, res.Length - 1);
                return TimeSpan.FromHours(ParsePositiveValue(v));
            }
            
            if (res.EndsWith("d"))
            {
                string v = res.Substring(0, res.Length - 1);
                return TimeSpan.FromDays(ParsePositiveValue(v));
            }
            
            // not in Japson spec
            if (allowInfinite && res.Equals("infinite", StringComparison.OrdinalIgnoreCase))  
                return Timeout.InfiniteTimeSpan;

            return TimeSpan.FromMilliseconds(ParsePositiveValue(res));
        }

        private static double ParsePositiveValue(string v)
        {
            double parsed = double.Parse(v, NumberFormatInfo.InvariantInfo);

            if (parsed < 0)
                throw new FormatException(string.Format(RS.ExpectPositiveNumber, parsed));

            return parsed;
        }

        /// <summary>
        /// Retrieves the long value from this <see cref="JapsonValue"/>.
        /// </summary>
        /// <exception cref="System.OverflowException">Maxiumum supported size is 7 exbibytes (e), or 9exabytes (eb).</exception>
        /// <returns>The long value represented by this <see cref="JapsonValue"/>.</returns>
        /// <remarks>
        /// This method returns a value of type <see cref="System.Int64" />. Therefore, the maximum supported size is 7e (or 9eb). 
        /// </remarks>
        public long? GetByteSize()
        {
            // #todo support for zb/yb

            string res = GetString();

            if (res.EndsWith("byte") || res.EndsWith("bytes"))
                res = "b";
            else if (res.EndsWith("kilobytes") || res.EndsWith("kilobyte"))
                res = "kb";
            else if (res.EndsWith("kib") || res.EndsWith("kibibytes") || res.EndsWith("kibibyte"))
                res = "k";
            else if (res.EndsWith("megabytes") || res.EndsWith("megabyte"))
                res = "mb";
            else if (res.EndsWith("mib") || res.EndsWith("mebibytes") || res.EndsWith("mebibyte"))
                res = "m";
            else if (res.EndsWith("gigabytes") || res.EndsWith("gigabyte"))
                res = "gb";
            else if (res.EndsWith("gib") || res.EndsWith("gibibytes") || res.EndsWith("gibibyte"))
                res = "g";
            else if (res.EndsWith("terabytes") || res.EndsWith("terabyte"))
                res = "tb";
            else if (res.EndsWith("tib") || res.EndsWith("tebibytes") || res.EndsWith("tebibyte"))
                res = "t";
            else if (res.EndsWith("petabytes") || res.EndsWith("petabyte"))
                res = "pb";
            else if (res.EndsWith("pib") || res.EndsWith("pebibytes") || res.EndsWith("pebibyte"))
                res = "p";
            else if (res.EndsWith("exabytes") || res.EndsWith("exabyte"))
                res = "eb";
            else if (res.EndsWith("eib") || res.EndsWith("exbibytes") || res.EndsWith("exbibyte"))
                res = "e";

            if (res.EndsWith("b"))
            {
                string v = res.Substring(0, res.Length - 1);
                return long.Parse(v);
            }

            if (res.EndsWith("kb"))
            {
                string v = res.Substring(0, res.Length - 2);
                return (long.Parse(v) * 1000);
            }
            if (res.EndsWith("k"))
            {
                string v = res.Substring(0, res.Length - 1);
                return (long.Parse(v) * 1024);
            }
            if (res.EndsWith("mb"))
            {
                string v = res.Substring(0, res.Length - 2);
                return (long.Parse(v) * 1000 * 1000);
            }
            if (res.EndsWith("m"))
            {
                string v = res.Substring(0, res.Length - 1);
                return (long.Parse(v) * 1024 * 1024);
            }
            if (res.EndsWith("gb"))
            {
                string v = res.Substring(0, res.Length - 2);
                return (long.Parse(v) * 1000 * 1000 * 1000);
            }
            if (res.EndsWith("g"))
            {
                string v = res.Substring(0, res.Length - 1);
                return (long.Parse(v) * 1024 * 1024 * 1024);
            }
            if (res.EndsWith("tb"))
            {
                string v = res.Substring(0, res.Length - 2);
                return (long.Parse(v) * 1000 * 1000 * 1000 * 1000);
            }
            if (res.EndsWith("t"))
            {
                string v = res.Substring(0, res.Length - 1);
                return (long.Parse(v) * 1024 * 1024 * 1024 * 1024);
            }
            if (res.EndsWith("pb"))
            {
                string v = res.Substring(0, res.Length - 2);
                return (long.Parse(v) * 1000 * 1000 * 1000 * 1000 * 1000);
            }
            if (res.EndsWith("p"))
            {
                string v = res.Substring(0, res.Length - 1);
                return (long.Parse(v) * 1024 * 1024 * 1024 * 1024 * 1024);
            }
            if (res.EndsWith("eb"))
            {
                string v = res.Substring(0, res.Length - 2);
                return (long.Parse(v) * 1000 * 1000 * 1000 * 1000 * 1000 * 1000);
            }
            if (res.EndsWith("e"))
            {
                string v = res.Substring(0, res.Length - 1);
                return (long.Parse(v) * 1024 * 1024 * 1024 * 1024 * 1024 * 1024);
            }

            return long.Parse(res);
        }

        /// <summary>
        /// Returns a JAPSON string representation of this <see cref="JapsonValue"/>.
        /// </summary>
        /// <returns>A JAPSON string representation of this <see cref="JapsonValue"/>.</returns>
        public override string ToString()
        {
            return ToString(0);
        }

        /// <summary>
        /// Returns a JAPSON string representation of this <see cref="JapsonValue"/>.
        /// </summary>
        /// <param name="indent">The number of spaces to indent the string.</param>
        /// <returns>A JAPSON string representation of this <see cref="JapsonValue"/>.</returns>
        public virtual string ToString(int indent)
        {
            if (IsString())
            {
                string text = QuoteIfNeeded(GetString());
                return text;
            }
            if (IsObject())
            {
                string i = new string(' ', indent * 2);
                return string.Format("{{\r\n{1}{0}}}", i, GetObject().ToString(indent + 1));
            }
 
            if (IsArray())
                return string.Format("[{0}]", string.Join(",", GetArray().Select(e => e.ToString(indent + 1))));
 
            return "<<unknown value>>";
        }

        private string QuoteIfNeeded(string text)
        {
            if (text == null) 
                return string.Empty;
            
            if (text.ToCharArray().Intersect(" \t".ToCharArray()).Any())
                return "\"" + text + "\"";

            return text;
        }
    }
}

