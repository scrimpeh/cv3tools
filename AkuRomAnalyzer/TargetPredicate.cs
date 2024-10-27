using System;
using System.Collections.Generic;
using System.Linq;

namespace AkuRomAnalyzer
{
	public class TargetPredicate
	{
		// only 1 if using anything else than equal, 0 if "any"
		public HashSet<byte> Values { get; private set; }
		public byte Value { get; private set; }
		public Type PredicateType { get; private set; }

		private TargetPredicate(List<byte> targetValues, Type type)
		{
			Values = targetValues.ToHashSet();

			PredicateType = type;
			switch (PredicateType)
			{
				case Type.Equal:
					if (!Values.Any())
						throw new ArgumentException();
					break;
				case Type.GreaterThan:
				case Type.GreaterThanEqual:
				case Type.LessThan:
				case Type.LessThanEqual:
					if (Values.Count != 1)
						throw new ArgumentException();
					Value = Values.First();
					break;
			}
		}

		public static TargetPredicate Any()
			=> new TargetPredicate(new List<byte>(), Type.Any);

		public static TargetPredicate Of(Type type, byte value)
			=> new TargetPredicate(new List<byte>() { value }, type);

		public static TargetPredicate Equal(List<byte> values)
			=> new TargetPredicate(values, Type.Equal);

		public bool Matches(byte value)
		{
			switch (PredicateType)
			{
				case Type.Any:              return true;
				case Type.Equal:            return Values.Contains(value);
				case Type.GreaterThan:      return value > Value;
				case Type.GreaterThanEqual: return value >= Value;
				case Type.LessThan:         return value < Value;
				case Type.LessThanEqual:    return value <= Value;
				default:                    return false;
			}
		}

		public string Format()
		{
			switch (PredicateType)
			{
				case Type.Any:              return "Any";
				case Type.Equal:            return "== " + string.Join(", ", FormatUtil.ToHex(Values).OrderBy(s => s));
				case Type.GreaterThan:      return "> " + FormatUtil.ToHex(Value);
				case Type.GreaterThanEqual: return ">= " + FormatUtil.ToHex(Value);
				case Type.LessThan:         return "<= " + FormatUtil.ToHex(Value);
				case Type.LessThanEqual:    return "< " + FormatUtil.ToHex(Value);
				default:                    return "<Unknown>";
			}
		}

		public enum Type
		{
			Any,
			GreaterThan,
			GreaterThanEqual,
			LessThan,
			LessThanEqual,
			Equal
		}
	}
}
