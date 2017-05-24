using System;
using System.Collections.Generic;
using System.Linq;

namespace Standard.Data.Japson
{
    /// <summary>
    /// This class contains methods used to parse JAPSON configuration strings.
    /// </summary>
    public class JapsonParser
    {
        private readonly List<JapsonSubstitution> _substitutions = new List<JapsonSubstitution>();
        private JapsonTokenizer _reader;
        private JapsonValue _root;
        private Func<string, JapsonRoot> _includeCallback;
        private Stack<string> _diagnosticsStack = new Stack<string>();

        private void PushDiagnostics(string message)
        {
            _diagnosticsStack.Push(message);
        }

        private void PopDiagnostics()
        {
            _diagnosticsStack.Pop();
        }

        public string GetDiagnosticsStackTrace()
        {
            string currentPath = string.Join(string.Empty, _diagnosticsStack.Reverse());
            return string.Format("Path: {0}", currentPath);
        }

        /// <summary>
        /// Parses the supplied JAPSON configuration string into a root element.
        /// </summary>
        /// <param name="text">The string that contains a JAPSON configuration string.</param>
        /// <param name="includeCallback">Callback used to resolve includes.</param>
        /// <exception cref="System.Exception">
        /// An unresolved substitution is encountered, or the end of the file has been reached while trying to read a value.
        /// </exception>
        /// <returns>The root element created from the supplied JAPSON configuration string.</returns>
        public static JapsonRoot Parse(string text, Func<string, JapsonRoot> includeCallback)
        {
            return new JapsonParser().ParseText(text, includeCallback);
        }

        private JapsonRoot ParseText(string text, Func<string, JapsonRoot> includeCallback)
        {
            _includeCallback = includeCallback;
            _root = new JapsonValue();
            _reader = new JapsonTokenizer(text);
            _reader.PullWhitespaceAndComments();
            ParseObject(_root, true, string.Empty);

            JapsonContext c = new JapsonContext(new JapsonRoot(_root, Enumerable.Empty<JapsonSubstitution>()));
            foreach (JapsonSubstitution sub in _substitutions)
            {
                JapsonValue res = c.GetValue(sub.Path);
                if (res == null)
                    throw new JapsonParserException(string.Format(RS.ErrUnresolvedSubstitution, sub.Path));

                sub.ResolvedValue = res;
            }
            return new JapsonRoot(_root, _substitutions);
        }

        private void ParseObject(JapsonValue owner, bool root, string currentPath)
        {
            try
            {
                PushDiagnostics("{");

                if (owner.IsObject())
                {
                    //the value of this KVP is already an object
                }
                else
                {
                    //the value of this KVP is not an object, thus, we should add a new
                    owner.NewValue(new JapsonObject());
                }

                JapsonObject currentObject = owner.GetObject();

                while (!_reader.EOF)
                {
                    JapsonToken t = _reader.PullNext();
                    switch (t.Type)
                    {
                        case TokenType.Include:
                            JapsonRoot included = _includeCallback(t.Value);
                            IEnumerable<JapsonSubstitution> substitutions = included.Substitutions;
                            foreach (JapsonSubstitution substitution in substitutions)
                            {
                                //fixup the substitution, add the current path as a prefix to the substitution path
                                substitution.Path = currentPath + "." + substitution.Path;
                            }
                            _substitutions.AddRange(substitutions);
                            JapsonObject otherObj = included.Value.GetObject();
                            owner.GetObject().Merge(otherObj);

                            break;

                        case TokenType.EOF:
                            if (!string.IsNullOrEmpty(currentPath))
                                throw new JapsonParserException(string.Format(RS.ErrObjectUnexpectedEOF, GetDiagnosticsStackTrace()));

                            break;

                        case TokenType.Key:
                            JapsonValue value = currentObject.GetOrCreateKey(t.Value);

                            string currentKey = t.Value;
                            if (currentKey.IndexOf('.') >= 0) 
                                currentKey = "\"" + currentKey + "\"";
                            string nextPath = currentPath == string.Empty ? currentKey : currentPath + "." + currentKey;
                            
                            ParseKeyContent(value, nextPath);
                            if (!root)
                                return;
                            break;

                        case TokenType.ObjectEnd:
                            return;
                    }
                }
            }
            finally
            {
                PopDiagnostics();
            }
        }

        private void ParseKeyContent(JapsonValue value, string currentPath)
        {
            try
            {
                string last = new JapsonPath(currentPath).AsArray().Last();
                PushDiagnostics(string.Format("{0} = ", last));
                while (!_reader.EOF)
                {
                    JapsonToken t = _reader.PullNext();
                    switch (t.Type)
                    {
                        case TokenType.Dot:
                            ParseObject(value, false, currentPath);
                            return;

                        case TokenType.Assign:
                            if (!value.IsObject())
                            {
                                //if not an object, then replace the value.
                                //if object. value should be merged
                                value.Clear();
                            }
                            ParseValue(value, currentPath);
                            return;

                        case TokenType.ObjectStart:
                            ParseObject(value, true, currentPath);
                            return;
                    }
                }
            }
            finally
            {
                PopDiagnostics();
            }
        }

        /// <summary>
        /// Retrieves the next value token from the tokenizer and appends it
        /// to the supplied element <paramref name="owner"/>.
        /// </summary>
        /// <param name="owner">The element to append the next token.</param>
        /// <param name="currentPath">Current AST path.</param>
        /// <exception cref="System.Exception">End of file reached while trying to read a value</exception>
        public void ParseValue(JapsonValue owner, string currentPath)
        {
            if (_reader.EOF)
                throw new JapsonParserException(RS.ErrUnexpectedEOF);

            _reader.PullWhitespaceAndComments();
            int start = _reader.Index;
            try
            {
                while (_reader.IsValue())
                {
                    JapsonToken t = _reader.PullValue();

                    switch (t.Type)
                    {
                        case TokenType.EOF:
                            break;

                        case TokenType.LiteralValue:
                            // needed to allow for override objects
                            if (owner.IsObject())
                                owner.Clear();

                            LiteralString lit = new LiteralString { Value = t.Value };
                            owner.AppendValue(lit);

                            break;

                        case TokenType.ObjectStart:
                            ParseObject(owner, true, currentPath);
                            break;

                        case TokenType.ArrayStart:
                            JapsonArray arr = ParseArray(currentPath);
                            owner.AppendValue(arr);
                            break;

                        case TokenType.Substitute:
                            JapsonSubstitution sub = ParseSubstitution(t.Value);
                            _substitutions.Add(sub);
                            owner.AppendValue(sub);
                            break;
                    }

                    if (_reader.IsSpaceOrTab())
                        ParseTrailingWhitespace(owner);
                }

                IgnoreComma();
            }
            catch(JapsonTokenizerException tokenizerException)
            {
                throw new JapsonParserException(string.Format("{0}\r{1}", tokenizerException.Message, GetDiagnosticsStackTrace()),tokenizerException);
            }
            finally
            {
                // no value was found, tokenizer is still at the same position
                if (_reader.Index == start)
                    throw new JapsonParserException(string.Format(RS.ErrBadJapsonSyntax, _reader.GetHelpTextAtIndex(start), GetDiagnosticsStackTrace()));
            }
        }

        private void ParseTrailingWhitespace(JapsonValue owner)
        {
            JapsonToken ws = _reader.PullSpaceOrTab();

            //single line ws should be included if string concat
            if (ws.Value.Length > 0)
            {
                LiteralString wsLit = new LiteralString { Value = ws.Value, };
                owner.AppendValue(wsLit);
            }
        }

        private static JapsonSubstitution ParseSubstitution(string value)
        {
            return new JapsonSubstitution(value);
        }

        /// <summary>
        /// Retrieves the next array token from the tokenizer.
        /// </summary>
        /// <returns>An array of elements retrieved from the token.</returns>
        public JapsonArray ParseArray(string currentPath)
        {
            try
            {
                PushDiagnostics("[");

                JapsonArray arr = new JapsonArray();
                while (!_reader.EOF && !_reader.IsArrayEnd())
                {
                    JapsonValue v = new JapsonValue();
                    ParseValue(v, currentPath);
                    arr.Add(v);
                    _reader.PullWhitespaceAndComments();
                }
                _reader.PullArrayEnd();
                return arr;
            }
            finally
            {
                PopDiagnostics();
            }
        }

        private void IgnoreComma()
        {
            // optional end of value
            if (_reader.IsComma()) 
                _reader.PullComma();
        }
    }
}
