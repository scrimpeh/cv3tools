using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.IO;
using AkuRomAnaylzer.Extensions.ByteArray;

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
				var levelAddr = prgBank.ReadWordAndInc(ref readOffset);
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
					var sublevelOffs = prgBank.ReadWordAndInc(ref offs);
					currentSublevel.Add(sublevelOffs);
					Console.WriteLine($"BLK {i:X}-{sublevel} - ${sublevelOffs:X4}");
				}
				sublevelStarts.Add(currentSublevel);
				i++;
			}

			Console.WriteLine("\nReading Write Offsets...");
			var writeOffset = 0x7E0;
			var writeOffsets = new List<int>() { 0x7C2, 0x7DA, 0x7D4, 0x7E6, 0x7CE };
			// This table contains the RAM offsets we can overwrite
			var offsetTable = new byte[256];
			var offsetTableAddr = region == Region.Us ? 0x840C : 0x8410;
			for (i = 0; i < 256; i++)
			{
				offsetTable[i] = prgBank[(offsetTableAddr + i) & 0x3FFF];
			}

			var targetAddress = 0xAA;
			var targetValues = new List<int>() { 0xD, 0x11, 0x36, 0x43, 0x7C, 0x7D, 0x7E, 0x83, 0x87, 0xA6, 0xA7, 0xAE, 0xAF, 0xB2, 0xB3, 0xBD };
			//var targetAddress = 0x18;
			//var targetValues = new List<int>() { 0xC };

			Console.WriteLine($"\nTrying to find errant RAM write for ${targetAddress:X2}.");
			Console.Write("Possible values are: \n");
			Console.Write($"${targetValues[0]:X2}");
			foreach (var target in targetValues.Skip(1))
			{
				Console.Write($", ${target:X2}");
			}
			Console.WriteLine("\n");

			var goodOffsets = new List<WriteOffs>(); 
			for (i = 0; i < 256; i++) 
			{
				var y = 0;
				foreach (var o in writeOffsets) 
				{
					if (((o + offsetTable[i]) & 0x7FF) == targetAddress)
					{
						goodOffsets.Add(new WriteOffs(i, y, o, offsetTable[i]));
					}
					y++;
				}

				if (((writeOffset + offsetTable[i]) & 0x7FF) == targetAddress)
				{
					goodOffsets.Add(new WriteOffs(i, -1, writeOffset, offsetTable[i]));
				}
			}

			if (!goodOffsets.Any()) 
			{
				Console.WriteLine("Cannot find a good read offset!");
				return;
			}

			goodOffsets.Sort((x, y) => x.BaseAddr.CompareTo(y.BaseAddr));
			foreach (var offs in goodOffsets)
			{
				var cameraPosMin = (0x100 * (offs.CamOffs / 4)) + (0x40 * (i % 4));
				var cameraPosMax = cameraPosMin + 0x3F;
				var cameraPos = $"[${cameraPosMin:X4}-${cameraPosMax:X4}]";
				var y = offs.Y == -1 ? "-" : $"{offs.Y}";
				Console.Write($"OK: ${offs.BaseAddr:X3},${offs.Offs:X2} -> ${targetAddress:X2} (y: {y})    offs ${offs.CamOffs:X2} {cameraPos}   ");
				if (offs.Y == -1)
				{
					Console.WriteLine("< $0A & $01     >");
				}
				else if (offs.Y == 1)
				{
					Console.WriteLine("< ($98),y + $09 >");
				}
				else
				{
					Console.WriteLine("< ($98),y       >");
				}
			}


			// so here's the situation: these pointers point to pointer tables for rooms
			// however, while they begin at a certain location, if we exceed the regular game room through stair glitching, we 
			// can "access" up to 128 rooms from where the pointer starts

			// the pointer to a room is later dereferenced, and the value found there is used as an index into a fixed table which
			// holds the level ID we want to write.
			// our goal is to find a good index

			// first, obtain the table that is dereferenced
			// i have no clue what it's actually used for, which doesn't help naming a lot
			var indexedTableOffs = (region == Region.Us ? 0xA03F : 0x9F6E) & 0x3FFF;
			var indexedTableSize = 228;
			var indexedTablePtrs = new int[indexedTableSize];
			Console.WriteLine($"\nReading Table @ ${indexedTableOffs | 0x8000:X4}...");
			for (i = 0; i < indexedTableSize; i++)
			{
				indexedTablePtrs[i] = prgBank.ReadWordAndInc(ref indexedTableOffs);
			}
			Console.WriteLine("Reading Offsets from table...");

			Console.WriteLine("\nFinding appropriate lookups...");
			var lookups = new List<Lookup>();
			for (i = 0; i < indexedTableSize; i++)
			{
				var addr = indexedTablePtrs[i];
				for (var y = 0; y < 5; y++)
				{
					foreach (var value in targetValues)
					{
						if (prgBank[(addr + y) & 0x3FFF] == value)
						{
							var lookup = new Lookup();
							lookup.TableBaseAddr = indexedTablePtrs[0];
							lookup.FullAddress = addr + y;
							lookup.TableBaseOffs = lookup.FullAddress - lookup.TableBaseAddr;
							lookup.Y = y;
							lookup.Index = i;
							lookup.Value = value;
							lookups.Add(lookup);
						}
					}
				}
			}

			Console.WriteLine("Can find target values at...");
			foreach (var lookup in lookups)
			{
				Console.Write($"${lookup.FullAddress:X4}: ${lookup.Index:X2},{lookup.Y} => ${lookup.Value:X2}");
				Console.WriteLine();
			}

			Console.WriteLine("\nAnalyzing room pointer data...\n");

			var readRoom = -1;
			var readSublevel = -1;
			var readBlock = -1;
			var readOffs = sublevelStarts[0][0];

			var goodReadOffsets = new List<ReadOffs>();
				
			while (true)
			{
				var roomAddress = prgBank.ReadWord(readOffs & 0x3FFF);

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
				var offs = (goodOffsets[0].CamOffs * 2) & 0xFF;	// this is effectively (camera pos * 8 & 0xFF) = ($76*2)
				var structOffs = 0;
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
				else if (roomAddress  < 0xC000)
				{
					Console.Write("[ROM]");
					roomAddress &= 0x3FFF;
					foreach (var o in goodOffsets.Where(o => o.Y != -1))
					{
						var ptrOffs = (o.CamOffs * 2) & 0xFF;
						Console.Write($" @[${0x8000 | roomAddress:X4}],${ptrOffs:X2} -> ");
						if (roomAddress + ptrOffs >= 0x4000)
						{
							Console.Write("[?]; ");
							continue;
						}
						var read = prgBank[roomAddress + ptrOffs];
						Console.Write($"${read:X2}");
						if (read >= indexedTablePtrs.Length) 
						{
							Console.Write(" --> [X]; ");
							continue;
						}

						var indexed = indexedTablePtrs[read];
						var readRom = prgBank[(indexed + o.Y) & 0x3FFF];
						Console.Write($" --> [${indexed:X4}],{o.Y} => ${readRom:X2}");
						if (targetValues.Contains(readRom))
						{
							Console.Write('*');
							goodReadOffsets.Add(new ReadOffs(readBlock, readSublevel, readRoom, o, readRom));
						}
						Console.Write("; ");
					}				
					Console.WriteLine();
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
			
			if (!goodReadOffsets.Any()) 
			{
				Console.WriteLine("\nNo suitable read offsets found. Try using a room that points to [ZP].");
			}
			else 
			{
				Console.WriteLine("\nOffsets found:");
				foreach (var o in goodReadOffsets) 
				{
					Console.Write($"BLK-{o.Block:X}-{o.Sublevel:X}-{o.Screen:X2}");
					Console.Write($": Cam ${o.CamOffs:X2} [${o.CameraMin:X4}-${o.CameraMax:X4}] -> ");
					Console.Write($"[${o.BaseAddr:X3},${o.Offs:X2}, y: {o.Y}] :: ");
					Console.Write($"set ${o.Target:X2} to ${o.Value:X2}");
					Console.WriteLine();
				}
			}

			Console.WriteLine("\nDone");
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

	struct WriteOffs
	{
		public int Y { get; set; }
		public int BaseAddr { get; set; }
		public int Offs { get; set; }
		public int CamOffs { get; set; }

		public WriteOffs(int camOffs, int y, int baseAddr, int offs) 
		{
			CamOffs = camOffs;
			Y = y;
			BaseAddr = baseAddr;
			Offs = offs;
		}
	}

	struct ReadOffs
	{
		public int Block { get; set; }
		public int Screen { get; set; }
		public int Sublevel { get; set; }
		public int CamOffs { get; set; }
		public int CameraMin { get; set; }
		public int CameraMax { get; set; }
		public int Value { get; set; }
		public int Target { get; set; }
		public int BaseAddr { get; set; }
		public int Y { get; set; }
		public int Offs { get; set; }

		public ReadOffs(int block, int sublevel, int screen, WriteOffs wo, int value) 
		{
			Block = block;
			Sublevel = sublevel;
			Screen = screen;
			CamOffs = wo.CamOffs;
			CameraMin = (0x100 * (CamOffs / 4)) + (0x40 * (CamOffs % 4));
			CameraMax = CameraMin + 0x3F;
			Y = wo.Y;
			Offs = wo.Offs;
			BaseAddr = wo.BaseAddr;
			Target = (BaseAddr + Offs) & 0xFF;
			Value = value;
		}
	}

	struct Lookup
	{
		public int TableBaseAddr { get; set; }
		public int TableBaseOffs { get; set; }
		public int Index { get; set; }
		public int FullAddress { get; set; }
		public int Value { get; set; }
		public int Y { get; set; }
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
