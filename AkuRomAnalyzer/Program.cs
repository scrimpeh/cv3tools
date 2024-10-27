using System;
using System.Linq;

namespace AkuRomAnalyzer
{
	class Program
	{
		// Analyzes a Castlevania 3 ROM for possible memory corruption from out-of-bounds camera indices
		// You can supply a target address in RAM and a target value, and this tool will try to find
		// possible memory corruptions using the game's enemy object table.

		static void Main(string[] args)
		{
			Console.WriteLine("====================================================================");
			Console.WriteLine("=                  = Castlevania 3 Rom Analyzer =                  =");
			Console.WriteLine("====================================================================\n");

			var argParser = new ArgumentParser(args.ToList());
			var romInformation = argParser.RomPaths.Select(s => new GameData(s));

			Console.WriteLine("ROMs:\n");
			foreach (var romPath in argParser.RomPaths)
				Console.WriteLine(romPath);
			Console.WriteLine();

			var iteration = 1;
			foreach (var corruption in argParser.TargetCorruptions)
			{
				Console.WriteLine($"------------------ Starting Corruption Search {iteration++} ------------------\n");
				Console.WriteLine("Target addresses: " + string.Join(", ", FormatUtil.ToHex(corruption.TargetAddress.Values)));
				Console.WriteLine("Target values: " + corruption.TargetPredicate.Format() + '\n');
				var corruptionSearch = new CorruptionSearch(romInformation, corruption);
				corruptionSearch.Run();
				Console.WriteLine($"\n------------------------------------------------------------------\n");
			}

			Console.WriteLine("Done.");
		}
	}
}
