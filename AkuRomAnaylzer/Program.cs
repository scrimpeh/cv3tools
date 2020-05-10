using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.IO;

namespace AkuRomAnaylzer
{
	class Program
	{
		static void Main(string[] args)
		{
			// Todo: Factor all this out into separate classes / functions
			var region = Region.Unknown;
			var romType = RomType.Unsupported;
			string path = null;

			// Search Castlevania 3 ROM for Pointer Tables relating to map loading
			// Used for figuring out wrong warps
			// usage: cv3rom [-u/-j] [filename].
			// Results are printed out to console.
			Console.WriteLine("-- Castlevania 3 Rom Analyzer --");
			if (args.Length < 1)
			{
				PrintUsage();
				Environment.Exit(1);
			}

			foreach (var arg in args)
			{
				if (arg[0] == '-')
				{
					if (arg.Length <= 1)
					{
						Console.WriteLine($"Invalid Argument: {arg}");
						Environment.Exit(1);
					}
					switch (arg[1])
					{
						case 'j':
							region = Region.Japan;
							break;
						case 'u':
							region = Region.Us;
							break;
						default:
							Console.WriteLine($"Invalid flag: {arg[1]}!");
							Environment.Exit(1);
							break;
					}
				}
				else
				{
					path = arg;
				}

				if (path == null)
				{
					Console.WriteLine($"No Path set!");
					PrintUsage();
					Environment.Exit(1);
				}

				Console.WriteLine($"Reading ROM {path}...");
				try
				{
					if (region == Region.Unknown)
					{
						region = TryGuessRegion(path);
					}
				}
				catch (Exception e)
				{
					Console.WriteLine($"Error reading file: {e.Message}");
					Environment.Exit(1);
				}
				if (region == Region.Europe)
				{
					Console.WriteLine("Region Europe is not supported!");
					Environment.Exit(1);
				}
				if (region == Region.Unknown)
				{
					Console.WriteLine("Warning, couldn't determine region! Attempting US as fallback");
					region = Region.Us;
				}

				// As far as I know, there were no differing revisions of the game, so we don't need to do a check for that.

				// Now read the rom
				byte[] rawRom = null;
				try
				{
					rawRom = File.ReadAllBytes(path);
				}
				catch (Exception e)
				{
					Console.WriteLine($"Error reading file: {e.Message}");
					Environment.Exit(1);
				}

				try
				{
					romType = GuessRomType(path, rawRom);
				}
				catch (Exception e)
				{
					Console.WriteLine($"Error determining ROM type: {e.Message}");
					Environment.Exit(1);
				}

				if (!ValidateRom(rawRom, region, romType))
				{
					Console.WriteLine($"Error. Rom doesn't match expected paramenters!");
					Environment.Exit(1);
				}

				// Extract PRG rom
				var trained = (rawRom[6] & 0x4) != 0;
				var prgStart = trained ? 528 : 16;
				var prgSize = rawRom[4] * 16384;
				var prg = new byte[prgSize];
				try
				{
					Array.Copy(rawRom, prgStart, prg, 0, prgSize);
				}
				catch (Exception e)
				{
					Console.WriteLine($"Couldn't read ROM: {e.Message}");
					Environment.Exit(1);
				}

				// now anaylze
				Console.WriteLine($"Got ROM - Region {region}. Extracted PRG ROM [{prgSize / 1024} kib]");

				var romBank = 10;
				// note that this is the offset the game code reads from, which needs to be masked with 0x3FFF first
				var prgOffset = romBank * 16384;
				var prgBank = new byte[16384];
				Array.Copy(prg, prgOffset, prgBank, 0, prgBank.Length);
				var readOffset = region == Region.Us ? 0x937F : 0x92AE;

				// now begin
				Console.WriteLine($"\nReading rom offsets at ${readOffset:X4}...\n");
				readOffset &= 0x3FFF;
				var levelOffsets = new List<int>();
				for (var level = 0; level < 15; level++)
				{
					var lo = prgBank[readOffset++];
					var hi = prgBank[readOffset++];
					var levelAddr = (hi << 8) | lo;
					levelOffsets.Add(levelAddr);
					Console.WriteLine($"Block ${level:X} -> ${levelAddr:X4}");
				}
				Console.WriteLine("\nReading Level Offsets...\n");

				// 0.beginning// 1.clock tower
				// 2.forest
				// 3.ship
				// 4.tower
				// 5.bridge
				// 6.swamp
				// 7.cave
				// 8.sunken city
				// 9.crypt
				// A.cliffs
				// B.rafters
				// C.entry hall
				// D.inner castle
				// E.final approach
				var blockSublevelCounts = new List<int>() { 4, 6, 5, 5, 3, 4, 3, 7, 5, 2, 7, 3, 3, 4, 3 };

				// todo: decouple gathering of information from output
				var sublevelStarts = new List<List<int>>();
				var i = 0;
				foreach (var block in levelOffsets)
				{
					Console.WriteLine($"BLK {i:X}");
					var offs = block & 0x3FFF;
					var currentSublevel = new List<int>();
					for (var sublevel = 0; sublevel < blockSublevelCounts[i]; sublevel++)
					{
						var sublevelOffsLo = prgBank[offs++];
						var sublevelOffsHi = prgBank[offs++];
						var sublevelOffs = (sublevelOffsHi <<8) | sublevelOffsLo;
						currentSublevel.Add(sublevelOffs);
						Console.WriteLine($"BLK {i:X}-{sublevel} - ${sublevelOffs:X4}");
					}
					sublevelStarts.Add(currentSublevel);
					i++;
				}

				// so here's the situation: these pointers point to pointer tables for rooms
				// however, while they begin at a certain location, if we exceed the regular game room through stair glitching, we 
				// can "access" up to 128 rooms from where the pointer starts

				// the pointer to a room is later dereferenced, and the value found there is used as an index into a fixed table which
				// holds the level ID we want to write.
				// our goal is to find a good index
				Console.WriteLine("\nAnalyzing room pointer data...\n");

				var readRoom = -1;
				var readSublevel = -1;
				var readBlock = -1;
				var readOffs = sublevelStarts[0][0];

				while (true)
				{
					var roomAddressLo = prgBank[readOffs & 0x3FFF];
					var roomAddressHi = prgBank[(readOffs + 1) & 0x3FFF];
					var roomAddress = (roomAddressHi << 8) | roomAddressLo;

					var nextSubLevel = readSublevel + 1;
					var nextBlock = readBlock + 1;
					if (nextBlock < 15 && readOffs >= sublevelStarts[nextBlock][0])
					{
						readRoom = 0;
						readSublevel = 0;
						readBlock++;
						Console.Write($"BLK-{readBlock:X}-0-00 - $");
					}
					else if (nextSubLevel < sublevelStarts[readBlock].Count && readOffs >= sublevelStarts[readBlock][nextSubLevel])
					{
						readRoom = 0;
						readSublevel++;
						Console.Write($"      {readSublevel}-00 - $");
					}
					else
					{
						Console.Write($"        {readRoom:X2} - $");
					}
					Console.Write($"{roomAddress:X4} - ");


					// now analyze what we can find there there
					
					var offs = 0xAA;
					if ((roomAddress & ~0x800) == 0)
					{
						Console.WriteLine("[RAM] [ZP]");
					}
					else if (roomAddress < 0x2000)
					{
						Console.WriteLine("[RAM]");
					}
					else if (roomAddress < 0x8000)
					{
						Console.WriteLine("[-]");
					}
					else if (roomAddress + offs < 0xC000)
					{
						// todo: this seemed to be the offset we read from.
						roomAddress &= 0x3FFF;
						roomAddress += offs;
						var read = prgBank[roomAddress];
						Console.WriteLine($"@ [${0x8000 | (roomAddress - offs):X4}],${offs:X2} -> ${read:X2}");
					}
					else
					{
						// unfortunately I do not know currently what is mapped in above 0xC000 in the 6502's address space.
						// this is tbd
						Console.WriteLine("[ROM] [?]");
					}


					readOffs += 2;
					readRoom++;
					if (readRoom == 128)
					{
						if (readBlock == 14)
						{
							break;
						}
						else 
						{
							readOffs = sublevelStarts[readBlock + 1][0];
						}
					}
				}

			}
		}

		static bool ValidateRom(byte[] raw, Region region, RomType type)
		{
			// Castlevania 3 ROM has 256 kb of PRG rom and 128 kb of CHR Rom in both regions
			// Mapper MMC5 (5) in U, and mapper VRC6a (24) for J
			switch (type)
			{
				case RomType.Ines:
					{
						var expectedMapper = region == Region.Japan ? 24 : 5;
						var prgBanks = raw[4];
						var chrBanks = raw[5];
						var mapper = (raw[7] & 0xF0) | (raw[6] >> 4);
						if (prgBanks != 16 || chrBanks != 16 || mapper != expectedMapper)
						{
							return false;
						}
						return true;
					}
			}

			return false;
		}

		static RomType GuessRomType(string path, byte[] raw)
		{
			var assumedRomType = RomType.Unsupported;

			// First, look at the filename
			var extension = Path.GetExtension(path);
			if (extension == ".nes")
			{
				assumedRomType = RomType.Ines;
			}

			// Now, look at the header
			if (raw.Length < 16)
			{
				throw new Exception("ROM too small!");
			}

			switch (assumedRomType)
			{
				case RomType.Ines:
					if (raw[0] == 0x4E && raw[1] == 0x45 && raw[2] == 0x53 && raw[3] == 0x1A)
					{
						return RomType.Ines;
					}
					break;
			}

			throw new Exception("Cannot guess Rom Type!");
		}

		static Region TryGuessRegion(string path)
		{
			string filename = Path.GetFileNameWithoutExtension(path).ToLowerInvariant();
			if (filename.StartsWith("c") && Regex.Matches(filename, @"[[\(\[]eu?r?o?p?e?[\)\]]").Count > 0)
			{
				return Region.Europe;
			}
			else if (filename.StartsWith("c") || Regex.Matches(filename, @"[\(\[]us?a?[\)\]]").Count > 0)
			{
				return Region.Us;
			}
			else if (filename.StartsWith("a") || Regex.Matches(filename, @"[[\(\[]ja?p?a?n?[\)\]]").Count > 0)
			{
				return Region.Japan;
			}

			return Region.Unknown;
		}

		static void PrintUsage()
		{
			Console.WriteLine("Usage: cv3rom [-u/-j] [filename]");
		}

		static readonly string[] LevelNames =
		{
			"Beginning", "Clock Tower", "Forest", "Ship", "Tower", "Bridge", "Swamp",
			"Caves", "Sunken City", "Crypt", "Cliffs", "Rafters", "Entry Hall", "Inner Castle", "Final Approach"
		};
	}

	enum Level
	{
		Beginning = 0x0,
		ClockTower = 0x1,
		Forest = 0x2,
		Ship = 0x3,
		Tower = 0x4,
		Bridge = 0x5,
		Swamp = 0x6,
		Caves = 0x7,
		SunkenCity = 0x8,
		Crypt = 0x9,
		Cliffs = 0xA,
		Rafters = 0xB,
		EntryHall = 0xC,
		InnerCastle = 0xD,
		FinalApproach = 0xE
	}

	enum RomType
	{
		Ines,
		Unsupported
	}

	enum Region
	{
		Unknown,
		Us,
		Japan,
		Europe
	}
}
