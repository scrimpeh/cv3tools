using System;
using System.Collections.Generic;
using System.Linq;

namespace AkuRomAnalyzer
{
	public class ArgumentParser
	{
		private readonly IDictionary<char, Region> RecognizedRegions = new Dictionary<char, Region>
		{
			{ 'u', Region.Us },
			{ 'j', Region.Japan },
		};

		public List<string> RomPaths { get; } = new List<string>();
		public List<CorruptionSearchParameters> TargetCorruptions { get; } = new List<CorruptionSearchParameters>();

		// Currently constructed construction search parameters
		private IDictionary<Region, ushort> targetAddresses;
		private List<byte> targetValues;

		public ArgumentParser(List<string> args)
		{
			if (!args.Any())
				Error();
			ResetParameters();
			for (var i = 0; i < args.Count; i++)
				ParseArg(args, ref i);

			if (!RomPaths.Any())
				Error("No roms specified!");
			if (!TargetCorruptions.Any())
				Error("No target corruptions specified!");
		}

		private void ResetParameters()
		{
			targetAddresses = new Dictionary<Region, ushort>();
			targetValues = new List<byte>();
		}

		private void ParseArg(List<string> args, ref int i)
		{
			var arg = args[i].ToLowerInvariant();
			if (arg == "-rom")
			{
				// TODO: I'm not sure yet if filenames with spaces are handled properly here
				if (++i == args.Count)
					Error("Reached end of args before getting ROM path!");
				RomPaths.Add(args[i]);
			}
			else if (arg == "-target")
			{
				if (++i == args.Count)
					Error("Reached end of args before getting target values!");
				for (; i < args.Count; i++)
				{
					targetValues.Add(ParseByte(args[i]));
					if (i == args.Count - 1 || args[i + 1].StartsWith("-"))
					{
						// Complete corruption
						if (!targetAddresses.Any())
							throw new ArgumentException("No target address given!");
						var targetAddressU = GetTargetAddress(Region.Us);
						var targetAddressJ = GetTargetAddress(Region.Japan);
						TargetCorruptions.Add(new CorruptionSearchParameters(targetAddressU, targetAddressJ, targetValues.ToArray()));
						ResetParameters();
						break;
					}
				}
			}
			else if (arg.StartsWith("-"))
			{
				var regions = arg.Substring(1).ToHashSet();
				if (++i == args.Count)
					Error("Reached end of args before getting target address!");
				foreach (var regionKey in regions)
				{
					if (!RecognizedRegions.TryGetValue(regionKey, out var region))
						Error($"Unknown region '{regionKey}'!");
					if (targetAddresses.TryGetValue(region, out var existing))
						Error($"Region {region} already has target address for given corruption: ${existing:X}");
					targetAddresses[region] = ParseWord(args[i]);
				}
			}
			else
			{
				Error($"Unrecognized Argument: '{args[i]}'!");
			}
		}

		private ushort GetTargetAddress(Region region)
		{
			if (targetAddresses.TryGetValue(region, out var value))
				return value;
			return CorruptionSearchParameters.Unknown;
		}

		private static byte ParseByte(string value)
		{
			var b = ParseValue(value);
			if (b < 0 || b >= 256)
				throw new ArgumentException(value);
			return (byte)b;
		}

		private static ushort ParseWord(string value)
		{
			var w = ParseValue(value);
			if (w < 0 || w >= 65536)
				throw new ArgumentException(value);
			return (ushort)w;
		}

		private static long ParseValue(string value)
		{
			if (value.StartsWith("0b"))
				return Convert.ToInt64(value.Substring(2), 2);
			else if (value.StartsWith("%"))
				return Convert.ToInt64(value.Substring(1), 2);
			if (value.StartsWith("0x"))
				return Convert.ToInt64(value.Substring(2), 16);
			else if (value.StartsWith("$"))
				return Convert.ToInt64(value.Substring(1), 16);
			return long.Parse(value);
		}

		private static void Error(string message = null)
		{
			Console.WriteLine("\nUsage:\n");
			Console.Write("cv3rom ");
			Console.Write("-rom \"path/to/Akumajou Densetsu (J).nes\" ");
			Console.Write("-rom ... ");
			Console.Write("-u $32 ");
			Console.Write("-j $34 ");
			Console.Write("-target $0D $0E ");
			Console.Write("-uj $18 ");
			Console.Write("-target $0C ");
			Console.Write(" ...");
			Console.WriteLine("\n");
			Console.WriteLine("Seaches for memory corruption of the target address given by '-u' or '-j' with the given target values.");
			Console.WriteLine("Provide the path to ROMs for different regions using the '-rom' parameter.\n");
			if (message != null)
				Console.WriteLine(message);
			Console.WriteLine();
			Environment.Exit(1);
		}
	}
}
