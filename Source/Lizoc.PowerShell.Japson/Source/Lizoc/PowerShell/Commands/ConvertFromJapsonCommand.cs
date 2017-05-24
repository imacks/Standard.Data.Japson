using System;
using System.Collections.Generic;
using System.IO;
using System.Management.Automation;
using System.Reflection;
using System.Linq;
using Standard.Data.Japson;
using Lizoc.PowerShell.Japson;

namespace Lizoc.PowerShell.Commands
{
    [Cmdlet(
        VerbsData.ConvertFrom, "Japson", 
        HelpUri = "http://docs.lizoc.com/powerdev/cmd/convertfromjapson",
        RemotingCapability = RemotingCapability.None
    ), OutputType(typeof(PSObject))]
    public class ConvertFromJapsonCommand : Cmdlet
    {
        private List<string> _inputObjectBuffer = new List<string>();
        private string[] _fallback;

        [AllowEmptyString, Parameter(Mandatory = true, Position = 0, ValueFromPipeline = true)]
        public string InputObject { get; set; }

        [Parameter(Mandatory = false)]
        public string[] Fallback 
        { 
            get { return _fallback; }
            set { _fallback = value; }
        }

        protected override void BeginProcessing()
        {
        }

        protected override void ProcessRecord()
        {
            _inputObjectBuffer.Add(this.InputObject);
        }

        protected override void EndProcessing()
        {
            // ignore empty entry
            if (_inputObjectBuffer.Count == 0)
                return;

            // It is not actually easy to write syntaxically wrong Japson.
            // So instead of trying to figure out if it is a list of japson or 
            // just newlines, let's just join the list to a whole big string.

            JapsonContext context;
            JapsonContext userContext;
            try
            {
                if (_inputObjectBuffer.Count == 1)
                    userContext = JapsonFactory.ParseString(string.Join(Environment.NewLine, _inputObjectBuffer[0]));
                else
                    userContext = JapsonFactory.ParseString(string.Join(Environment.NewLine, _inputObjectBuffer.ToArray()));

                if (_fallback == null || _fallback.Length == 0)
                {
                    context = userContext;
                }
                else if (_fallback.Length == 1)
                {
                    if (string.IsNullOrEmpty(_fallback[0]))
                        context = userContext;
                    else
                        context = userContext.WithFallback(JapsonFactory.ParseString(_fallback[0]));
                }
                else
                {
                    JapsonContext baseContext = null;
                    for (int i = _fallback.Length - 1; i >= 0; i--)
                    {
                        if (string.IsNullOrEmpty(_fallback[i]))
                            continue;

                        if (baseContext == null)
                            baseContext = JapsonFactory.ParseString(_fallback[i]);       
                        else
                            baseContext = baseContext.WithFallback(JapsonFactory.ParseString(_fallback[i]));
                    }

                    if (baseContext == null)
                        context = userContext;
                    else
                        context = userContext.WithFallback(baseContext);
                }

                // Handle empty situation
                if (context.IsEmpty)
                    return;

                ErrorRecord populateError;
                object obj = TransverseJapsonRoot(context, out populateError);
                if (populateError != null)
                    base.ThrowTerminatingError(populateError);

                base.WriteObject(obj);
            }
            catch (Exception ex)
            {
                ErrorRecord errorRecord = new ErrorRecord(ex, "JapsonConversionFailure", ErrorCategory.ParserError, null);
                base.ThrowTerminatingError(errorRecord);
            }
        }

        private static object TransverseJapsonRoot(JapsonContext context, out ErrorRecord error)
        {
            // internal exception catching
            if (context == null)
                throw new ArgumentNullException(nameof(context));

            error = null;
            PSObject psObject = new PSObject();

            if (context.IsEmpty)
                return null;

            if (!context.Root.IsObject())
            {
                error = new ErrorRecord(new FormatException(RS.Err_JapsonRootNotAnObject), "JapsonRootNotAnObject", ErrorCategory.ParserError, null);
                return null;
            }

            // direct decendents of root
            IList<string> keys = context.GetChildNodeNames();
            foreach (string key in keys)
            {
                string safeKey = key;
                if (key.Contains("."))
                    safeKey = "'" + key.Replace("'", "\\'") + "'";

                JapsonValue child = context.GetValue(safeKey);
                psObject.Properties.Add(new PSNoteProperty(key, PopulateJapsonValue(child, context, safeKey, out error)));                
                if (error != null)
                    return null;
            }

            return psObject;
        }

        private static object PopulateJapsonValue(JapsonValue jv, JapsonContext context, string path, out ErrorRecord error)
        {
            if (jv == null)
                throw new ArgumentNullException(nameof(jv));
            error = null;

            if (jv.IsEmpty)
                return null;

            if (jv.IsString())
            {
                try { return jv.GetBoolean(); }
                catch {}

                try { return jv.GetInt32(); }
                catch {}

                try { return jv.GetInt64(); }
                catch {}

                try { return jv.GetSingle(); }
                catch {}
                
                try { return jv.GetDouble(); }
                catch {}

                try { return jv.GetDecimal(); }
                catch {}

                try { return jv.GetTimeSpan(); }
                catch {}

                try { return jv.GetByteSize(); }
                catch {}

                return jv.GetString();
            }
            else if (jv.IsArray())
            {
                IList<JapsonValue> values = jv.GetArray();
                List<object> results = new List<object>();

                foreach (JapsonValue current in values)
                {
                    results.Add(PopulateJapsonValue(current, context, path, out error));
                    if (error != null)
                        return null;
                }

                return results.ToArray();
            }
            else if (jv.IsObject())
            {
                PSObject psObject = new PSObject();
                IList<string> keys = context.GetChildNodeNames(path);

                foreach (string key in keys)
                {
                    string safeKey = key;
                    if (key.Contains("."))
                        safeKey = "'" + key.Replace("'", "\\'") + "'";
                    string safePath = path + "." + safeKey;

                    JapsonValue child = context.GetValue(safePath);
                    psObject.Properties.Add(new PSNoteProperty(key, PopulateJapsonValue(child, context, safePath, out error)));
                    if (error != null)
                        return null;
                }

                return psObject;
            }
            else
            {
                return null;
            }
        }
    }
}
